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

  Future<Map<String, dynamic>?> _myData() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    return doc.data();
  }


  Future<DocumentSnapshot?> _findUserByUsername(String rawUsername) async {
    final username = rawUsername.replaceFirst('@', '').trim();
    final query = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }


  Future<void> _runCommand(String raw) async {
    final cmd = raw.trim();
    if (cmd.isEmpty) return;
    _print('\$ ${cmd.length > 30 ? "••••• (скрыто)" : cmd}');

    final lowerCmd = cmd.toLowerCase();
    final parts = cmd.split(' ');
    final command = parts.first.toLowerCase();

    switch (command) {
      case 'help':
        _print('''
доступные команды:
  whoami                    — свой публичный профиль
  whoami @ник                — профиль другого пользователя
  ping                        — проверить связь с Firestore
  clear                       — очистить консоль
  users count                 — сколько всего зарегистрировано
  version                     — версия приложения
  help                       — список этих команд''');
        break;

      case 'whoami':
        if (parts.length > 1) {
          final userDoc = await _findUserByUsername(parts[1]);
          if (userDoc == null) {
            _print('пользователь ${parts[1]} не найден');
          } else {
            final data = userDoc.data() as Map<String, dynamic>;
            _print('''
юзернейм: @${data['username']}
id: ${userDoc.id}''');
          }
        } else {
          final data = await _myData();
          _print('''
юзернейм: @${data?['username'] ?? '—'}
код: ${data?['userCode'] ?? '—'}
id: $_myUid''');
        }
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
        if (parts.length > 1 && parts[1] == 'count') {
          final snap = await _db.collection('users').count().get();
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


    final gift = _gifts[giftId]!;
    final price = gift['price'] as int;
    final requiresPremium = gift['requiresPremium'] == true;
    final buyerData = await _myData();
    final buyerStars = (buyerData?['shadowStars'] ?? 0) as int;

    if (requiresPremium && !_isPremiumActive(buyerData)) {
      _print('для покупки этого подарка нужен активный Pipisgram Premium');
      return;
    }
    if (buyerStars < price) {
      _print('недостаточно звёзд (нужно $price★, у тебя ${buyerStars}★)');
      return;
    }

    String? targetUid;
    if (targetUsername != null) {
      final targetDoc = await _findUserByUsername(targetUsername);
      if (targetDoc == null) {
        _print('пользователь $targetUsername не найден');
        return;
      }
      targetUid = targetDoc.id;
    }

    try {
      await _gamesService.economyAction(
        action: targetUid == null ? 'buy_gift' : 'gift',
        giftId: giftId,
        targetUid: targetUid,
      );
      if (targetUid != null) {
        final myUsernameForGiftItem = buyerData?['username'] ?? 'кто-то';
        PushNotificationService.sendToUser(
          targetUid: targetUid,
          title: 'Подарок! 🎁',
          body: '@$myUsernameForGiftItem подарил тебе "${gift['name']}"',
        );
      }
      _print(targetUsername == null
          ? '"${gift['name']}" куплен себе за $price★'
          : '"${gift['name']}" подарен $targetUsername за $price★');
    } catch (e) {
      _print('ошибка: $e');
    }
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