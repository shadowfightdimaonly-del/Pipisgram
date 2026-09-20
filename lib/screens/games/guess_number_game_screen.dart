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

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    final left = await _service.getGuessAttemptsLeft();
    setState(() {
      _attemptsLeft = left;
      _loading = false;
    });
  }

  Future<void> _guess(int number) async {
    if (_attemptsLeft <= 0 || _guessing) return;

    setState(() {
      _guessing = true;
      _selectedNumber = number;
    });

    final allowed = await _service.useGuessAttempt();
    if (!allowed) {
      setState(() {
        _guessing = false;
        _attemptsLeft = 0;
      });
      return;
    }

    final secretNumber = Random().nextInt(15) + 1;
    final won = number == secretNumber;

    if (won) {
      await _service.rewardGuessWin();
    }

    final newAttemptsLeft = await _service.getGuessAttemptsLeft();

    setState(() {
      _guessing = false;
      _attemptsLeft = newAttemptsLeft;
      _lastResult = won
          ? 'Угадал! Загаданное число было $secretNumber. +1★'
          : 'Не угадал. Загаданное число было $secretNumber';
      _selectedNumber = null;
    });
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
                            color: isDisabled
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
                                      strokeWidth: 2),
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
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _lastResult!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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