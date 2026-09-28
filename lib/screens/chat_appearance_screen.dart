import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_upload_service.dart';

class ChatAppearanceScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatAppearanceScreen({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  State<ChatAppearanceScreen> createState() => _ChatAppearanceScreenState();
}

class _ChatAppearanceScreenState extends State<ChatAppearanceScreen> {
  final _db = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;
  bool _uploadingBackground = false;
  String? _backgroundUrl;
  int _backgroundColorValue = 0xFF121212;
  int _listColorValue = 0xFF2AABEE;
  String _listDecoration = 'none';

  static const _decorationOptions = <Map<String, dynamic>>[
    {'id': 'none', 'label': 'Нет', 'icon': null},
    {'id': 'water', 'label': 'Вода', 'icon': Icons.water_drop_outlined},
    {'id': 'blood', 'label': 'Пятно', 'icon': Icons.opacity},
    {'id': 'star', 'label': 'Звезда', 'icon': Icons.star},
    {'id': 'fire', 'label': 'Огонь', 'icon': Icons.local_fire_department},
    {'id': 'bolt', 'label': 'Молния', 'icon': Icons.bolt},
  ];

  static const _colorOptions = <Color>[
    Color(0xFF2AABEE),
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFF546E7A),
    Color(0xFF121212),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _db.collection('chats').doc(widget.chatId).get();
    final data = doc.data() ?? {};

    if (!mounted) return;
    setState(() {
      _backgroundUrl = data['chatBackgroundUrl'];
      _backgroundColorValue =
          (data['chatBackgroundColor'] ?? 0xFF121212) as int;
      _listColorValue = (data['chatListColor'] ?? 0xFF2AABEE) as int;
      _listDecoration = data['chatListDecoration'] ?? 'none';
      _loading = false;
    });
  }

  Future<void> _save(String field, dynamic value) async {
    await _db.collection('chats').doc(widget.chatId).update({field: value});
  }

  Future<void> _pickBackground() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingBackground = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final url = await ImageUploadService.uploadImage(bytes);
      if (url == null) {
        throw Exception('upload failed');
      }

      await _save('chatBackgroundUrl', url);
      if (!mounted) return;
      setState(() => _backgroundUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фон')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingBackground = false);
    }
  }

  Future<void> _removeBackground() async {
    await _save('chatBackgroundUrl', FieldValue.delete());
    if (mounted) setState(() => _backgroundUrl = null);
  }

  Future<void> _setBackgroundColor(Color color) async {
    setState(() => _backgroundColorValue = color.value);
    await _save('chatBackgroundColor', color.value);
  }

  Future<void> _setListColor(Color color) async {
    setState(() => _listColorValue = color.value);
    await _save('chatListColor', color.value);
  }

  Future<void> _setDecoration(String id) async {
    setState(() => _listDecoration = id);
    await _save('chatListDecoration', id);
  }

  IconData? _decorationIcon(String id) {
    for (final option in _decorationOptions) {
      if (option['id'] == id) return option['icon'] as IconData?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final backgroundColor = Color(_backgroundColorValue);
    final listColor = Color(_listColorValue);
    final decorationIcon = _decorationIcon(_listDecoration);

    return Scaffold(
      appBar: AppBar(title: const Text('Оформление чата')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.chatName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
              image: _backgroundUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(_backgroundUrl!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.2),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Пример сообщения',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _uploadingBackground ? null : _pickBackground,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _uploadingBackground ? 'Загрузка...' : 'Изменить фон',
                  ),
                ),
              ),
              if (_backgroundUrl != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Убрать фон',
                  onPressed: _removeBackground,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Цвет используется, когда фон не установлен.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colorOptions.map((color) {
              final selected = color.value == _backgroundColorValue;
              return GestureDetector(
                onTap: () => _setBackgroundColor(color),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: color,
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const Divider(height: 36),
          const Text(
            'Оформление чата в списке',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: listColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: listColor.withOpacity(0.35)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: listColor,
                child: const Icon(Icons.chat_bubble, color: Colors.white),
              ),
              title: Text(widget.chatName),
              subtitle: const Text('Последнее сообщение'),
              trailing: decorationIcon == null
                  ? null
                  : Icon(decorationIcon, color: listColor),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Цвет карточки',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colorOptions.map((color) {
              final selected = color.value == _listColorValue;
              return GestureDetector(
                onTap: () => _setListColor(color),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: color,
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Украшение',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _decorationOptions.map((option) {
              final id = option['id'] as String;
              final selected = id == _listDecoration;
              final icon = option['icon'] as IconData?;
              return ChoiceChip(
                selected: selected,
                avatar: icon == null ? null : Icon(icon, size: 18),
                label: Text(option['label'] as String),
                onSelected: (_) => _setDecoration(id),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Настройки сохраняются отдельно для этого чата.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
