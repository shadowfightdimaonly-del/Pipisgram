import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mini_games_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _service = MiniGamesService();
  bool _loading = true, _premium = false, _buying = false;
  int? _registeredCount;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final doc = await _db.collection('users').doc(_uid).get();
    final data = doc.data() ?? {};
    final premium = data['isPremium'] == true ||
        (data['premiumUntil'] is Timestamp &&
            (data['premiumUntil'] as Timestamp).toDate().isAfter(DateTime.now()));
    if (premium) {
      try { _registeredCount = await _service.getRegisteredUsersCount(); } catch (_) {}
    }
    if (mounted) setState(() { _premium = premium; _loading = false; });
  }

  Future<void> _buy() async {
    if (_buying || _premium) return;
    setState(() => _buying = true);
    try {
      await _service.economyAction(action: 'buy_premium');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium активирован 💎')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось купить Premium: $e')),
      );
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Widget _feature(IconData icon, String title, String text) => ListTile(
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(text),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pipis Premium 💎')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    const Icon(Icons.workspace_premium, size: 64),
                    const SizedBox(height: 10),
                    Text(_premium ? 'Premium активен' : 'Pipis Premium',
                        style: const TextStyle(fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    if (!_premium) ...[
                      const SizedBox(height: 8),
                      const Text('750 ядер навсегда',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _buying ? null : _buy,
                        icon: const Icon(Icons.stars),
                        label: Text(_buying ? 'Покупка...' : 'Купить Premium'),
                      ),
                    ],
                  ]),
                )),
                const SizedBox(height: 12),
                _feature(Icons.touch_app, 'Кликер',
                    'Лимит увеличивается с 250 до 500 тапов в день.'),
                _feature(Icons.numbers, 'Угадайка',
                    '6 попыток вместо 3. С подарком №5 получается 9.'),
                _feature(Icons.directions_run, 'Ночной бег',
                    '1 ядро за прыжок вместо 0,5 ядра. Лимита на Dino нет.'),
                _feature(Icons.people, 'Счётчик пользователей',
                    _registeredCount == null
                        ? 'Показывается после активации Premium.'
                        : 'Сейчас зарегистрировано: $_registeredCount'),
                _feature(Icons.emoji_emotions, 'Мои эмодзи',
                    'Лимит увеличивается с 12 до 24.'),
                _feature(Icons.card_giftcard, 'Скидка на подарки',
                    'Все подарки дешевле на 25 ядер.'),
              ],
            ),
    );
  }
}
