import 'package:flutter/material.dart';
import '../../services/mini_games_service.dart';

class ClickerGameScreen extends StatefulWidget {
  const ClickerGameScreen({super.key});

  @override
  State<ClickerGameScreen> createState() => _ClickerGameScreenState();
}

class _ClickerGameScreenState extends State<ClickerGameScreen>
    with SingleTickerProviderStateMixin {
  final _service = MiniGamesService();
  int _tapsToday = 0;
  int _availableTaps = 0;
  int _maxTaps = 250;
  bool _loading = true;
  bool _cashingOut = false;
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _tapCooldown = Duration(milliseconds: 400);
  late AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.9,
      upperBound: 1.0,
    )..value = 1.0;
    _loadTaps();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTaps() async {
    try {
      final taps = await _service.getClickerTapsToday();
      final available = await _service.getClickerAvailableTaps();
      final maxTaps = await _service.getClickerMaxTaps();
      if (mounted) {
        setState(() {
          _tapsToday = taps;
          _availableTaps = available;
          _maxTaps = maxTaps;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tap() async {
    if (_tapsToday >= _maxTaps) return;

    final now = DateTime.now();
    if (now.difference(_lastTapAt) < _tapCooldown) return;
    _lastTapAt = now;

    _bounceCtrl.reverse().then((_) => _bounceCtrl.forward());
    try {
      final previousCount = _tapsToday;
      final newCount = await _service.registerClickerTap();
      if (mounted) {
        setState(() {
          _tapsToday = newCount;
          if (newCount > previousCount) {
            _availableTaps++;
          }
        });
      }
    } catch (e) {
      // Сервер не подтвердил тап.
    }
  }

  Future<void> _cashOut() async {
    if (_availableTaps == 0 || _cashingOut) return;
    setState(() => _cashingOut = true);

    try {
      final earned = await _service.cashOutClickerStars();
      final remaining = await _service.getClickerAvailableTaps();
      if (mounted) {
        setState(() {
          _availableTaps = remaining;
          _cashingOut = false;
        });
        if (earned <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пока недостаточно тапов для вывода')),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Получено $earned ядер!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cashingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось вывести ядра, попробуй ещё раз'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitReached = _tapsToday >= _maxTaps;
    final availableStars = (_availableTaps * 3) ~/ 10;

    return Scaffold(
      appBar: AppBar(title: const Text('Кликер')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Тапов сегодня (общий лимит): $_tapsToday / $_maxTaps',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                          'Доступно к выводу: $_availableTaps тапов = $availableStars ядер',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: limitReached ? null : _tap,
                      child: ScaleTransition(
                        scale: _bounceCtrl,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: limitReached
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: (limitReached
                                        ? Colors.grey
                                        : Theme.of(context).colorScheme.primary)
                                    .withOpacity(0.5),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              limitReached ? 'Лимит\nна сегодня' : 'ТАП',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: (_availableTaps > 0 && !_cashingOut)
                        ? _cashOut
                        : null,
                    icon: _cashingOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.stars),
                    label: Text(
                        _cashingOut ? 'Забираем...' : 'Забрать $availableStars ядер'),
                  ),
                ),
              ],
            ),
    );
  }
}