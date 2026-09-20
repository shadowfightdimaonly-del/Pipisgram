import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/chat.dart';
import '../models/app_user.dart';
import 'push_notification_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

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
        final isGroup = data['isGroup'] == true;

        if (isGroup) {
          chats.add(ChatPreview(
            id: doc.id,
            participants: participants,
            lastMessage: data['lastMessage'] ?? '',
            lastMessageTime:
                (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
            otherUsername: data['groupName'] ?? 'Группа',
            otherUid: '',
            otherProfileColor: data['groupColor'] ?? 0xFF546E7A,
            unreadCount: (data['unread_$_myUid'] ?? 0) as int,
            isGroup: true,
          ));
          continue;
        }

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
          otherProfileColor: otherUserData['profileColor'] ?? 0xFF2AABEE,
          unreadCount: (data['unread_$_myUid'] ?? 0) as int,
        ));
      }
      return chats;
    });
  }

  Future<String> getOrCreateChat(String otherUid) async {
    final isSelfChat = otherUid == _myUid;

    final existing = await _db
        .collection('chats')
        .where('participants', arrayContains: _myUid)
        .get();

    for (var doc in existing.docs) {
      final data = doc.data();
      if (data['isGroup'] == true) continue;

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
      'isGroup': false,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
    return newChat.id;
  }

  Future<String> createGroup(String groupName, List<String> memberUids) async {
    final participants = {_myUid, ...memberUids}.toList();

    final newChat = await _db.collection('chats').add({
      'participants': participants,
      'isGroup': true,
      'isSelfChat': false,
      'groupName': groupName,
      'groupColor': 0xFF546E7A,
      'createdBy': _myUid,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
    return newChat.id;
  }

  /// Поиск по юзернейму — используется внутренне (команды, whoami)
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

  /// Поиск по 5-значному коду — основной способ добавить друга
  Future<AppUser?> findUserByCode(String code) async {
    final cleanCode = code.trim();
    final query = await _db
        .collection('users')
        .where('userCode', isEqualTo: cleanCode)
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

    final myUserDoc = await _db.collection('users').doc(_myUid).get();
    final myUsername = myUserDoc.data()?['username'] ?? 'Неизвестный';

    await msgRef.add({
      'senderId': _myUid,
      'senderUsername': myUsername,
      'text': text,
      'type': 'text',
      'timestamp': now.millisecondsSinceEpoch,
      'read': false,
    });

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    final chatDoc = await _db.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    if (chatData != null) {
      final isGroup = chatData['isGroup'] == true;
      final participants = List<String>.from(chatData['participants']);

      if (isGroup) {
        final groupName = chatData['groupName'] ?? 'Группа';
        PushNotificationService.sendToGroup(
          participantUids: participants,
          excludeUid: _myUid,
          title: groupName,
          body: '@$myUsername: $text',
        );
      } else {
        final otherUid = participants.firstWhere(
          (id) => id != _myUid,
          orElse: () => '',
        );
        if (otherUid.isNotEmpty) {
          PushNotificationService.sendToUser(
            targetUid: otherUid,
            title: '@$myUsername',
            body: text,
          );
        }
      }
    }
  }

  Future<void> deleteChat(String chatId) async {
    final messagesSnap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    for (var doc in messagesSnap.docs) {
      await doc.reference.delete();
    }

    await _db.collection('chats').doc(chatId).delete();
  }

  Future<bool> hasEditMessagesGift() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    return doc.data()?['hasGiftEditMessages'] == true;
  }

  Future<bool> hasGroupTakeoverGift() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    return doc.data()?['hasGiftGroupTakeover'] == true;
  }

  Future<bool> hasChangeAvatarsGift() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    return doc.data()?['hasGiftChangeAvatars'] == true;
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'edited': true});
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> removeParticipant(String chatId, String targetUid) async {
    await _db.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayRemove([targetUid]),
    });
  }
}