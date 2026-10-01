import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../services/image_upload_service.dart';

import 'profile_settings_screen.dart';

const List<Map<String, dynamic>> bubbleStyles = [
  {'id': 'rounded', 'name': 'Скруглённое', 'radius': 16.0},
  {'id': 'sharp', 'name': 'Мягкое', 'radius': 4.0},
  {'id': 'pill', 'name': 'Капсула', 'radius': 24.0},
  {'id': 'square', 'name': 'Квадратное', 'radius': 0.0},
];

class MessageBubbleAppearanceScreen extends StatefulWidget {
  const MessageBubbleAppearanceScreen({super.key});

  @override
  State<MessageBubbleAppearanceScreen> createState() =>
      _MessageBubbleAppearanceScreenState();
}

class _MessageBubbleAppearanceScreenState
    extends State<MessageBubbleAppearanceScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;
  String _shape = 'rounded';
  int _color = 0xFF2AABEE;
  int _gradientColor = 0xFF8E24AA;
  double _opacity = 1;
  bool _gradientEnabled = false;
  bool _borderEnabled = false;
  int _borderColor = 0xFFFFFFFF;
  double _borderWidth = 1;
  bool _shadowEnabled = false;
  int _textColor = 0xFFFFFFFF;
  int _timeColor = 0xB3FFFFFF;
  int _checkColor = 0xFF81D4FA;
  String _decoration = 'none';
  String? _bubbleImageUrl;
  bool _uploadingBubbleImage = false;

  static const _colors = <Color>[
    Color(0xFF2AABEE), Color(0xFFE53935), Color(0xFFFB8C00),
    Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF8E24AA),
    Color(0xFFD81B60), Color(0xFF546E7A), Color(0xFF121212),
    Color(0xFFFFFFFF),
  ];

  static const _decorations = <Map<String, dynamic>>[
    {'id': 'none', 'name': 'Нет', 'icon': null},
    {'id': 'star', 'name': 'Звезда', 'icon': Icons.star},
    {'id': 'water', 'name': 'Вода', 'icon': Icons.water_drop_outlined},
    {'id': 'bolt', 'name': 'Молния', 'icon': Icons.bolt},
    {'id': 'fire', 'name': 'Огонь', 'icon': Icons.local_fire_department},
    {'id': 'heart', 'name': 'Сердце', 'icon': Icons.favorite},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _db.collection('users').doc(_uid).get();
    final data = snap.data() ?? {};
    if (!mounted) return;
    setState(() {
      _shape = data['bubbleStyle'] ?? 'rounded';
      _color = (data['bubbleColor'] ?? 0xFF2AABEE) as int;
      _gradientColor = (data['bubbleGradientColor'] ?? 0xFF8E24AA) as int;
      _opacity = ((data['bubbleOpacity'] ?? 1) as num).toDouble().clamp(0.1, 1);
      _gradientEnabled = data['bubbleGradientEnabled'] == true;
      _borderEnabled = data['bubbleBorderEnabled'] == true;
      _borderColor = (data['bubbleBorderColor'] ?? 0xFFFFFFFF) as int;
      _borderWidth = ((data['bubbleBorderWidth'] ?? 1) as num).toDouble().clamp(0.5, 6);
      _shadowEnabled = data['bubbleShadowEnabled'] == true;
      _textColor = (data['bubbleTextColor'] ?? 0xFFFFFFFF) as int;
      _timeColor = (data['bubbleTimeColor'] ?? 0xB3FFFFFF) as int;
      _checkColor = (data['bubbleCheckColor'] ?? 0xFF81D4FA) as int;
      _decoration = data['bubbleDecoration'] ?? 'none';
      _bubbleImageUrl = data['bubbleImageUrl']?.toString();
      _loading = false;
    });
  }

  Future<void> _save(String field, dynamic value) async {
    await _db.collection('users').doc(_uid).update({field: value});
  }

  Future<void> _set(String field, dynamic value, void Function() local) async {
    setState(local);
    await _save(field, value);
  }

  double _radiusFor(String shape) {
    switch (shape) {
      case 'sharp': return 4;
      case 'pill': return 24;
      case 'square': return 0;
      default: return 16;
    }
  }

  IconData? _decorationIcon() {
    for (final item in _decorations) {
      if (item['id'] == _decoration) return item['icon'] as IconData?;
    }
    return null;
  }

  Future<void> _pickBubbleImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _uploadingBubbleImage = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final url = await ImageUploadService.uploadImage(bytes);
      if (url == null) {
        throw Exception('Не удалось загрузить изображение');
      }
      await _save('bubbleImageUrl', url);
      if (mounted) {
        setState(() => _bubbleImageUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Изображение облачка загружено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingBubbleImage = false);
    }
  }

  Future<void> _removeBubbleImage() async {
    await _save('bubbleImageUrl', FieldValue.delete());
    if (mounted) setState(() => _bubbleImageUrl = null);
  }

  Widget _colorPicker({
    required String title,
    required int value,
    required Future<void> Function(Color) onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _colors.map((color) {
            final selected = color.value == value;
            return GestureDetector(
              onTap: () => onPick(color),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: selected
                    ? Icon(Icons.check,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final baseColor = Color(_color);
    final decorationIcon = _decorationIcon();
    final radius = _radiusFor(_shape);

    return Scaffold(
      appBar: AppBar(title: const Text('Облачко сообщения')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(_opacity),
                  gradient: _bubbleImageUrl == null && _gradientEnabled
                      ? LinearGradient(colors: [
                          baseColor.withOpacity(_opacity),
                          Color(_gradientColor).withOpacity(_opacity),
                        ])
                      : null,
                  image: _bubbleImageUrl == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(_bubbleImageUrl!),
                          fit: BoxFit.fill,
                        ),
                  borderRadius: BorderRadius.circular(radius),
                  border: _borderEnabled
                      ? Border.all(color: Color(_borderColor), width: _borderWidth)
                      : null,
                  boxShadow: _shadowEnabled
                      ? const [BoxShadow(blurRadius: 10, offset: Offset(0, 4))]
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 34, bottom: 18),
                      child: Text('Пример сообщения',
                          style: TextStyle(color: Color(_textColor))),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('21:37',
                              style: TextStyle(fontSize: 10, color: Color(_timeColor))),
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: Color(_checkColor)),
                        ],
                      ),
                    ),
                    if (decorationIcon != null)
                      Positioned(
                        top: -12,
                        right: -10,
                        child: Icon(decorationIcon,
                            size: 24, color: Color(_textColor).withOpacity(0.9)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Изображение облачка',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_bubbleImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _bubbleImageUrl!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _uploadingBubbleImage ? null : _pickBubbleImage,
                        icon: _uploadingBubbleImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _bubbleImageUrl == null
                              ? 'Загрузить из галереи'
                              : 'Заменить из галереи',
                        ),
                      ),
                      if (_bubbleImageUrl != null)
                        OutlinedButton.icon(
                          onPressed: _removeBubbleImage,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Убрать'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Форма', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bubbleStyles.map((style) {
              final id = style['id'] as String;
              return ChoiceChip(
                selected: id == _shape,
                label: Text(style['name'] as String),
                onSelected: (_) => _set('bubbleStyle', id, () => _shape = id),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _colorPicker(
            title: 'Цвет',
            value: _color,
            onPick: (c) => _set('bubbleColor', c.value, () => _color = c.value),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Градиент'),
            value: _gradientEnabled,
            onChanged: (v) => _set('bubbleGradientEnabled', v, () => _gradientEnabled = v),
          ),
          if (_gradientEnabled)
            _colorPicker(
              title: 'Второй цвет',
              value: _gradientColor,
              onPick: (c) => _set('bubbleGradientColor', c.value, () => _gradientColor = c.value),
            ),
          const SizedBox(height: 12),
          Text('Прозрачность: \${(_opacity * 100).round()}%'),
          Slider(
            value: _opacity,
            min: 0.1,
            max: 1,
            divisions: 18,
            onChanged: (v) => setState(() => _opacity = v),
            onChangeEnd: (v) => _save('bubbleOpacity', v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Рамка'),
            value: _borderEnabled,
            onChanged: (v) => _set('bubbleBorderEnabled', v, () => _borderEnabled = v),
          ),
          if (_borderEnabled) ...[
            _colorPicker(
              title: 'Цвет рамки',
              value: _borderColor,
              onPick: (c) => _set('bubbleBorderColor', c.value, () => _borderColor = c.value),
            ),
            const SizedBox(height: 10),
            Text('Толщина рамки: \${_borderWidth.toStringAsFixed(1)}'),
            Slider(
              value: _borderWidth,
              min: 0.5,
              max: 6,
              divisions: 11,
              onChanged: (v) => setState(() => _borderWidth = v),
              onChangeEnd: (v) => _save('bubbleBorderWidth', v),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Тень'),
            value: _shadowEnabled,
            onChanged: (v) => _set('bubbleShadowEnabled', v, () => _shadowEnabled = v),
          ),
          const SizedBox(height: 8),
          _colorPicker(
            title: 'Цвет текста',
            value: _textColor,
            onPick: (c) => _set('bubbleTextColor', c.value, () => _textColor = c.value),
          ),
          const SizedBox(height: 18),
          _colorPicker(
            title: 'Цвет времени',
            value: _timeColor,
            onPick: (c) => _set('bubbleTimeColor', c.value, () => _timeColor = c.value),
          ),
          const SizedBox(height: 18),
          _colorPicker(
            title: 'Цвет галочек',
            value: _checkColor,
            onPick: (c) => _set('bubbleCheckColor', c.value, () => _checkColor = c.value),
          ),
          const SizedBox(height: 18),
          const Text('Украшение', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _decorations.map((item) {
              final id = item['id'] as String;
              final icon = item['icon'] as IconData?;
              return ChoiceChip(
                selected: id == _decoration,
                avatar: icon == null ? null : Icon(icon, size: 18),
                label: Text(item['name'] as String),
                onSelected: (_) => _set('bubbleDecoration', id, () => _decoration = id),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Настройки сохраняются в профиле и применяются к твоим сообщениям.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
