import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';

class CustomEmojiScreen extends StatefulWidget {
  const CustomEmojiScreen({super.key});

  @override
  State<CustomEmojiScreen> createState() => _CustomEmojiScreenState();
}

class _CustomEmojiScreenState extends State<CustomEmojiScreen> {
  final _db = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser!.uid;
  bool _uploading = false;

  static const int _maxEmoji = 12;

  Future<void> _addEmoji() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _uploading = true);

    try {
      final bytes = await File(picked.path).readAsBytes();
      final url = await ImageUploadService.uploadImage(bytes);
      if (url != null) {
        await _db.collection('users').doc(_myUid).update({
          'customEmojis': FieldValue.arrayUnion([url]),
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить эмодзи')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeEmoji(String url) async {
    await _db.collection('users').doc(_myUid).update({
      'customEmojis': FieldValue.arrayRemove([url]),
      // если удаляемый эмодзи был бейджем — снимаем и его
    });
    final doc = await _db.collection('users').doc(_myUid).get();
    if (doc.data()?['badgeEmoji'] == url) {
      await _db.collection('users').doc(_myUid).update({
        'badgeEmoji': FieldValue.delete(),
      });
    }
  }

  Future<void> _setBadge(String url) async {
    await _db.collection('users').doc(_myUid).update({'badgeEmoji': url});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Эмодзи установлен рядом с ником')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои эмодзи')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(_myUid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final emojis = List<String>.from(data?['customEmojis'] ?? []);
          final badge = data?['badgeEmoji'];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${emojis.length} / $_maxEmoji загружено',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                const Text(
                  'Нажми на эмодзи, чтобы поставить его значком рядом со своим ником. Долгое нажатие — удалить.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (context, index) {
                      final url = emojis[index];
                      final isBadge = url == badge;
                      return GestureDetector(
                        onTap: () => _setBadge(url),
                        onLongPress: () => _removeEmoji(url),
                        child: Container(
                          decoration: BoxDecoration(
                            border: isBadge
                                ? Border.all(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 3)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(url, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: (_uploading || emojis.length >= _maxEmoji)
                      ? null
                      : _addEmoji,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                  label: Text(emojis.length >= _maxEmoji
                      ? 'Достигнут лимит'
                      : 'Добавить эмодзи'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}