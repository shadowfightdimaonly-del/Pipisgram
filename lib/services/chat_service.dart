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
        .snapshots()
        .asyncMap((snap) async {
      final userUids = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final isSelfChat = data['isSelfChat'] == true;
        final isGroup = data['isGroup'] == true;

        if (!isGroup && !isSelfChat) {
          final otherUid = participants.firstWhere(
            (id) => id != _myUid,
            orElse: () => '',
          );
          if (otherUid.isNotEmpty) {
            userUids.add(otherUid);
          }
        }
      }

      // Вместо отдельного users/{uid}.get() для каждого чата читаем
      // профили пакетами. Firestore ограничивает whereIn размером списка,
      // поэтому режем на безопасные группы.
      final userDataByUid = <String, Map<String, dynamic>>{};

      final uidList = userUids.toList();
      for (var start = 0; start < uidList.length; start += 30) {
        final end = (start + 30 < uidList.length)
            ? start + 30
            : uidList.length;
        final chunk = uidList.sublist(start, end);

        if (chunk.isEmpty) continue;

        final userSnap = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final userDoc in userSnap.docs) {
          userDataByUid[userDoc.id] = userDoc.data();
        }
      }

      final unreadByChatId = <String, int>{};
      final unreadSnap = await _db
          .collection('chatUnread')
          .where('userId', isEqualTo: _myUid)
          .get();

      // Recovery мог оставить устаревшие записи. Проверяем связанное
      // сообщение, чтобы фантомный unread не жил вечно.
      for (final unreadDoc in unreadSnap.docs) {
        final unreadData = unreadDoc.data();
        final chatId = unreadData['chatId'];
        final messageId = unreadData['messageId'];

        if (chatId is! String ||
            chatId.isEmpty ||
            messageId is! String ||
            messageId.isEmpty) {
          continue;
        }

        try {
          final messageDoc = await _db
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(messageId)
              .get();

          final messageData = messageDoc.data();
          if (!messageDoc.exists ||
              messageData == null ||
              messageData['read'] == true ||
              messageData['senderId'] == _myUid) {
            continue;
          }

          unreadByChatId[chatId] = (unreadByChatId[chatId] ?? 0) + 1;
        } catch (_) {
          // Устаревшая запись может ссылаться на удалённый чат.
          // Она не должна ломать весь список чатов.
          continue;
        }
      }

      final chats = <ChatPreview>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final participants =
            List<String>.from(data['participants'] ?? []);
        final isSelfChat = data['isSelfChat'] == true;
        final isGroup = data['isGroup'] == true;
        final lastMessage = data['lastMessage'] ?? '';
        final lastMessageTime =
            (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final unreadCount = unreadByChatId[doc.id] ?? 0;

        if (isGroup) {
          chats.add(
            ChatPreview(
              id: doc.id,
              participants: participants,
              lastMessage: lastMessage,
              lastMessageTime: lastMessageTime,
              otherUsername: data['groupName'] ?? 'Группа',
              otherUid: '',
              otherProfileColor:
                  (data['groupColor'] ?? 0xFF546E7A) as int,
              unreadCount: unreadCount,
              isGroup: true,
              chatListColor:
                  (data['chatListColor'] ?? 0xFF546E7A) as int,
              chatListDecoration:
                  data['chatListDecoration'] ?? 'none',
            ),
          );
          continue;
        }

        final otherUid = isSelfChat
            ? _myUid
            : participants.firstWhere(
                (id) => id != _myUid,
                orElse: () => _myUid,
              );
        final otherUserData =
            isSelfChat ? <String, dynamic>{} : (userDataByUid[otherUid] ?? {});

        chats.add(
          ChatPreview(
            id: doc.id,
            participants: participants,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            otherUsername: isSelfChat
                ? 'Избранное'
                : (otherUserData['username'] ?? 'Неизвестный'),
            otherAvatarUrl: otherUserData['avatarUrl'],
            otherUid: otherUid,
            otherProfileColor:
                (otherUserData['profileColor'] ?? 0xFF2AABEE) as int,
            unreadCount: unreadCount,
            chatListColor:
                (data['chatListColor'] ??
                        otherUserData['profileColor'] ??
                        0xFF2AABEE)
                    as int,
            chatListDecoration:
                data['chatListDecoration'] ?? 'none',
          ),
        );
      }

      chats.sort((a, b) {
        final aUnread = a.unreadCount > 0;
        final bUnread = b.unreadCount > 0;
        if (aUnread != bUnread) return aUnread ? -1 : 1;
        if (aUnread && bUnread && a.unreadCount != b.unreadCount) {
          return b.unreadCount.compareTo(a.unreadCount);
        }
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });

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

  /// Отмечает переданные непрочитанные сообщения как прочитанные.
  /// Вызывается только когда в актуальном snapshot действительно есть
  /// непрочитанные сообщения от собеседника.
  Future<void> markMessagesAsRead(
    String chatId,
    Iterable<String> messageIds,
  ) async {
    final ids = messageIds.toSet();
    if (ids.isEmpty) return;

    final messagesRef =
        _db.collection('chats').doc(chatId).collection('messages');
    final unreadRef = _db.collection('chatUnread');
    final chatRef = _db.collection('chats').doc(chatId);
    final idList = ids.toList();

    // Одновременно отмечаем сообщения прочитанными и удаляем
    // личные записи непрочитанного состояния текущего пользователя.
    for (var start = 0; start < idList.length; start += 10) {
      final end = (start + 10 < idList.length) ? start + 10 : idList.length;
      final batch = _db.batch();

      for (final messageId in idList.sublist(start, end)) {
        batch.update(messagesRef.doc(messageId), {'read': true});
        batch.delete(unreadRef.doc(chatId + '_' + messageId + '_' + _myUid));
      }
      batch.update(chatRef, {
        'unreadVersion': FieldValue.increment(1),
      });

      await batch.commit();
    }
  }

  /// Создаёт отдельные записи непрочитанного состояния для получателей.
  /// Получатель владеет своей записью и удаляет её при прочтении.
  Future<void> _createUnreadRecords(String chatId, String messageId) async {
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    if (chatData == null) return;

    final participants = List<String>.from(chatData['participants'] ?? []);
    final recipients = participants.where((uid) => uid != _myUid).toList();
    if (recipients.isEmpty) return;

    final unreadRef = _db.collection('chatUnread');

    for (var start = 0; start < recipients.length; start += 10) {
      final end = (start + 10 < recipients.length)
          ? start + 10
          : recipients.length;
      final batch = _db.batch();

      for (final uid in recipients.sublist(start, end)) {
        batch.set(
          unreadRef.doc(chatId + '_' + messageId + '_' + uid),
          {
            'chatId': chatId,
            'messageId': messageId,
            'userId': uid,
            'senderId': _myUid,
          },
        );
      }

      await batch.commit();
    }
  }
  Future<void> sendImageMessage(String chatId, String imageUrl) async {
    final msgRef = _db.collection('chats').doc(chatId).collection('messages');
    final now = DateTime.now();

    final myUserDoc = await _db.collection('users').doc(_myUid).get();
    final myUsername = myUserDoc.data()?['username'] ?? 'Неизвестный';

    final messageRef = msgRef.doc();
    await messageRef.set({
      'chatId': chatId,
      'senderId': _myUid,
      'senderUsername': myUsername,
      'text': '',
      'type': 'image',
      'mediaUrl': imageUrl,
      'timestamp': now.millisecondsSinceEpoch,
      'read': false,
    });

    await _createUnreadRecords(chatId, messageRef.id);

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': '📷 Фото',
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
          body: '@$myUsername отправил фото',
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
            body: '📷 Фото',
          );
        }
      }
    }
  }

  Future<void> sendVideoMessage(
  String chatId,
  String videoUrl,
  String fileName,
) async {
    final msgRef = _db.collection('chats').doc(chatId).collection('messages');
    final now = DateTime.now();

    final myUserDoc = await _db.collection('users').doc(_myUid).get();
    final myUsername = myUserDoc.data()?['username'] ?? 'Неизвестный';

    final messageRef = msgRef.doc();
    await messageRef.set({
      'chatId': chatId,
      'senderId': _myUid,
      'senderUsername': myUsername,
      'text': fileName,
      'type': 'video',
      'mediaUrl': videoUrl,
      'timestamp': now.millisecondsSinceEpoch,
      'read': false,
    });

    await _createUnreadRecords(chatId, messageRef.id);

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': '🎥 Видео',
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
          body: '@$myUsername отправил видео',
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
            body: '🎥 Видео',
          );
        }
      }
    }
  }

  Future<void> sendAudioMessage(String chatId, String audioUrl) async {
    final msgRef = _db.collection('chats').doc(chatId).collection('messages');
    final now = DateTime.now();
    final myUserDoc = await _db.collection('users').doc(_myUid).get();
    final myUsername = myUserDoc.data()?['username'] ?? 'Неизвестный';

    final messageRef = msgRef.doc();
    await messageRef.set({
      'chatId': chatId,
      'senderId': _myUid,
      'senderUsername': myUsername,
      'text': '',
      'type': 'audio',
      'mediaUrl': audioUrl,
      'timestamp': now.millisecondsSinceEpoch,
      'read': false,
    });

    await _createUnreadRecords(chatId, messageRef.id);

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': '🎵 Аудио',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await _sendMediaNotification(chatId, myUsername, '🎵 Аудио', 'аудио');
  }

  Future<void> sendFileMessage(
      String chatId, String fileUrl, String fileName) async {
    final msgRef = _db.collection('chats').doc(chatId).collection('messages');
    final now = DateTime.now();
    final myUserDoc = await _db.collection('users').doc(_myUid).get();
    final myUsername = myUserDoc.data()?['username'] ?? 'Неизвестный';

    final messageRef = msgRef.doc();
    await messageRef.set({
      'chatId': chatId,
      'senderId': _myUid,
      'senderUsername': myUsername,
      'text': fileName,
      'type': 'file',
      'mediaUrl': fileUrl,
      'timestamp': now.millisecondsSinceEpoch,
      'read': false,
    });

    await _createUnreadRecords(chatId, messageRef.id);

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': '📎 $fileName',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await _sendMediaNotification(chatId, myUsername, '📎 $fileName', 'файл');
  }

  Future<void> _sendMediaNotification(
      String chatId, String myUsername, String body, String mediaName) async {
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    if (chatData == null) return;

    final isGroup = chatData['isGroup'] == true;
    final participants = List<String>.from(chatData['participants']);
    if (isGroup) {
      final groupName = chatData['groupName'] ?? 'Группа';
      PushNotificationService.sendToGroup(
        participantUids: participants,
        excludeUid: _myUid,
        title: groupName,
        body: '@$myUsername отправил $mediaName',
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
          body: body,
        );
      }
    }
  }

  Future<void> sendEmojiMessage(String chatId, String emojiUrl) async {
    final msgRef = _db.collection('chats').doc(chatId).collection('messages');
    final now = DateTime.now();

    final myUserDoc = await _db.collection('users').doc(_myUid).get();
    final myUsername = myUserDoc.data()?['username'] ?? 'Неизвестный';

    final messageRef = msgRef.doc();
    await messageRef.set({
      'chatId': chatId,
      'senderId': _myUid,
      'senderUsername': myUsername,
      'text': '',
      'type': 'emoji',
      'mediaUrl': emojiUrl,
      'timestamp': now.millisecondsSinceEpoch,
      'read': false,
    });

    await _createUnreadRecords(chatId, messageRef.id);

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': '😀 Эмодзи',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendMessage(String chatId, String text) async {

  
    final msgRef = _db.collection('chats').doc(chatId).collection('messages');
    final now = DateTime.now();

    final myUserDoc = await _db.collection('users').doc(_myUid).get();
    final myUsername = myUserDoc.data()?['username'] ?? 'Неизвестный';

    final messageRef = msgRef.doc();
    await messageRef.set({
      'chatId': chatId,
      'senderId': _myUid,
      'senderUsername': myUsername,
      'text': text,
      'type': 'text',
      'timestamp': now.millisecondsSinceEpoch,
      'read': false,
    });

    await _createUnreadRecords(chatId, messageRef.id);

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

  Future<void> changeOtherAvatar(String targetUid, String avatarUrl) async {
    if (targetUid == _myUid) {
      throw Exception('Для своей аватарки используй обычные настройки профиля');
    }

    final allowed = await hasChangeAvatarsGift();
    if (!allowed) {
      throw Exception('Для этого нужен подарок №2');
    }

    if (avatarUrl.trim().isEmpty) {
      throw Exception('Некорректная ссылка на аватарку');
    }

    await _db.collection('users').doc(targetUid).update({
      'avatarUrl': avatarUrl.trim(),
    });
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    final allowed = await hasEditMessagesGift();
    if (!allowed) {
      throw Exception('Для этого нужен подарок №1');
    }

    final text = newText.trim();
    if (text.isEmpty) {
      throw Exception('Сообщение не может быть пустым');
    }

    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
          'text': text,
          'edited': true,
        });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data();
    if (chatData == null) return;

    final participants = List<String>.from(chatData['participants'] ?? []);
    final batch = _db.batch();

    batch.delete(chatRef.collection('messages').doc(messageId));

    final unreadRef = _db.collection('chatUnread');
    for (final uid in participants) {
      if (uid == _myUid) continue;
      batch.delete(unreadRef.doc(chatId + '_' + messageId + '_' + uid));
    }

    await batch.commit();
  }

  Future<void> removeParticipant(String chatId, String targetUid) async {
    await _db.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayRemove([targetUid]),
    });
  }
}
