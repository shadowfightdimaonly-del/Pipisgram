import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Простая встроенная консоль: полезные dev/debug-команды прямо в приложении,
/// без необходимости лезть в adb logcat. Список команд легко расширять.
class CommandLineScreen extends StatefulWidget {
  const CommandLineScreen({super.key});

  @override
  State<CommandLineScreen> createState() => _CommandLineScreenState();
}

class _CommandLineScreenState extends State<CommandLineScreen> {
  final _inputCtrl = TextEditingController();
  final List<String> _log = [
    '> система готова. напиши "help" для списка команд',
  ];
  final _scrollCtrl = ScrollController();

  void _print(String line) {
    setState(() => _log.add(line));
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runCommand(String raw) async {
    final cmd = raw.trim();
    if (cmd.isEmpty) return;
    _print('\$ $cmd');

    final parts = cmd.split(' ');
    switch (parts.first.toLowerCase()) {
      case 'help':
        _print('''
доступные команды:
  whoami          — показать текущего пользователя (uid, email)
  ping            — проверить связь с Firestore
  clear           — очистить консоль
  users count     — сколько всего зарегистрировано пользователей
  version         — версия приложения''');
        break;

      case 'whoami':
        final u = FirebaseAuth.instance.currentUser;
        _print('uid: ${u?.uid}\nemail: ${u?.email}');
        break;

      case 'clear':
        setState(() => _log.clear());
        break;

      case 'version':
        _print('chatapp v1.0.0+1 (MVP)');
        break;

      case 'ping':
        final sw = Stopwatch()..start();
        try {
          await FirebaseFirestore.instance.collection('users').limit(1).get();
          sw.stop();
          _print('pong — ${sw.elapsedMilliseconds}ms');
        } catch (e) {
          _print('ошибка соединения: $e');
        }
        break;

      case 'users':
        if (parts.length > 1 && parts[1] == 'count') {
          final snap =
              await FirebaseFirestore.instance.collection('users').count().get();
          _print('пользователей в базе: ${snap.count}');
        } else {
          _print('неизвестная подкоманда. попробуй: users count');
        }
        break;

      default:
        _print('неизвестная команда: "$cmd". напиши "help"');
    }

    _inputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text('Командная строка',
            style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
        iconTheme: const IconThemeData(color: Colors.greenAccent),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, i) => Text(
                _log[i],
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                const Text('\$ ',
                    style: TextStyle(
                        color: Colors.greenAccent, fontFamily: 'monospace')),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: const TextStyle(
                        color: Colors.greenAccent, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _runCommand,
                    autofocus: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
