import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/mini_games_service.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});
  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftInfo {
  final String id, title, property, field;
  final int price;
  final bool premiumOnly;
  const _GiftInfo({
    required this.id, required this.title, required this.property,
    required this.price, required this.field, this.premiumOnly = false,
  });
}

const _giftCatalog = [
  _GiftInfo(id: '1', title: 'Право редактора сообщений',
      property: 'Позволяет редактировать сообщения.', price: 125,
      field: 'hasGiftEditMessages'),
  _GiftInfo(id: '2', title: 'Право менять аватарки',
      property: 'Позволяет менять аватарки другим участникам.', price: 215,
      field: 'hasGiftChangeAvatars'),
  _GiftInfo(id: '3', title: 'Власть над группами',
      property: 'Открывает расширенные возможности управления группами.',
      price: 570, field: 'hasGiftGroupTakeover', premiumOnly: true),
  _GiftInfo(id: '4', title: 'Право менять юзернеймы',
      property: 'Позволяет менять юзернеймы другим участникам.', price: 150,
      field: 'hasGiftChangeUsernames'),
  _GiftInfo(id: '5', title: 'Двойные попытки в угадайке',
      property: 'Даёт ещё 3 попытки поверх обычного лимита.', price: 235,
      field: 'hasGiftDoubleGuessAttempts'),
];

class _GiftsScreenState extends State<GiftsScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _service = MiniGamesService();
  final _pageController = PageController(viewportFraction: 0.88);

  bool _premium = false, _loading = true;
  int _index = 0;
  String? _buying;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  Future<void> _load() async {
    final doc = await _db.collection('users').doc(_uid).get();
    final data = doc.data() ?? {};
    final premium = data['isPremium'] == true ||
        (data['premiumUntil'] is Timestamp &&
            (data['premiumUntil'] as Timestamp).toDate().isAfter(DateTime.now()));
    if (mounted) setState(() { _premium = premium; _loading = false; });
  }

  Future<void> _buy(_GiftInfo gift, Map<String, dynamic> data) async {
    if (data[gift.field] == true || _buying != null) return;
    if (gift.premiumOnly && !_premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для этого подарка нужен Premium')),
      );
      return;
    }
    setState(() => _buying = gift.id);
    try {
      final result = await _service.economyAction(
        action: 'buy_gift', giftId: gift.id,
      );
      if (mounted) {
        final price = (result['price'] as num?)?.toInt() ?? gift.price;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Подарок куплен за $price ядер 🎁')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось купить: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подарки 🎁')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(_uid).snapshots(),
        builder: (context, snap) {
          final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
          if (_loading) return const Center(child: CircularProgressIndicator());

          return Column(
            children: [
              const SizedBox(height: 14),
              Text('${_index + 1} / ${_giftCatalog.length}',
                  style: const TextStyle(color: Colors.grey)),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _giftCatalog.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final item = _giftCatalog[i];
                    final owned = data[item.field] == true;
                    final price = _premium ? item.price - 25 : item.price;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 18),
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.card_giftcard, size: 72),
                              const SizedBox(height: 18),
                              Text(item.title, textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 14),
                              Text(item.property, textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 16),
                              if (item.premiumOnly)
                                const Chip(
                                  avatar: Icon(Icons.workspace_premium, size: 18),
                                  label: Text('Требуется Premium'),
                                ),
                              if (_premium)
                                Text('${item.price} ядер',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  )),
                              Text('$price ядер', style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: owned || _buying != null
                                    ? null : () => _buy(item, data),
                                icon: _buying == item.id
                                    ? const SizedBox(width: 18, height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.stars),
                                label: Text(owned ? 'Куплено ✓' : 'Купить'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Text('Листай карточки влево и вправо',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }
}
