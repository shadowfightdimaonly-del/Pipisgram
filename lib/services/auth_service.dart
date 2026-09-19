import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<String?> register(String email, String password, String username) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _db.collection('users').doc(cred.user!.uid).set({
        'username': username,
        'email': email,
        'online': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // без ошибок
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<String?> register(String email, String password, String username) async {
    // Проверяем уникальность username ДО создания аккаунта
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
      await _db.collection('users').doc(cred.user!.uid).set({
        'username': username,
        'email': email,
        'online': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // без ошибок
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
