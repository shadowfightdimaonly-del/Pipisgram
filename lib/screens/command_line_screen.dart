import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommandLineScreen extends StatefulWidget {
  const CommandLineScreen({super.key});
  @override
  State<CommandLineScreen> createState() => _CommandLineScreenState();
}

class _CommandLineScreenState extends State<CommandLineScreen> {
  final _inputCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser!.uid;
  final _log = <String>['> система готова. напиши "help" для списка команд'];
  final _scrollCtrl = ScrollController();

  void _print(String line) {
    if (!mounted) return;
    setState(() => _log.add(line));
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<Map<String, dynamic>?> _myData() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    return doc.data();
  }

  Future<void> _runCommand(String raw) async {
    final cmd = raw.trim();
    if (cmd.isEmpty) return;
    _print('\$ ${cmd.length > 30 ? "••••• (скрыто)" : cmd}');
    final parts = cmd.split(RegExp(r'\\s+'));
    final command = parts.first.toLowerCase();
    switch (command) {
      case 'help':
        _print('доступные команды:\n  whoami — свой профиль\n  ping — проверить связь\n  clear — очистить консоль\n  users count — количество пользователей\n  version — версия');
        break;
      case 'whoami':
        final data = await _myData();
        _print('юзернейм: @${data?['username'] ?? '—'}\nкод: ${data?['userCode'] ?? '—'}\nid: $_myUid');
        break;
      case 'clear':
        setState(() => _log.clear());
        break;
      case 'version':
        _print('chatapp v1.0.0+1');
        break;
      case 'ping':
        final sw = Stopwatch()..start();
        try {
          await _db.collection('users').limit(1).get();
          sw.stop();
          _print('pong — ${sw.elapsedMilliseconds}ms');
        } catch (e) {
          _print('ошибка соединения: $e');
        }
        break;
      case 'users':
        if (parts.length > 1 && parts[1].toLowerCase() == 'count') {
          try {
            final snap = await _db.collection('users').count().get();
            _print('пользователей в базе: ${snap.count}');
          } catch (e) {
            _print('ошибка: $e');
          }
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
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black87, title: const Text('Командная строка', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')), iconTheme: const IconThemeData(color: Colors.greenAccent)),
      body: Column(children: [
        Expanded(child: ListView.builder(controller: _scrollCtrl, padding: const EdgeInsets.all(12), itemCount: _log.length, itemBuilder: (context, i) => Text(_log[i], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13)))),
        Container(color: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Row(children: [
          const Text('\$ ', style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
          Expanded(child: TextField(controller: _inputCtrl, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'), decoration: const InputDecoration(border: InputBorder.none, isDense: true), onSubmitted: _runCommand, autofocus: true)),
        ])),
      ]),
    );
  }
}