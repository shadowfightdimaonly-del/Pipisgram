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
    final mainCommand = parts.first.toLowerCase();

    // ⚡ ПАСХАЛКА: Обработка твоих секретных кодов интерфейса прямо в терминале!
    if (mainCommand == 'sonne') {
      _print('🪐 HIER KOMMT DIE SONNE... Скин Сириуса активирован в кэше!');
      _inputCtrl.clear();
      return;
    } else if (mainCommand == 'bad' && parts.length > 1 && parts[1].toLowerCase() == 'time') {
      _print('💀 Вы собираетесь хорошо провести время. Скин Санса готов!');
      _inputCtrl.clear();
      return;
    } else if (mainCommand == 'murder!') {
      _print('🔮 MURDER! В воздухе пахнет фиолетовой пылью Даста...');
      _inputCtrl.clear();
      return;
    }

    switch (mainCommand) {
      case 'help':
        _print('''
доступные команды:
  whoami          — инфо о себе (без палева почты)
  whoami @username— найти профиль пользователя в Pipisgram
  ping            — проверить связь с Firestore
  clear           — очистить консоль
  users count     — сколько всего зарегистрировано пользователей
  version         — версия приложения''');
        break;

      case 'whoami':
        final u = FirebaseAuth.instance.currentUser;
        if (u == null) {
          _print('ошибка: вы не авторизованы.');
          break;
        }

        // Если ввели просто "whoami" — показываем инфу о самом себе из Firestore
        if (parts.length == 1) {
          try {
            final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
            final name = doc.data()?['username'] ?? 'Без имени';
            final hasPremium = doc.data()?['hasPremium'] ?? false;
            
            _print('-----------------------------------------');
            _print('ℹ️ ТВОЙ СЕКРЕТНЫЙ ПРОФИЛЬ PIPISGRAM:');
            _print('👤 Имя в базе: $name');
            _print('🆔 Твой цифровой ID: ${u.uid.substring(0, 8)}... (Защищено)');
            _print('👑 Премиум статус: ${hasPremium ? "АКТИВЕН 🐾" : "Обычный юзер"}');
            _print('🔒 Google Email скрыт ради безопасности!');
            _print('-----------------------------------------');
          } catch (e) {
            // Если документ еще не создан, выдаем базовый UID
            _print('uid: ${u.uid}\n🔒 Email скрыт из вывода.');
          }
        } 
        // Если ввели "whoami @username" — ищем чужой профиль в Pipisgram!
        else {
          final targetUser = parts[1];
          try {
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .where('username', isEqualTo: targetUser)
                .limit(1)
                .get();

            if (snap.docs.isNotEmpty) {
              final doc = snap.docs.first;
              final name = doc.data()['username'] ?? 'Без имени';
              final hasPremium = doc.data()['hasPremium'] ?? false;
              
              _print('-----------------------------------------');
              _print('🔎 НАЙДЕН ПОЛЬЗОВАТЕЛЬ PIPISGRAM:');
              _print('👤 Имя профиля: $name');
              _print('🆔 Системный ID: ${doc.id.substring(0, 8)}...');
              _print('💎 Имущество: ${hasPremium ? "Pipis Premium 👑" : "Нет"}');
              _print('-----------------------------------------');
            } else {
              _print('пользователь с юзернеймом $targetUser не найден.');
            }
          } catch (e) {
            _print('ошибка поиска: $e');
          }
        }
        break;

      case 'clear':
        setState(() => _log.clear());
        break;

      case 'version':
        _print('pipisgram v1.1.0 (Safe Version)');
        break;

      case 'ping':
        final sw = Stopwatch()..start();
        try {
          await FirebaseFirestore.instance.collection('users').limit(1).get();
          sw.stop();
          _print('pong — ${sw.elapsedMilliseconds}ms (Firebase напрямую)');
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
