import 'package:flutter/material.dart';
import 'games/clicker_game_screen.dart';
import 'games/guess_number_game_screen.dart';
import 'games/dino_game_screen.dart';

class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мини-игры')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GameCard(
            icon: Icons.touch_app,
            color: Colors.blueAccent,
            title: 'Кликер',
            subtitle: '0.3★ за тап · до 1000 тапов в день',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClickerGameScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _GameCard(
            icon: Icons.directions_run,
            color: Colors.deepPurpleAccent,
            title: 'Ночной бег',
            subtitle: '0.5★ за прыжок · без лимита',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DinoGameScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _GameCard(
            icon: Icons.casino,
            color: Colors.orangeAccent,
            title: 'Угадай число',
            subtitle: '1-15 · 1★ за угадывание · 3 попытки в день',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const GuessNumberGameScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}