import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../services/help_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  static const _workerUrl =
      'https://pipisgram-media.burmaldat199.workers.dev';
  final _search = TextEditingController();
  final _help = HelpService();
  bool _loading = false;
  List<Map<String, dynamic>> _users = [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');
      final token = await user.getIdToken(true);
      final response = await http.post(
        Uri.parse(_workerUrl + '/admin/action'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (token ?? ''),
        },
        body: jsonEncode({'action': 'search_users', 'query': query}),
      );
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['error']?.toString() ?? 'Ошибка поиска');
      }
      final users = (data['users'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAction(
    String title,
    String description,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Решение применено')),
        );
        await _searchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<String?> _reasonDialog(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Причина'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _warn(Map<String, dynamic> user) async {
    final reason = await _reasonDialog('Предупреждение');
    if (reason == null) return;
    await _confirmAction(
      'Подтвердить предупреждение?',
      'Пользователь @' + (user['username'] ?? '—').toString() +
          ' получит предупреждение.\n\nПричина: ' + reason,
      () => _help.warnUser(user['uid'].toString(), reason),
    );
  }

  Future<void> _block(Map<String, dynamic> user, {required bool permanent}) async {
    final reason = await _reasonDialog(
      permanent ? 'Причина постоянной блокировки' : 'Причина заморозки',
    );
    if (reason == null) return;

    if (permanent) {
      await _confirmAction(
        '🚫 Заблокировать аккаунт навсегда?',
        'Пользователь @' + (user['username'] ?? '—').toString() +
            ' будет заблокирован навсегда.\n\nПричина: ' + reason,
        () => _help.blockUser(
          user['uid'].toString(),
          reason: reason,
          permanent: true,
        ),
      );
      return;
    }

    final hoursController = TextEditingController(text: '24');
    final hours = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заморозка аккаунта'),
        content: TextField(
          controller: hoursController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Часы', hintText: '24'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(hoursController.text.trim());
              if (value != null && value >= 1 && value <= 720) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    hoursController.dispose();
    if (hours == null) return;

    await _confirmAction(
      '🧊 Подтвердить заморозку?',
      'Аккаунт будет заморожен на ' + hours.toString() +
          ' ч.\n\nПричина: ' + reason,
      () => _help.blockUser(
        user['uid'].toString(),
        reason: reason,
        hours: hours,
      ),
    );
  }

  Future<void> _penalty(Map<String, dynamic> user) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🌟 Списание звёзд 🌟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Пользователь: @' + (user['username'] ?? '—').toString()),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество звёзд',
                hintText: '70',
                prefixText: '🌟 ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Причина'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text.trim());
              final reason = reasonController.text.trim();
              if (amount != null && amount > 0 && reason.isNotEmpty) {
                Navigator.pop(context, {'amount': amount, 'reason': reason});
              }
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    amountController.dispose();
    reasonController.dispose();
    if (result == null) return;

    final amount = result['amount'] as int;
    final reason = result['reason'] as String;
    await _confirmAction(
      '🌟 Подтвердить списание ' + amount.toString() + ' звёзд?',
      'У пользователя будет списано:\n\n🌟 ' + amount.toString() +
          '\n\nПричина: ' + reason,
      () => _help.penalizeUser(user['uid'].toString(), amount, reason),
    );
  }

  String _blockText(Map<String, dynamic> user) {
    if (user['permanentlyBlocked'] == true) return 'Заблокирован навсегда';
    final until = user['blockedUntil']?.toString();
    if (until != null && until.isNotEmpty) return 'Заморожен до ' + until;
    return 'Нет';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Панель администратора')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Поиск пользователя',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _searchUsers(),
                  decoration: const InputDecoration(
                    hintText: 'Код, username или email',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _loading ? null : _searchUsers,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_users.isEmpty)
            const Text('Результатов пока нет.')
          else
            ..._users.map(_userCard),
        ],
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@' + ((user['username']?.toString().isNotEmpty == true)
                            ? user['username'].toString()
                            : '—'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Код: ' + (user['userCode'] ?? '—').toString()),
                    ],
                  ),
                ),
                if (user['online'] == true)
                  const Icon(Icons.circle, size: 12, color: Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            Text('UID: ' + (user['uid'] ?? '—').toString()),
            Text('Email: ' + (user['email'] ?? '—').toString()),
            Text('Баланс: 🌟 ' + (user['shadowStars'] ?? 0).toString()),
            Text('Предупреждения: ' + (user['supportWarnings'] ?? 0).toString()),
            Text('Статус: ' + _blockText(user)),
            if ((user['blockReason'] ?? '').toString().isNotEmpty)
              Text('Причина блока: ' + user['blockReason'].toString()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _warn(user),
                  icon: const Icon(Icons.warning_amber),
                  label: const Text('Предупредить'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _penalty(user),
                  icon: const Icon(Icons.star),
                  label: const Text('Штраф'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _block(user, permanent: false),
                  icon: const Icon(Icons.ac_unit),
                  label: const Text('Заморозить'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _block(user, permanent: true),
                  icon: const Icon(Icons.block),
                  label: const Text('Заблокировать'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _confirmAction(
                    'Снять блокировку?',
                    'У пользователя будет снята текущая блокировка.',
                    () => _help.unblockUser(user['uid'].toString()),
                  ),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Снять блок'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
