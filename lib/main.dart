import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  OneSignal.initialize('a171af7d-69c0-40e1-85af-b4dfcbf67a01');
  OneSignal.Notifications.requestPermission(true);

  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Наш чат',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2AABEE),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2AABEE),
        brightness: Brightness.dark,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return FutureBuilder(
              future: AuthService().ensureUserCode(),
              builder: (context, _) => const _HeartbeatWrapper(
                child: ChatListScreen(),
              ),
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

/// Поддерживает поле lastActive свежим, пока приложение открыто и активно.
/// Статус "в сети" в интерфейсе показывается по свежести этой метки, а не
/// только по флагу online — так статус сам "протухает", если приложение
/// закрыли без явного выхода (сворачивание, аварийное закрытие и т.д.)
class _HeartbeatWrapper extends StatefulWidget {
  final Widget child;
  const _HeartbeatWrapper({required this.child});

  @override
  State<_HeartbeatWrapper> createState() => _HeartbeatWrapperState();
}

class _HeartbeatWrapperState extends State<_HeartbeatWrapper>
    with WidgetsBindingObserver {
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sendHeartbeat();
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendHeartbeat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // тихо игнорируем — не критично, следующий тик попробует снова
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendHeartbeat();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}