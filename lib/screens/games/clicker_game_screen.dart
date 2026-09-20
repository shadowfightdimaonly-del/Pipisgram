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
  int _tapsThisSession = 0;
  bool _loading = true;
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
    final taps = await _service.getClickerTapsToday();
    setState(() {
      _tapsToday = taps;
      _loading = false;
    });
  }

  Future<void> _tap() async {
    if (_tapsToday >= 1000) return;
    _bounceCtrl.reverse().then((_) => _bounceCtrl.forward());
    final newCount = await _service.registerClickerTap();
    setState(() {
      _tapsToday = newCount;
      _tapsThisSession++;
    });
  }

  Future<void> _cashOut() async {
    if (_tapsThisSession == 0) return;
    await _service.cashOutClickerStars(_tapsThisSession);
    final earned = (_tapsThisSession * 0.3).floor();
    setState(() => _tapsThisSession = 0);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Получено $earned★')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitReached = _tapsToday >= 1000;
    final sessionStars = (_tapsThisSession * 0.3).floor();

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
                      Text('Тапов сегодня: $_tapsToday / 1000',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('За эту сессию: $_tapsThisSession тапов = $sessionStars★',
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
                  child: FilledButton(
                    onPressed: _tapsThisSession > 0 ? _cashOut : null,
                    child: Text('Забрать $sessionStars★'),
                  ),
                ),
              ],
            ),
    );
  }
}
