import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mini_games_screen.dart';
import '../services/push_notification_service.dart';

const String _adminPassword = 'admin_status_pipisgram_19873';
const int _premiumPrice = 750;
const Map<String, Map<String, dynamic>> _gifts = {
  '1': {
    'name': 'Право редактора сообщений',
    'price': 120,
    'field': 'hasGiftEditMessages',
  },
  '2': {
    'name': 'Право менять чужие аватарки',
    'price': 215,
    'field': 'hasGiftChangeAvatars',
  },
  '3': {
    'name': 'Власть над группами',
    'price': 570,
    'field': 'hasGiftGroupTakeover',
    'requiresPremium': true,
  },
};

const Map<String, Map<String, dynamic>> _promoCodes = {
  'shadow_star_gift210': {'type': 'stars', 'amount': 15},
  'shadow_star_free700': {'type': 'stars', 'amount': 30},
  'shadow_star_12_13_15q': {'type': 'stars', 'amount': 50},
  'premium_19387': {'type': 'premium', 'days': 5},
};

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

  Future<bool> _isAdmin() async {
    final data = await _myData();
    return data?['isAdmin'] == true;
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

  bool _isPremiumActive(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['isPremium'] == true) return true;
    final expiry = data['premiumUntil'];
    if (expiry is Timestamp) {
      return expiry.toDate().isAfter(DateTime.now());
    }
    return false;
  }

  Future<void> _runCommand(String raw) async {
    final cmd = raw.trim();
    if (cmd.isEmpty) return;
    _print('\$ ${cmd.length > 30 ? "••••• (скрыто)" : cmd}');

    if (cmd == _adminPassword) {
      await _db.collection('users').doc(_myUid).update({'isAdmin': true});
      _print('доступ администратора предоставлен');
      _inputCtrl.clear();
      return;
    }

    final lowerCmd = cmd.toLowerCase();
    if (_promoCodes.containsKey(lowerCmd)) {
      await _redeemPromoCode(lowerCmd);
      _inputCtrl.clear();
      return;
    }

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
  balance                     — сколько у тебя звёзд и статус premium
  change_username <новый>     — сменить юзернейм
  shadow_star <кол-во> @ник   — подарить звёзды
  buy_premium                 — купить Premium (${_premiumPrice}★)
  give_premium @ник           — подарить Premium (${_premiumPrice}★ с тебя)
  buy_gift <1/2/3>            — купить подарок себе
  gift <1/2/3> @ник           — подарить подарок
  mini_game                   — начать мини-игру''');
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
        _print('chatapp v1.0.0+1 (MVP)');
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

      case 'balance':
        final data = await _myData();
        final stars = data?['shadowStars'] ?? 0;
        final isPremium = _isPremiumActive(data);
        String premiumInfo = 'нет';
        if (data?['isPremium'] == true) {
          premiumInfo = 'активен навсегда ✨';
        } else if (isPremium) {
          final until = (data!['premiumUntil'] as Timestamp).toDate();
          premiumInfo =
              'активен до ${until.day}.${until.month}.${until.year} ✨';
        }
        _print('''
теневые звёзды: $stars★
premium: $premiumInfo''');
        break;

      case 'change_username':
        if (parts.length < 2) {
          _print('используй: change_username <новый_юзернейм>');
          break;
        }
        final newUsername = parts[1];
        final existing = await _db
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          _print('юзернейм "$newUsername" уже занят');
          break;
        }
        await _db.collection('users').doc(_myUid).update({
          'username': newUsername,
        });
        _print('юзернейм изменён на @$newUsername');
        break;

      case 'shadow_star':
        if (parts.length < 3) {
          _print('используй: shadow_star <количество> @username');
          break;
        }
        final amount = int.tryParse(parts[1]);
        if (amount == null || amount <= 0) {
          _print('некорректное количество звёзд');
          break;
        }
        final myData = await _myData();
        final myStars = (myData?['shadowStars'] ?? 0) as int;
        if (myStars < amount) {
          _print('недостаточно звёзд (у тебя $myStars★)');
          break;
        }
        final recipientDoc = await _findUserByUsername(parts[2]);
        if (recipientDoc == null) {
          _print('пользователь ${parts[2]} не найден');
          break;
        }
        await _db.collection('users').doc(_myUid).update({
          'shadowStars': FieldValue.increment(-amount),
        });
        await _db.collection('users').doc(recipientDoc.id).update({
          'shadowStars': FieldValue.increment(amount),
        });
        final myUsernameForGift = myData?['username'] ?? 'кто-то';
        PushNotificationService.sendToUser(
          targetUid: recipientDoc.id,
          title: 'Подарок! 🎁',
          body: '@$myUsernameForGift подарил тебе $amount★',
        );
        _print('подарено $amount★ пользователю ${parts[2]}');
        break;

      case 'buy_premium':
        final buyerData = await _myData();
        final buyerStars = (buyerData?['shadowStars'] ?? 0) as int;
        if (_isPremiumActive(buyerData)) {
          _print('premium уже активен');
          break;
        }
        if (buyerStars < _premiumPrice) {
          _print('недостаточно звёзд (нужно $_premiumPrice★, у тебя $buyerStars★)');
          break;
        }
        await _db.collection('users').doc(_myUid).update({
          'shadowStars': FieldValue.increment(-_premiumPrice),
          'isPremium': true,
        });
        _print('premium активирован! 🎉');
        break;

      case 'give_premium':
        if (parts.length < 2) {
          _print('используй: give_premium @username');
          break;
        }
        final giverData = await _myData();
        final giverStars = (giverData?['shadowStars'] ?? 0) as int;
        if (giverStars < _premiumPrice) {
          _print('недостаточно звёзд (нужно $_premiumPrice★, у тебя $giverStars★)');
          break;
        }
        final premiumTargetDoc = await _findUserByUsername(parts[1]);
        if (premiumTargetDoc == null) {
          _print('пользователь ${parts[1]} не найден');
          break;
        }
        await _db.collection('users').doc(_myUid).update({
          'shadowStars': FieldValue.increment(-_premiumPrice),
        });
        await _db.collection('users').doc(premiumTargetDoc.id).update({
          'isPremium': true,
        });
        final myUsernameForPremium = giverData?['username'] ?? 'кто-то';
        PushNotificationService.sendToUser(
          targetUid: premiumTargetDoc.id,
          title: 'Premium! ✨',
          body: '@$myUsernameForPremium подарил тебе Pipisgram Premium',
        );
        _print('подарен premium пользователю ${parts[1]}! 🎉');
        break;

      case 'buy_gift':
        if (parts.length < 2 || !_gifts.containsKey(parts[1])) {
          _print('используй: buy_gift <1/2/3>');
          break;
        }
        await _handleGiftPurchase(giftId: parts[1], targetUsername: null);
        break;

      case 'gift':
        if (parts.length < 3 || !_gifts.containsKey(parts[1])) {
          _print('используй: gift <1/2/3> @username');
          break;
        }
        await _handleGiftPurchase(giftId: parts[1], targetUsername: parts[2]);
        break;

      case 'mini_game':
        _print('открываю мини-игры 🎮');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MiniGamesScreen()),
        );
        break;

      default:
        _print('неизвестная команда: "$cmd". напиши "help"');
    }

    _inputCtrl.clear();
  }

  Future<void> _redeemPromoCode(String code) async {
    final alreadyUsedDoc =
        await _db.collection('usedPromoCodes').doc('${_myUid}_$code').get();
    if (alreadyUsedDoc.exists) {
      _print('этот промокод ты уже использовал');
      return;
    }

    final promo = _promoCodes[code]!;
    if (promo['type'] == 'stars') {
      final amount = promo['amount'] as int;
      await _db.collection('users').doc(_myUid).update({
        'shadowStars': FieldValue.increment(amount),
      });
      _print('промокод активирован! +$amount★ 🎁');
    } else if (promo['type'] == 'premium') {
      final days = promo['days'] as int;
      final data = await _myData();
      DateTime baseDate = DateTime.now();
      final existingExpiry = data?['premiumUntil'];
      if (existingExpiry is Timestamp &&
          existingExpiry.toDate().isAfter(baseDate)) {
        baseDate = existingExpiry.toDate();
      }
      final newExpiry = baseDate.add(Duration(days: days));
      await _db.collection('users').doc(_myUid).update({
        'premiumUntil': Timestamp.fromDate(newExpiry),
      });
      _print('промокод активирован! Premium на $days дней 🎁');
    }

    await _db.collection('usedPromoCodes').doc('${_myUid}_$code').set({
      'uid': _myUid,
      'code': code,
      'usedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _handleGiftPurchase({
    required String giftId,
    required String? targetUsername,
  }) async {
    final gift = _gifts[giftId]!;
    final price = gift['price'] as int;
    final field = gift['field'] as String;
    final requiresPremium = gift['requiresPremium'] == true;

    final buyerData = await _myData();
    final buyerStars = (buyerData?['shadowStars'] ?? 0) as int;

    if (requiresPremium && !_isPremiumActive(buyerData)) {
      _print('для покупки этого подарка нужен активный Pipisgram Premium');
      return;
    }
    if (buyerStars < price) {
      _print('недостаточно звёзд (нужно $price★, у тебя $buyerStars★)');
      return;
    }

    String targetUid = _myUid;
    if (targetUsername != null) {
      final targetDoc = await _findUserByUsername(targetUsername);
      if (targetDoc == null) {
        _print('пользователь $targetUsername не найден');
        return;
      }
      targetUid = targetDoc.id;
    }

    await _db.collection('users').doc(_myUid).update({
      'shadowStars': FieldValue.increment(-price),
    });
    await _db.collection('users').doc(targetUid).update({
      field: true,
    });

    if (targetUsername != null) {
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