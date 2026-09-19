import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/chat.dart';
import '../models/app_user.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  /// Список чатов текущего пользователя, отсортирован по последнему сообщению
  Stream<List<ChatPreview>> chatsStream() {
    return _db
        .collection('chats')
        .where('participants', arrayContains: _myUid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      List<ChatPreview> chats = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants']);
        final isSelfChat = data['isSelfChat'] == true;

        final otherUid = isSelfChat
            ? _myUid
            : participants.firstWhere(
                (id) => id != _myUid,
                orElse: () => _myUid,
              );

        final otherUserDoc = await _db.collection('users').doc(otherUid).get();
        final otherUserData = otherUserDoc.data() ?? {};

        chats.add(ChatPreview(
          id: doc.id,
          participants: participants,
          lastMessage: data['lastMessage'] ?? '',
          lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          otherUsername: isSelfChat
              ? 'Избранное'
              : (otherUserData['username'] ?? 'Неизвестный'),
          otherAvatarUrl: otherUserData['avatarUrl'],
          otherUid: otherUid,
          unreadCount: (data['unread_$_myUid'] ?? 0) as int,
        ));
      }
      return chats;
    });
  }

  /// Создать чат с пользователем по его uid (или вернуть существующий).
  /// Если otherUid == свой uid — это "Избранное" (чат с самим собой).
  Future<String> getOrCreateChat(String otherUid) async {
    final isSelfChat = otherUid == _myUid;

    final existing = await _db
        .collection('chats')
        .where('participants', arrayContains: _myUid)
        .get();

    for (var doc in existing.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants']);
      final docIsSelfChat = data['isSelfChat'] == true;

      if (isSelfChat && docIsSelfChat) {
        return doc.id;
      }
      if (!isSelfChat && !docIsSelfChat && participants.contains(otherUid)) {
        return doc.id;
      }
    }

    final newChat = await _db.collection('chats').add({
      'participants': isSelfChat ? [_myUid] : [_myUid, otherUid],
      'isSelfChat': isSelfChat,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
    return newChat.id;
  }

  Future<AppUser?> findUserByUsername(String username) async {
    final cleanUsername = username.trim().replaceFirst('@', '');
    final query = await _db
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return AppUser.fromMap(query.docs.first.id, query.docs.first.data());
  }

  Stream<List<Message>> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Message.fromMap(d.id, d.data())).toList());
  }

  Future<void> sendMessage(String chatId, String text) async {
    final msgRef = _db.collection('chats').doc(chatId).collection('messages');
    final now = DateTime.now();

    await msgRef.add({
      'senderId': _myUid,
      'text': text,
      'type': 'text',
      'timestamp': now.millisecondsSinceEpoch,
      'read': false,
    });

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }
}