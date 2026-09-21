import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/mini_games_service.dart';

class GuessNumberGameScreen extends StatefulWidget {
  const GuessNumberGameScreen({super.key});

  @override
  State<GuessNumberGameScreen> createState() => _GuessNumberGameScreenState();
}

class _GuessNumberGameScreenState extends State<GuessNumberGameScreen> {
  final _service = MiniGamesService();
  int _attemptsLeft = 3;
  bool _loading = true;
  bool _guessing = false;
  String? _lastResult;
  int? _selectedNumber;
  bool? _lastWon;

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    try {
      final left = await _service.getGuessAttemptsLeft();
      if (mounted) {
        setState(() {
          _attemptsLeft = left;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить попытки, попробуй ещё раз')),
        );
      }
    }
  }

  Future<void> _guess(int number) async {
    if (_attemptsLeft <= 0 || _guessing) return;

    setState(() {
      _guessing = true;
      _selectedNumber = number;
      _lastResult = null;
    });

    try {
      final allowed = await _service.useGuessAttempt();
      if (!allowed) {
        if (mounted) {
          setState(() {
            _guessing = false;
            _attemptsLeft = 0;
            _selectedNumber = null;
          });
        }
        return;
      }

      final secretNumber = Random().nextInt(15) + 1;
      final won = number == secretNumber;

      if (won) {
        await _service.rewardGuessWin();
      }

      final newAttemptsLeft = await _service.getGuessAttemptsLeft();

      if (mounted) {
        setState(() {
          _guessing = false;
          _attemptsLeft = newAttemptsLeft;
          _lastWon = won;
          _lastResult = won
              ? 'Угадал! Загаданное число было $secretNumber. +1★'
              : 'Не угадал. Загаданное число было $secretNumber';
          _selectedNumber = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _guessing = false;
          _selectedNumber = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка соединения, попытка не потрачена')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Угадай число')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Осталось попыток сегодня: $_attemptsLeft / 3',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Загадано число от 1 до 15. Угадаешь — получишь 1★.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: List.generate(15, (i) {
                      final number = i + 1;
                      final isDisabled = _attemptsLeft <= 0 || _guessing;
                      final isSelected = _selectedNumber == number;
                      return GestureDetector(
                        onTap: isDisabled ? null : () => _guess(number),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDisabled && !isSelected
                                ? Colors.grey.shade300
                                : (isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant),
                          ),
                          child: isSelected && _guessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text('$number',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : null,
                                  )),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  if (_lastResult != null)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (_lastWon == true ? Colors.green : Colors.orange)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _lastWon == true ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _lastWon == true
                                ? Icons.celebration
                                : Icons.info_outline,
                            color: _lastWon == true ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _lastResult!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_attemptsLeft <= 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Попытки на сегодня закончились, приходи завтра!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}