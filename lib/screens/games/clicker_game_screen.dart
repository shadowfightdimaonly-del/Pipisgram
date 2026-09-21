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
  bool _cashingOut = false;
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
      if (mounted) {
        setState(() {
          _tapsToday = taps;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tap() async {
    if (_tapsToday >= 1000) return;
    _bounceCtrl.reverse().then((_) => _bounceCtrl.forward());
    // Оптимистично увеличиваем счётчик сразу, чтобы тап ощущался мгновенно
    setState(() => _tapsThisSession++);
    try {
      final newCount = await _service.registerClickerTap();
      if (mounted) setState(() => _tapsToday = newCount);
    } catch (e) {
      // Если сервер не подтвердил тап — откатываем сессионный счётчик,
      // чтобы не показывать звёзды, которые реально не засчитались
      if (mounted) setState(() => _tapsThisSession--);
    }
  }

  Future<void> _cashOut() async {
    if (_tapsThisSession == 0 || _cashingOut) return;
    setState(() => _cashingOut = true);

    final earned = (_tapsThisSession * 0.3).floor();
    try {
      await _service.cashOutClickerStars(_tapsThisSession);
      if (mounted) {
        setState(() {
          _tapsThisSession = 0;
          _cashingOut = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Получено $earned★!'),
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
            content: Text('Не удалось вывести звёзды, попробуй ещё раз'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                      Text('Тапов сегодня (общий лимит): $_tapsToday / 1000',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                          'Накоплено с последнего вывода: $_tapsThisSession тапов = $sessionStars★',
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
                    onPressed: (_tapsThisSession > 0 && !_cashingOut)
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
                        _cashingOut ? 'Забираем...' : 'Забрать $sessionStars★'),
                  ),
                ),
              ],
            ),
    );
  }
}