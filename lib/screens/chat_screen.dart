import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import '../services/chat_service.dart';
import '../services/image_upload_service.dart';
import '../services/file_upload_service.dart';
import '../models/message.dart';
import 'group_info_screen.dart';
import 'view_profile_screen.dart';
import 'profile_settings_screen.dart';

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
  bool _isGroup = false;
  bool _canEditOthersMessages = false;
  double _myBubbleRadius = 16.0;
  String? _myBubbleTexture;
  double _otherBubbleRadius = 16.0;
  String? _otherBubbleTexture;
  bool _isOffline = false;
  bool _uploadingMedia = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _checkIfGroup();
    _checkEditRights();
    _loadBubbleStyles();
    _chatService.markMessagesAsRead(widget.chatId);
    _watchConnectivity();
  }

  void _watchConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted) setState(() => _isOffline = offline);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkIfGroup() async {
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();
    if (mounted) setState(() => _isGroup = doc.data()?['isGroup'] == true);
  }

  Future<void> _checkEditRights() async {
    final hasGift = await _chatService.hasEditMessagesGift();
    if (mounted) setState(() => _canEditOthersMessages = hasGift);
  }

  Future<void> _loadBubbleStyles() async {
    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_myUid)
        .get();
    final myData = myDoc.data();
    final myStyleId = myData?['bubbleStyle'] ?? 'rounded';
    final myStyle = bubbleStyles.firstWhere(
      (s) => s['id'] == myStyleId,
      orElse: () => bubbleStyles.first,
    );

    double otherRadius = 16.0;
    String? otherTexture;
    if (widget.otherUid != null) {
      final otherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUid)
          .get();
      final otherData = otherDoc.data();
      final otherStyleId = otherData?['bubbleStyle'] ?? 'rounded';
      final otherStyle = bubbleStyles.firstWhere(
        (s) => s['id'] == otherStyleId,
        orElse: () => bubbleStyles.first,
      );
      otherRadius = otherStyle['radius'] as double;
      otherTexture = otherData?['bubbleTextureUrl'];
    }

    if (mounted) {
      setState(() {
        _myBubbleRadius = myStyle['radius'] as double;
        _myBubbleTexture = myData?['bubbleTextureUrl'];
        _otherBubbleRadius = otherRadius;
        _otherBubbleTexture = otherTexture;
      });
    }
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _chatService.sendMessage(widget.chatId, text);
    _textCtrl.clear();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingMedia = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final url = await ImageUploadService.uploadImage(bytes);
      if (url != null) {
        await _chatService.sendImageMessage(widget.chatId, url);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фото')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _sendVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploadingMedia = true);
    try {
      final url = await FileUploadService.uploadFile(picked.path, picked.name);
      if (url != null) {
        await _chatService.sendVideoMessage(widget.chatId, url);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить видео')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _sendAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;
    setState(() => _uploadingMedia = true);
    try {
      final url = await FileUploadService.uploadFile(path, name);
      if (url != null) {
        await _chatService.sendAudioMessage(widget.chatId, url);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить аудио')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;

    setState(() => _uploadingMedia = true);

    try {
      final url = await FileUploadService.uploadFile(path, name);
      if (url != null) {
        await _chatService.sendFileMessage(widget.chatId, url, name);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить файл')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_myUid)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() as Map<String, dynamic>?;
            final emojis = List<String>.from(data?['customEmojis'] ?? []);

            if (emojis.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'У тебя пока нет своих эмодзи — загрузи их в настройках профиля',
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  final url = emojis[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _chatService.sendEmojiMessage(widget.chatId, url);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  bool _openingMedia = false;

  Future<void> _openMedia(String url, String fileName) async {
  if (_openingMedia) return;
  setState(() => _openingMedia = true);

  try {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(filePath);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось скачать файл')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть файл')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingMedia = false);
    }
  }
  void _showAttachMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Фото'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Видео'),
              onTap: () {
                Navigator.pop(context);
                _sendVideo();
              },
            ),
           ListTile(
              leading: const Icon(Icons.audiotrack_outlined),
              title: const Text('Аудио'),
              onTap: () {
                Navigator.pop(context);
                _sendAudio();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Файл'),
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('Мой эмодзи'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageActions(Message msg) {
    final isMine = msg.senderId == _myUid;
    final canEdit = isMine || (_isGroup && _canEditOthersMessages);
    if (!canEdit) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(context);
                _editMessageDialog(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _chatService.deleteMessage(widget.chatId, msg.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editMessageDialog(Message msg) {
    final ctrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать сообщение'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final newText = ctrl.text.trim();
              if (newText.isNotEmpty) {
                await _chatService.editMessage(widget.chatId, msg.id, newText);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Message msg, bool isMine) {
    final textColor = isMine
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    if (msg.type == MessageType.image && msg.mediaUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          msg.mediaUrl!,
          width: 220,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 220,
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            width: 220,
            height: 100,
            child: Center(child: Text('Не удалось загрузить фото')),
          ),
        ),
      );
    }

    else if (msg.type == MessageType.video &&
                                  msg.mediaUrl != null)
                                GestureDetector(
onTap: () => _openMedia(
  msg.mediaUrl!,
  msg.text.isNotEmpty ? msg.text : 'file',
),                                  
                                  child: Container(
                                    width: 220,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: _openingMedia
                                          ? const CircularProgressIndicator(
                                              color: Colors.white)
                                          : const Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.play_circle_fill,
                                                    color: Colors.white,
                                                    size: 48),
                                                SizedBox(height: 6),
                                                Text('Открыть видео',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                    ),
                                  ),
                                )
   else if (msg.type == MessageType.file &&
                                  msg.mediaUrl != null)
                                GestureDetector(
onTap: () => _openMedia(
  msg.mediaUrl!,
  msg.text.isNotEmpty ? msg.text : 'file',
),                                  
                                  child: Container(
                                    width: 200,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        if (_openingMedia)
                                          SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: isMine
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          )
                                        else
                                        Icon(Icons.insert_drive_file,
                color: textColor,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg.text.isNotEmpty ? msg.text : 'Файл',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Text(
      msg.text,
      style: TextStyle(color: textColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isOffline
            ? const Text(
                'Ожидание сети...',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            : GestureDetector(
                onTap: () {
                  if (_isGroup) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupInfoScreen(
                          chatId: widget.chatId,
                          groupName: widget.otherUsername,
                        ),
                      ),
                    );
                  } else if (widget.otherUid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ViewProfileScreen(uid: widget.otherUid!),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    if (!_isGroup && widget.otherUid != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.otherUid)
                              .snapshots(),
                          builder: (context, snap) {
                            final data =
                                snap.data?.data() as Map<String, dynamic>?;
                            final avatarUrl = data?['avatarUrl'];
                            return CircleAvatar(
                              radius: 18,
                              backgroundImage: avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null
                                  ? Text(widget.otherUsername.isNotEmpty
                                      ? widget.otherUsername[0].toUpperCase()
                                      : '?')
                                  : null,
                            );
                          },
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.otherUsername),
                          if (widget.otherUid != null)
                            _OnlineStatusText(
                              myUid: _myUid,
                              otherUid: widget.otherUid!,
                            ),
                          if (_isGroup)
                            const Text(
                              'нажми для управления группой',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
final bubbleColor = isMine
    ? Theme.of(context).colorScheme.primary
    : Theme.of(context).colorScheme.surfaceVariant;

final bubbleTexture =
    isMine ? _myBubbleTexture : _otherBubbleTexture;

final textColor = isMine
    ? Theme.of(context).colorScheme.onPrimary
    : Theme.of(context).colorScheme.onSurfaceVariant;
                    if (msg.type == MessageType.emoji &&
                        msg.mediaUrl != null) {
                      return GestureDetector(
                        onLongPress: () => _showMessageActions(msg),
                        child: Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: SizedBox(
                              width: 90,
                              height: 90,
                              child: Image.network(msg.mediaUrl!,
                                  fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      );
                    }

                    return GestureDetector(
                      onLongPress: () => _showMessageActions(msg),
                      child: Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(
                              isMine ? _myBubbleRadius : _otherBubbleRadius,
                            ),
                            image: bubbleTexture != null
                                ? DecorationImage(
                                    image: NetworkImage(bubbleTexture),
                                    fit: BoxFit.cover,
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withOpacity(0.15),
                                      BlendMode.darken,
                                    ),
                                  )
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isGroup && !isMine)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '@${msg.senderUsername ?? "неизвестный"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ),
                              _buildMessageContent(msg, isMine),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (msg.edited)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 4),
                                      child: Text(
                                        'изменено',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: textColor.withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    DateFormat('HH:mm').format(msg.timestamp),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                  if (isMine) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      msg.read
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 14,
                                      color: msg.read
                                          ? Colors.lightBlueAccent
                                          : textColor.withOpacity(0.7),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
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
                  IconButton(
                    icon: _uploadingMedia
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file),
                    onPressed: _uploadingMedia
                        ? null
                        : () => _showAttachMenu(context),
                  ),
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

class _OnlineStatusText extends StatelessWidget {
  final String myUid;
  final String otherUid;

  const _OnlineStatusText({
    required this.myUid,
    required this.otherUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .snapshots(),
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
            final otherData =
                otherSnap.data?.data() as Map<String, dynamic>?;
            final lastActive = otherData?['lastActive'];
            bool isOnline = false;
            if (lastActive is Timestamp) {
              final secondsAgo =
                  DateTime.now().difference(lastActive.toDate()).inSeconds;
              isOnline = secondsAgo < 90;
            }
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