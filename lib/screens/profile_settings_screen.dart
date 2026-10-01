import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';
import '../services/auth_service.dart';
import 'proxy_settings_screen.dart';
import 'custom_emoji_screen.dart';
import 'admin_panel_screen.dart';
import 'shadow_stars_screen.dart';
import 'gifts_screen.dart';
import 'premium_screen.dart';
import 'account_switch_screen.dart';

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
  bool _showOnlineStatus = true;
  bool _showGifts = false;
  bool _showTakeoverGift = false;
  String _username = '';
  String _userCode = '';
  String? _avatarUrl;
  String? _backgroundUrl;
  String? _badgeEmoji;
  bool _isAdmin = false;
  int _profileColorValue = 0xFF2AABEE;

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
      _badgeEmoji = data?['badgeEmoji'];
      _isAdmin = data?['isAdmin'] == true;
      _profileColorValue = data?['profileColor'] ?? 0xFF2AABEE;
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
                      onTap: _uploadingBackground
                          ? null
                          : _pickAndUploadBackground,
                      onLongPress:
                          _backgroundUrl != null ? _removeBackground : null,
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
                              onTap: _uploadingAvatar
                                  ? null
                                  : _pickAndUploadAvatar,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 48,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _avatarUrl != null
                                        ? CachedNetworkImageProvider(_avatarUrl!)
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
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.black87,
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _username.isEmpty ? '—' : '@$_username',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                            if (_badgeEmoji != null) ...[
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Image.network(_badgeEmoji!),
                                ),
                              ],
                              if (_isAdmin) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified,
                                    color: Colors.lightBlueAccent, size: 20),
                              ],
                              ],
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
                                  color: Colors.white,
                                ),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        'Цвет профиля',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _colorOptions.map((color) {
                          final isSelected =
                              color.value == _profileColorValue;
                          return GestureDetector(
                            onTap: () => _setProfileColor(color),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      )
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
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.emoji_emotions_outlined),
                        title: const Text('Мои эмодзи'),
                        subtitle:
                            const Text('Загрузи свои и выбери значок к нику'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CustomEmojiScreen(),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Твой код',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _userCode,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Скопировать код',
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _userCode),
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Код скопирован'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    ListTile(
                      leading: const Icon(Icons.card_giftcard_outlined),
                      title: const Text('Подарки'),
                      subtitle: const Text('Купленные подарки и магазин'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GiftsScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('Pipis Premium'),
                      subtitle: const Text('Лимиты, скидки и возможности'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PremiumScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Image.asset(
                        'assets/images/shadow_star.webp',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      title: const Text('Ядра'),
                      subtitle: const Text('Открыть баланс ядер'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ShadowStarsScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.vpn_lock_outlined),
                      title: const Text('Настройки прокси'),
                      subtitle: const Text('SOCKS5'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProxySettingsScreen(),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Показывать статус "в сети"'),
                      subtitle: const Text(
                        'Если выключено — ты не увидишь и чужой онлайн-статус тоже',
                      ),
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
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      if (_hasEditGift)
                        const ListTile(
                          leading: Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          title: Text('Редактор сообщений'),
                          dense: true,
                        ),
                      if (_hasAvatarGift)
                        const ListTile(
                          leading: Icon(
                            Icons.image_outlined,
                            color: Colors.green,
                          ),
                          title: Text('Право менять чужие аватарки'),
                          dense: true,
                        ),
                      if (_hasEditGift || _hasAvatarGift)
                        SwitchListTile(
                          title: const Text(
                            'Показывать эти подарки в профиле',
                          ),
                          subtitle: const Text(
                            'Другие увидят их у тебя в профиле',
                          ),
                          value: _showGifts,
                          onChanged: _toggleShowGifts,
                        ),
                      if (_hasTakeoverGift) ...[
                        const Divider(height: 24),
                        const ListTile(
                          leading: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.deepOrange,
                          ),
                          title: Text('Власть над группами'),
                          subtitle: Text(
                            'Мощный подарок — по умолчанию скрыт от других',
                          ),
                          dense: true,
                        ),
                        SwitchListTile(
                          title: const Text(
                            'Показывать этот подарок другим',
                          ),
                          subtitle: const Text(
                            'Осторожно: люди будут знать о твоей власти над группами',
                          ),
                          value: _showTakeoverGift,
                          onChanged: _toggleShowTakeoverGift,
                        ),
                      ],
                    ],
                    if (_isAdmin) ...[
                      const Divider(height: 32),
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: const Text('Панель администратора'),
                        subtitle: const Text('Поиск пользователей и модерация'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminPanelScreen(),
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    ListTile(
                      leading: const Icon(Icons.switch_account_outlined),
                      title: const Text('Сменить аккаунт'),
                      subtitle: const Text('Выбрать сохранённый аккаунт на этом устройстве'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSwitchScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Выйти из аккаунта',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Выйти из аккаунта?'),
                            content: const Text(
                              'Текущая сессия на этом устройстве будет завершена.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Выйти',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await AuthService().logout(forgetSavedAccount: true);
                        }
                      },
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}