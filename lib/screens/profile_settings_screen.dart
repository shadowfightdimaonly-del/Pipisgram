import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _db = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;
  bool _showOnlineStatus = true;
  String _username = '';
  int _profileColorValue = 0xFF2AABEE; // цвет по умолчанию, как в приложении

  final List<Color> _colorOptions = const [
    Color(0xFF2AABEE), // фирменный голубой
    Color(0xFFE53935), // красный
    Color(0xFFFB8C00), // оранжевый
    Color(0xFFFDD835), // жёлтый
    Color(0xFF43A047), // зелёный
    Color(0xFF8E24AA), // фиолетовый
    Color(0xFFD81B60), // розовый
    Color(0xFF546E7A), // серо-синий
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
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white,
                            child: Text(
                              _username.isNotEmpty
                                  ? _username[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: profileColor,
                              ),
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