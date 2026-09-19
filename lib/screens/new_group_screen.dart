import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/app_user.dart';
import 'chat_screen.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _chatService = ChatService();
  final _groupNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  final List<AppUser> _members = [];
  bool _searching = false;
  bool _creating = false;
  String? _error;

  Future<void> _addMember() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
    });

    final user = await _chatService.findUserByUsername(username);

    setState(() => _searching = false);

    if (user == null) {
      setState(() => _error = 'Пользователь не найден');
      return;
    }
    if (_members.any((m) => m.uid == user.uid)) {
      setState(() => _error = 'Уже добавлен');
      return;
    }

    setState(() {
      _members.add(user);
      _usernameCtrl.clear();
    });
  }

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введи название группы');
      return;
    }
    if (_members.isEmpty) {
      setState(() => _error = 'Добавь хотя бы одного участника');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    final chatId = await _chatService.createGroup(
      name,
      _members.map((m) => m.uid).toList(),
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, otherUsername: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая группа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _groupNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название группы',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(
                      labelText: '@юзернейм участника',
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _searching
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                  onPressed: _searching ? null : _addMember,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_members.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(member.username[0].toUpperCase()),
                      ),
                      title: Text('@${member.username}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _members.removeAt(index)),
                      ),
                    );
                  },
                ),
              ),
            FilledButton(
              onPressed: _creating ? null : _createGroup,
              child: _creating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Создать группу'),
            ),
          ],
        ),
      ),
    );
  }
}