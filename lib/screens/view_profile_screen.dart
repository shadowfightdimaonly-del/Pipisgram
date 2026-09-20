import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/image_upload_service.dart';

class ViewProfileScreen extends StatefulWidget {
  final String uid;

  const ViewProfileScreen({super.key, required this.uid});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final _db = FirebaseFirestore.instance;
  final _chatService = ChatService();
  bool _hasChangeAvatarGift = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _checkGift();
  }

  Future<void> _checkGift() async {
    final hasGift = await _chatService.hasChangeAvatarsGift();
    if (mounted) setState(() => _hasChangeAvatarGift = hasGift);
  }

  Future<void> _pickAndSetAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);

    final bytes = await File(picked.path).readAsBytes();
    final url = await ImageUploadService.uploadImage(bytes);

    if (url != null) {
      await _db.collection('users').doc(widget.uid).update({
        'avatarUrl': url,
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить фото')),
      );
    }

    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(widget.uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() as Map<String, dynamic>?;
          final username = data?['username'] ?? 'неизвестный';
          final avatarUrl = data?['avatarUrl'];
          final isPremium = data?['isPremium'] == true;
          final profileColor = Color(data?['profileColor'] ?? 0xFF2AABEE);

          final showGifts = data?['showGifts'] == true;
          final showTakeover = data?['showTakeoverGift'] == true;
          final hasEditGift = data?['hasGiftEditMessages'] == true;
          final hasAvatarGift = data?['hasGiftChangeAvatars'] == true;
          final hasTakeoverGift = data?['hasGiftGroupTakeover'] == true;

          final visibleGifts = <Widget>[];
          if (showGifts && hasEditGift) {
            visibleGifts.add(_giftChip(
                Icons.edit_outlined, 'Редактор сообщений', Colors.blue));
          }
          if (showGifts && hasAvatarGift) {
            visibleGifts.add(_giftChip(
                Icons.image_outlined, 'Меняет чужие аватарки', Colors.green));
          }
          if (showTakeover && hasTakeoverGift) {
            visibleGifts.add(_giftChip(Icons.warning_amber_rounded,
                'Власть над группами', Colors.deepOrange));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: (_hasChangeAvatarGift && !_uploading)
                      ? _pickAndSetAvatar
                      : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: profileColor,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 40, color: Colors.white),
                              )
                            : null,
                      ),
                      if (_uploading)
                        const Positioned.fill(
                          child: CircleAvatar(
                            backgroundColor: Colors.black45,
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      if (_hasChangeAvatarGift && !_uploading)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black87,
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('@$username',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    if (isPremium) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.workspace_premium,
                          color: Colors.amber, size: 20),
                    ],
                  ],
                ),
              ),
              if (visibleGifts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: visibleGifts,
                ),
              ],
              if (_hasChangeAvatarGift)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'У тебя есть подарок "менять чужие аватарки" — нажми на фото, чтобы изменить его.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _giftChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}