import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'command_line_screen.dart';
import 'profile_settings_screen.dart';
import 'chat_appearance_screen.dart';
import 'new_chat_screen.dart';
import 'new_group_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipisgram'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Настройки профиля',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatPreview>>(
        stream: chatService.chatsStream(),
        builder: (context, snapshot) {
          final chats = snapshot.data ?? [];

          return ListView.builder(
            // +2 — под "Командную строку" и "Избранное", они всегда первые
            itemCount: chats.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CommandLineTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CommandLineScreen()),
                  ),
                );
              }

              if (index == 1) {
                return _SavedMessagesTile(
                  onTap: () async {
                    final chatId = await chatService.getOrCreateChat(myUid);
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatId: chatId,
                          otherUsername: 'Избранное',
                        ),
                      ),
                    );
                  },
                );
              }

              final chat = chats[index - 2];
              final listColor = Color(chat.chatListColor);
              final decorationIcon = switch (chat.chatListDecoration) {
                'water' => Icons.water_drop_outlined,
                'blood' => Icons.opacity,
                'star' => Icons.star,
                'fire' => Icons.local_fire_department,
                'bolt' => Icons.bolt,
                _ => null,
              };

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: listColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: listColor.withOpacity(0.18)),
                ),
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: chat.isGroup
                            ? listColor
                            : Color(chat.otherProfileColor),
                        backgroundImage:
                            (!chat.isGroup && chat.otherAvatarUrl != null)
                                ? CachedNetworkImageProvider(chat.otherAvatarUrl!)
                                : null,
                        child: (!chat.isGroup && chat.otherAvatarUrl != null)
                            ? null
                            : (chat.isGroup
                                ? const Icon(Icons.groups, color: Colors.white)
                                : Text(
                                    chat.otherUsername.isNotEmpty
                                        ? chat.otherUsername[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )),
                      ),
                      if (decorationIcon != null)
                        Positioned(
                          right: -5,
                          top: -7,
                          child: Icon(
                            decorationIcon,
                            size: 18,
                            color: listColor,
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    chat.otherUsername,
                    style: TextStyle(
                      fontWeight:
                          chat.unreadCount > 0 ? FontWeight.w700 : null,
                    ),
                  ),
                  subtitle: Text(
                    chat.lastMessage.isEmpty
                        ? 'Нет сообщений'
                        : chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: chat.unreadCount > 0
                      ? CircleAvatar(
                          radius: 10,
                          backgroundColor: listColor,
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
                      builder: (context) => ChatScreen(
                        chatId: chat.id,
                        otherUsername: chat.otherUsername,
                        otherUid: chat.isGroup ? null : chat.otherUid,
                      ),
                    ),
                  ),
                  onLongPress: () async {
                    final action = await showModalBottomSheet<String>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.palette_outlined),
                              title: const Text('Оформление чата'),
                              onTap: () =>
                                  Navigator.pop(context, 'appearance'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              title: Text(
                                chat.isGroup ? 'Удалить группу' : 'Удалить чат',
                                style: const TextStyle(color: Colors.red),
                              ),
                              onTap: () =>
                                  Navigator.pop(context, 'delete'),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (!context.mounted) return;

                    if (action == 'appearance') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatAppearanceScreen(
                            chatId: chat.id,
                            chatName: chat.otherUsername,
                          ),
                        ),
                      );
                    } else if (action == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(chat.isGroup
                              ? 'Удалить группу?'
                              : 'Удалить чат?'),
                          content: Text(
                            'Все сообщения в "${chat.otherUsername}" будут удалены безвозвратно.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Удалить',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await chatService.deleteChat(chat.id);
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'newGroup',
            mini: true,
            child: const Icon(Icons.group_add_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewGroupScreen()),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'newChat',
            child: const Icon(Icons.add_comment_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewChatScreen()),
            ),
          ),
        ],
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
      leading: CircleAvatar(
        backgroundColor: Colors.black87,
        child: const Icon(Icons.terminal, color: Colors.greenAccent),
      ),
      title: const Text('Командная строка',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Системная консоль и логи'),
      onTap: onTap,
    );
  }
}

/// Спецпункт "Избранное" — чат с самим собой для заметок/сохранённых сообщений
class _SavedMessagesTile extends StatelessWidget {
  final VoidCallback onTap;
  const _SavedMessagesTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.bookmark, color: Colors.white),
      ),
      title: const Text('Избранное',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Заметки и сохранённые сообщения'),
      onTap: onTap,
    );
  }
}