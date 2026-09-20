import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

      final showStatus = data?['showOnlineStatus'] ?? true;
      final updates = <String, dynamic>{};
      if (showStatus) {
        updates['online'] = true;
      }

      // Довыдача кода для аккаунтов, созданных до введения этой функции
      if (data != null && (data['userCode'] == null || data['userCode'] == '')) {
        updates['userCode'] = await _generateUniqueCode();
      }

      if (updates.isNotEmpty) {
        await userRef.update(updates);
      }

      await OneSignal.login(_auth.currentUser!.uid);

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<void> logout() async {
    if (currentUser != null) {
      await _db.collection('users').doc(currentUser!.uid).update({
        'online': false,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await OneSignal.logout();
    await _auth.signOut();
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