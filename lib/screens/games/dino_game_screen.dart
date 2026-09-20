import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/mini_games_service.dart';

class DinoGameScreen extends StatefulWidget {
  const DinoGameScreen({super.key});

  @override
  State<DinoGameScreen> createState() => _DinoGameScreenState();
}

class _Obstacle {
  double x;
  _Obstacle(this.x);
}

class _DinoGameScreenState extends State<DinoGameScreen> {
  final _service = MiniGamesService();
  final _rnd = Random();

  static const double groundY = 0;
  static const double dinoWidth = 40;
  static const double dinoHeight = 44;
  static const double obstacleWidth = 20;
  static const double obstacleHeight = 40;
  static const double gravity = 0.9;
  static const double jumpVelocity = -14;

  Timer? _loopTimer;
  double _dinoY = 0;
  double _velocity = 0;
  bool _isJumping = false;
  bool _gameOver = false;
  bool _started = false;
  double _speed = 5;
  int _jumps = 0;
  int _score = 0;
  List<_Obstacle> _obstacles = [];
  final List<Offset> _stars = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 40; i++) {
      _stars.add(Offset(_rnd.nextDouble(), _rnd.nextDouble()));
    }
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _started = true;
      _gameOver = false;
      _dinoY = 0;
      _velocity = 0;
      _isJumping = false;
      _speed = 5;
      _jumps = 0;
      _score = 0;
      _obstacles = [_Obstacle(1.0)];
    });

    _loopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    if (_gameOver) return;

    setState(() {
      // Физика прыжка
      if (_isJumping) {
        _dinoY += _velocity;
        _velocity += gravity;
        if (_dinoY >= 0) {
          _dinoY = 0;
          _velocity = 0;
          _isJumping = false;
        }
      }

      // Движение препятствий
      final screenWidthFactor = 0.012 * (_speed / 5);
      for (var obs in _obstacles) {
        obs.x -= screenWidthFactor;
      }

      // Удаляем ушедшие за экран, засчитываем прыжок
      final passed = _obstacles.where((o) => o.x < -0.1).toList();
      for (var _ in passed) {
        _jumps++;
        _score++;
      }
      _obstacles.removeWhere((o) => o.x < -0.1);

      // Добавляем новое препятствие
      if (_obstacles.isEmpty || _obstacles.last.x < 0.6) {
        if (_rnd.nextDouble() < 0.02) {
          _obstacles.add(_Obstacle(1.0));
        }
      }

      // Постепенное ускорение
      _speed += 0.001;

      // Проверка столкновения (упрощённая, по x-координате возле динозаврика)
      for (var obs in _obstacles) {
        if (obs.x > 0.05 && obs.x < 0.16) {
          // динозаврик примерно на x=0.1, если не в прыжке — столкновение
          if (_dinoY > -20) {
            _endGame();
            return;
          }
        }
      }
    });
  }

  void _jump() {
    if (!_started) {
      _startGame();
      return;
    }
    if (_gameOver) {
      _startGame();
      return;
    }
    if (!_isJumping) {
      setState(() {
        _isJumping = true;
        _velocity = jumpVelocity;
      });
    }
  }

  void _endGame() {
    _loopTimer?.cancel();
    setState(() => _gameOver = true);
  }

  Future<void> _cashOut() async {
    if (_jumps == 0) return;
    await _service.cashOutDinoStars(_jumps);
    final earned = (_jumps * 0.5).floor();
    setState(() => _jumps = 0);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Получено $earned★')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionStars = (_jumps * 0.5).floor();

    return Scaffold(
      appBar: AppBar(title: const Text('Ночной бег')),
      backgroundColor: const Color(0xFF1A1033),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Прыжков: $_jumps = $sessionStars★',
                    style: const TextStyle(color: Colors.white)),
                FilledButton(
                  onPressed: _jumps > 0 ? _cashOut : null,
                  child: Text('Забрать $sessionStars★'),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _jump,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final groundLevel = h * 0.75;

                  return Stack(
                    children: [
                      // Фон — тёмно-фиолетовое небо со звёздами
                      Container(color: const Color(0xFF1A1033)),
                      ..._stars.map((s) => Positioned(
                            left: s.dx * w,
                            top: s.dy * groundLevel,
                            child: Container(
                              width: 2,
                              height: 2,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          )),
                      // Земля
                      Positioned(
                        left: 0,
                        right: 0,
                        top: groundLevel,
                        child: Container(height: 2, color: Colors.white24),
                      ),
                      // Динозаврик
                      Positioned(
                        left: w * 0.1 - dinoWidth / 2,
                        top: groundLevel - dinoHeight + _dinoY,
                        child: Container(
                          width: dinoWidth,
                          height: dinoHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Препятствия (шипы)
                      ..._obstacles.map((obs) => Positioned(
                            left: obs.x * w - obstacleWidth / 2,
                            top: groundLevel - obstacleHeight,
                            child: CustomPaint(
                              size: const Size(obstacleWidth, obstacleHeight),
                              painter: _SpikePainter(),
                            ),
                          )),
                      // Оверлеи состояния
                      if (!_started)
                        const Center(
                          child: Text('Нажми, чтобы начать',
                              style: TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                      if (_gameOver)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Игра окончена — счёт $_score',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 18)),
                              const SizedBox(height: 8),
                              const Text('Нажми, чтобы начать заново',
                                  style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpikePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2979FF)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}