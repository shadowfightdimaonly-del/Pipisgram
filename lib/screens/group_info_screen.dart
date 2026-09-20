import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import 'view_profile_screen.dart';
class GroupInfoScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _db = FirebaseFirestore.instance;
  final _chatService = ChatService();
  final _myUid = FirebaseAuth.instance.currentUser!.uid;
  bool _hasTakeoverGift = false;

  @override
  void initState() {
    super.initState();
    _checkGift();
  }

  Future<void> _checkGift() async {
    final hasGift = await _chatService.hasGroupTakeoverGift();
    if (mounted) setState(() => _hasTakeoverGift = hasGift);
  }

  Future<void> _removeParticipant(String uid, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить из группы?'),
        content: Text('@$username будет удалён из "${widget.groupName}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _chatService.removeParticipant(widget.chatId, uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('chats').doc(widget.chatId).snapshots(),
        builder: (context, chatSnap) {
          if (!chatSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chatData = chatSnap.data!.data() as Map<String, dynamic>?;
          final participants =
              List<String>.from(chatData?['participants'] ?? []);
          final createdBy = chatData?['createdBy'];

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Участники (${participants.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ...participants.map((uid) {
                return FutureBuilder<DocumentSnapshot>(
                  future: _db.collection('users').doc(uid).get(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return const SizedBox.shrink();
                    final userData =
                        userSnap.data!.data() as Map<String, dynamic>?;
                    final username = userData?['username'] ?? 'неизвестный';
                    final isOwner = uid == createdBy;
                    final isMe = uid == _myUid;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userData?['avatarUrl'] != null
                            ? NetworkImage(userData!['avatarUrl'])
                            : null,
                        child: userData?['avatarUrl'] == null
                            ? Text(username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?')
                            : null,
                      ),
                      title: Text('@$username${isMe ? ' (ты)' : ''}'),
                      subtitle: isOwner ? const Text('Владелец') : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewProfileScreen(uid: uid),
                        ),
                      ),
                      trailing: (_hasTakeoverGift && !isMe)
                          ? IconButton(
                              icon: const Icon(Icons.person_remove_outlined,
                                  color: Colors.red),
                              onPressed: () =>
                                  _removeParticipant(uid, username),
                            )
                          : null,
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}