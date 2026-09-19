import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';

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
  bool _showOnlineStatus = true;
  String _username = '';
  String? _avatarUrl;
  int _profileColorValue = 0xFF2AABEE;

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
      _username = data?['username'] ?? '';
      _avatarUrl = data?['avatarUrl'];
      _profileColorValue = data?['profileColor'] ?? 0xFF2AABEE;
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

  Future<void> _setProfileColor(Color color) async {
    setState(() => _profileColorValue = color.value);
    await _db.collection('users').doc(_myUid).update({
      'profileColor': color.value,
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

  @override
  Widget build(BuildContext context) {
    final profileColor = Color(_profileColorValue);

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
                    background: Container(
                      color: profileColor,
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
                        ],
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
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
                    const Divider(height: 32),
                    SwitchListTile(
                      title: const Text('Показывать статус "в сети"'),
                      subtitle: const Text(
                          'Если выключено — ты не увидишь и чужой онлайн-статус тоже'),
                      value: _showOnlineStatus,
                      onChanged: _toggleOnlineStatus,
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}