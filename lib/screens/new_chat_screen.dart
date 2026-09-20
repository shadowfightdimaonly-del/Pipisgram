import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _chatService = ChatService();
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _startChat() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final user = await _chatService.findUserByCode(code);
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Пользователь с таким кодом не найден';
      });
      return;
    }

    final chatId = await _chatService.getOrCreateChat(user.uid);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUsername: user.username,
          otherUid: user.uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый чат')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Код друга (5 цифр)',
                hintText: 'например, 71957',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onSubmitted: (_) => _startChat(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _startChat,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Написать'),
            ),
          ],
        ),
      ),
    );
  }
}