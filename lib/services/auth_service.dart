import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _savedAccountsKey = 'pipisgram_saved_accounts';
  static const _storage = FlutterSecureStorage();

  User? get currentUser => _auth.currentUser;

  Future<String> _generateUniqueCode() async {
    final rnd = Random();
    while (true) {
      final code = (10000 + rnd.nextInt(90000)).toString();
      final existing = await _db
          .collection('users')
          .where('userCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
  }

  Future<String?> register(String email, String password, String username) async {
    final existing = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return 'Это имя пользователя уже занято';
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final userCode = await _generateUniqueCode();

      await _db.collection('users').doc(cred.user!.uid).set({
        'username': username,
        'userCode': userCode,
        'email': email,
        'online': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await OneSignal.login(cred.user!.uid);
      await _saveAccount(email, password, username);

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final userRef = _db.collection('users').doc(_auth.currentUser!.uid);
      final userDoc = await userRef.get();
      final data = userDoc.data();

      if (data?['accountPermanentlyBlocked'] == true) {
        await OneSignal.logout();
        await _auth.signOut();
        return 'Аккаунт заблокирован навсегда';
      }

      final blockedUntil = data?['supportBlockedUntil'];
      if (blockedUntil is Timestamp) {
        final until = blockedUntil.toDate();
        if (until.isAfter(DateTime.now())) {
          await OneSignal.logout();
          await _auth.signOut();
          final remaining = until.difference(DateTime.now());
          final hours = (remaining.inMinutes / 60).ceil();
          return 'Аккаунт временно заблокирован. Осталось примерно $hours ч.';
        }
      }

      final showStatus = data?['showOnlineStatus'] ?? true;
      final updates = <String, dynamic>{};
      if (showStatus) {
        updates['online'] = true;
      }

      // Довыдача кода для аккаунтов, созданных до введения этой функции
      if (data != null && (data['userCode'] == null || data['userCode'] == '')) {
        try {
          updates['userCode'] = await _generateUniqueCode();
        } catch (_) {
          // Старый аккаунт без кода не должен ломать сам вход.
        }
      }

      if (updates.isNotEmpty) {
        try {
          await userRef.update(updates);
        } catch (_) {
          // Не блокируем авторизацию из-за необязательного профиля.
        }
      }

      await OneSignal.login(_auth.currentUser!.uid);
      final username = (data?['username'] ?? email).toString();
      await _saveAccount(email, password, username);

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.setLanguageCode('ru');
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<void> logout({bool forgetSavedAccount = false}) async {
    if (currentUser != null) {
      await _db.collection('users').doc(currentUser!.uid).update({
        'online': false,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    }
    final email = currentUser?.email;
    await OneSignal.logout();
    await _auth.signOut();
    if (forgetSavedAccount && email != null) {
      await removeSavedAccount(email);
    }
  }

  Future<List<Map<String, String>>> savedAccounts() async {
    final raw = await _storage.read(key: _savedAccountsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value.toString())))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAccount(String email, String password, String username) async {
    final accounts = await savedAccounts();
    accounts.removeWhere((a) => a['email']?.toLowerCase() == email.toLowerCase());
    accounts.insert(0, {
      'email': email.trim(),
      'password': password,
      'username': username,
    });
    await _storage.write(key: _savedAccountsKey, value: jsonEncode(accounts));
  }

  Future<void> removeSavedAccount(String email) async {
    final accounts = await savedAccounts();
    accounts.removeWhere((a) => a['email']?.toLowerCase() == email.toLowerCase());
    await _storage.write(key: _savedAccountsKey, value: jsonEncode(accounts));
  }

  Future<String?> loginSavedAccount(Map<String, String> account) async {
    final email = account['email'] ?? '';
    final password = account['password'] ?? '';
    if (email.isEmpty || password.isEmpty) return 'Данные сохранённого аккаунта повреждены';
    return login(email, password);
  }

/// Проверяет и довыдаёт userCode при каждом открытии приложения —
  /// на случай если аккаунт создан до введения этой функции.
  Future<void> ensureUserCode() async {
    if (currentUser == null) return;
    final userRef = _db.collection('users').doc(currentUser!.uid);
    final doc = await userRef.get();
    final data = doc.data();
    if (data != null && (data['userCode'] == null || data['userCode'] == '')) {
      try {
        await userRef.update({'userCode': await _generateUniqueCode()});
      } catch (_) {
        // Не ломаем запуск приложения из-за необязательной довыдачи кода.
      }
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Такой email уже зарегистрирован';
      case 'weak-password':
        return 'Пароль слишком простой (минимум 6 символов)';
      case 'user-not-found':
      case 'wrong-password':
        return 'Неверный email или пароль';
      case 'invalid-email':
        return 'Некорректный email';
      default:
        return 'Ошибка: $code';
    }
  }
}