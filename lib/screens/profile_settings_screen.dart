import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';

const List<Map<String, dynamic>> bubbleStyles = [
  {'id': 'rounded', 'name': 'Круглые', 'radius': 16.0},
  {'id': 'sharp', 'name': 'Острые', 'radius': 4.0},
  {'id': 'pill', 'name': 'Овальные', 'radius': 24.0},
  {'id': 'square', 'name': 'Квадратные', 'radius': 0.0},
];

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _db = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;
  bool _uploadingAvatar = false;
  bool _uploadingBackground = false;
  bool _uploadingBubble = false;
  bool _showOnlineStatus = true;
  bool _showGifts = false;
  bool _showTakeoverGift = false;
  String _username = '';
  String _userCode = '';
  String? _avatarUrl;
  String? _backgroundUrl;
  int _profileColorValue = 0xFF2AABEE;
  String _bubbleStyle = 'rounded';

  bool _hasEditGift = false;
  bool _hasAvatarGift = false;
  bool _hasTakeoverGift = false;

  final List<Color> _colorOptions = const [
    Color(0xFF2AABEE),
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFF546E7A),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    final data = doc.data();
    setState(() {
      _showOnlineStatus = data?['showOnlineStatus'] ?? true;
      _showGifts = data?['showGifts'] ?? false;
      _showTakeoverGift = data?['showTakeoverGift'] ?? false;
      _username = data?['username'] ?? '';
      _userCode = data?['userCode'] ?? '—';
      _avatarUrl = data?['avatarUrl'];
      _backgroundUrl = data?['profileBackgroundUrl'];
      _profileColorValue = data?['profileColor'] ?? 0xFF2AABEE;
      _bubbleStyle = data?['bubbleStyle'] ?? 'rounded';
      _hasEditGift = data?['hasGiftEditMessages'] == true;
      _hasAvatarGift = data?['hasGiftChangeAvatars'] == true;
      _hasTakeoverGift = data?['hasGiftGroupTakeover'] == true;
      _loading = false;
    });
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _showOnlineStatus = value);
    await _db.collection('users').doc(_myUid).update({
      'showOnlineStatus': value,
      if (!value) 'online': false,
    });
  }

  Future<void> _toggleShowGifts(bool value) async {
    setState(() => _showGifts = value);
    await _db.collection('users').doc(_myUid).update({'showGifts': value});
  }

  Future<void> _toggleShowTakeoverGift(bool value) async {
    setState(() => _showTakeoverGift = value);
    await _db.collection('users').doc(_myUid).update({'showTakeoverGift': value});
  }

  Future<void> _setProfileColor(Color color) async {
    setState(() => _profileColorValue = color.value);
    await _db.collection('users').doc(_myUid).update({
      'profileColor': color.value,
    });
  }

  Future<void> _setBubbleStyle(String styleId) async {
    setState(() => _bubbleStyle = styleId);
    await _db.collection('users').doc(_myUid).update({
      'bubbleStyle': styleId,
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);

    final bytes = await File(picked.path).readAsBytes();
    final url = await ImageUploadService.uploadImage(bytes);

    if (url != null) {
      await _db.collection('users').doc(_myUid).update({
        'avatarUrl': url,
      });
      setState(() {
        _avatarUrl = url;
        _uploadingAvatar = false;
      });
    } else {
      setState(() => _uploadingAvatar = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фото')),
        );
      }
    }
  }

  Future<void> _pickAndUploadBackground() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingBackground = true);

    final bytes = await File(picked.path).readAsBytes();
    final url = await ImageUploadService.uploadImage(bytes);

    if (url != null) {
      await _db.collection('users').doc(_myUid).update({
        'profileBackgroundUrl': url,
      });
      setState(() {
        _backgroundUrl = url;
        _uploadingBackground = false;
      });
    } else {
      setState(() => _uploadingBackground = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фон')),
        );
      }
    }
  }

  Future<void> _removeBackground() async {
    await _db.collection('users').doc(_myUid).update({
      'profileBackgroundUrl': FieldValue.delete(),
    });
    setState(() => _backgroundUrl = null);
  }

  @override
  Widget build(BuildContext context) {
    final profileColor = Color(_profileColorValue);
    final hasAnyGift = _hasEditGift || _hasAvatarGift || _hasTakeoverGift;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: profileColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: GestureDetector(
                      onTap: _uploadingBackground ? null : _pickAndUploadBackground,
                      onLongPress: _backgroundUrl != null ? _removeBackground : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: profileColor,
                          image: _backgroundUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_backgroundUrl!),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withOpacity(0.25),
                                    BlendMode.darken,
                                  ),
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 48,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _avatarUrl != null
                                        ? NetworkImage(_avatarUrl!)
                                        : null,
                                    child: _avatarUrl == null
                                        ? Text(
                                            _username.isNotEmpty
                                                ? _username[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: profileColor,
                                            ),
                                          )
                                        : null,
                                  ),
                                  if (_uploadingAvatar)
                                    const Positioned.fill(
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black45,
                                        child: CircularProgressIndicator(
                                            color: Colors.white),
                                      ),
                                    ),
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
                            const SizedBox(height: 12),
                            Text(
                              _username.isEmpty ? '—' : '@$_username',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _showOnlineStatus ? 'в сети' : 'статус скрыт',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                            if (_uploadingBackground)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        'Нажми на фон, чтобы загрузить свой (долгое нажатие — убрать)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        'Цвет профиля',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _colorOptions.map((color) {
                          final isSelected = color.value == _profileColorValue;
                          return GestureDetector(
                            onTap: () => _setProfileColor(color),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.6),
                                          blurRadius: 8,
                                        )
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 20)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'Форма облачка сообщений',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: bubbleStyles.map((style) {
                          final isSelected = style['id'] == _bubbleStyle;
                          return GestureDetector(
                            onTap: () => _setBubbleStyle(style['id']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? profileColor
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                borderRadius: BorderRadius.circular(
                                    style['radius'] as double),
                              ),
                              child: Text(
                                style['name'],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : null,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Твой код для друзей',
                                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(_userCode,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    SwitchListTile(
                      title: const Text('Показывать статус "в сети"'),
                      subtitle: const Text(
                          'Если выключено — ты не увидишь и чужой онлайн-статус тоже'),
                      value: _showOnlineStatus,
                      onChanged: _toggleOnlineStatus,
                    ),
                    if (hasAnyGift) ...[
                      const Divider(height: 32),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'Мои подарки',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey),
                        ),
                      ),
                      if (_hasEditGift)
                        const ListTile(
                          leading: Icon(Icons.edit_outlined, color: Colors.blue),
                          title: Text('Редактор сообщений'),
                          dense: true,
                        ),
                      if (_hasAvatarGift)
                        const ListTile(
                          leading:
                              Icon(Icons.image_outlined, color: Colors.green),
                          title: Text('Право менять чужие аватарки'),
                          dense: true,
                        ),
                      if (_hasEditGift || _hasAvatarGift)
                        SwitchListTile(
                          title: const Text('Показывать эти подарки в профиле'),
                          subtitle:
                              const Text('Другие увидят их у тебя в профиле'),
                          value: _showGifts,
                          onChanged: _toggleShowGifts,
                        ),
                      if (_hasTakeoverGift) ...[
                        const Divider(height: 24),
                        const ListTile(
                          leading: Icon(Icons.warning_amber_rounded,
                              color: Colors.deepOrange),
                          title: Text('Власть над группами'),
                          subtitle: Text(
                              'Мощный подарок — по умолчанию скрыт от других'),
                          dense: true,
                        ),
                        SwitchListTile(
                          title: const Text('Показывать этот подарок другим'),
                          subtitle: const Text(
                              'Осторожно: люди будут знать о твоей власти над группами'),
                          value: _showTakeoverGift,
                          onChanged: _toggleShowTakeoverGift,
                        ),
                      ],
                    ],
                  ]),
                ),
              ],
            ),
    );
  }
}