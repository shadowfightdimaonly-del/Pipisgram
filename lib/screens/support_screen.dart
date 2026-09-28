import 'package:flutter/material.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поддержка')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('Новое обращение'),
              subtitle: const Text('Создать тикет в поддержку'),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
