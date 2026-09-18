import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'command_line_screen.dart';
import 'proxy_settings_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final authService = AuthService(); // Наша пацанская авторизация

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_lock_outlined),
            tooltip: 'Настройки прокси',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProxySettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () => authService.logout(),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatPreview>>(
        stream: chatService.chatsStream(),
        builder: (context, snapshot) {
          final chats = snapshot.data ?? [];

          return ListView.builder(
            // +2 — под два спецпункта: 1. Командная строка, 2. Избранное
            itemCount: chats.length + 2,
            itemBuilder: (context, index) {
              // 1. Первый элемент всегда Командная строка
              if (index == 0) {
                return _CommandLineTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CommandLineScreen()),
                  ),
                );
              }

              // 2. Второй элемент — наше заветное Избранное!
              if (index == 1) {
                return _SavedMessagesTile(
                  onTap: () {
                    // Выдергиваем текущего залогиненного юзера (тебя!)
                    final currentUser = authService.currentUser; 
                    if (currentUser != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: currentUser.uid, // Твой личный ID чата с самим собой!
                            otherUsername: 'Избранное 🔒',
                          ),
                        ),
                      );
                    }
                  },
                );
              }

              // Сдвигаем индекс чатов на -2 из-за двух верхних спецпанелей
              final chat = chats[index - 2];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(chat.otherUsername.isNotEmpty
                      ? chat.otherUsername[0].toUpperCase()
                      : '?'),
                ),
                title: Text(chat.otherUsername),
                subtitle: Text(
                  chat.lastMessage.isEmpty ? 'Нет сообщений' : chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: chat.unreadCount > 0
                    ? CircleAvatar(
                        radius: 10,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          '${chat.unreadCount}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                      )
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: chat.id,
                      otherUsername: chat.otherUsername,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add_comment_outlined),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewChatScreen()),
        ),
      ),
    );
  }
}

/// Спецпункт в списке чатов — открывает встроенную консоль/дебаг-панель
class _CommandLineTile extends StatelessWidget {
  final VoidCallback onTap;
  const _CommandLineTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.black87,
        child: Icon(Icons.terminal, color: Colors.greenAccent),
      ),
      title: const Text('Командная строка',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Системная консоль и логи'),
      onTap: onTap,
    );
  }
}

/// НОВЫЙ ХИТБОКС ПРАЙМ-ТАЙМА: Спецпункт "Избранное"
class _SavedMessagesTile extends StatelessWidget {
  final VoidCallback onTap;
  const _SavedMessagesTile({required this.required, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.blueGrey, // Строгий хакерский цвет
        child: Icon(Icons.bookmark, color: Colors.cyanAccent), // Неоновая закладка Сириуса!
      ),
      title: const Text('Избранное',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('🐾 Мысли Пиписа, коды и заметки'),
      onTap: onTap,
    );
  }
}
