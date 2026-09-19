import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUsername;
  final String? otherUid;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUsername,
    this.otherUid,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _textCtrl = TextEditingController();
  final _myUid = FirebaseAuth.instance.currentUser!.uid;

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _chatService.sendMessage(widget.chatId, text);
    _textCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUsername),
        subtitle: widget.otherUid == null
            ? null
            : _OnlineStatusText(myUid: _myUid, otherUid: widget.otherUid!),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.messagesStream(widget.chatId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('Сообщений пока нет'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == _myUid;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: isMine
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('HH:mm').format(msg.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: (isMine
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: InputDecoration(
                        hintText: 'Сообщение...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Показывает "в сети" под именем собеседника — но только если
/// сам текущий пользователь не скрыл свой статус (правило "видишь,
/// только если сам показываешь").
class _OnlineStatusText extends StatelessWidget {
  final String myUid;
  final String otherUid;

  const _OnlineStatusText({required this.myUid, required this.otherUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
      builder: (context, mySnap) {
        final myData = mySnap.data?.data() as Map<String, dynamic>?;
        final myShowStatus = myData?['showOnlineStatus'] ?? true;

        if (!myShowStatus) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(otherUid)
              .snapshots(),
          builder: (context, otherSnap) {
            final otherData = otherSnap.data?.data() as Map<String, dynamic>?;
            final isOnline = otherData?['online'] == true;

            return Text(
              isOnline ? 'в сети' : 'не в сети',
              style: TextStyle(
                fontSize: 12,
                color: isOnline ? Colors.greenAccent : Colors.grey,
              ),
            );
          },
        );
      },
    );
  }
}