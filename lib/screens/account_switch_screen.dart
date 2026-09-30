import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AccountSwitchScreen extends StatefulWidget {
  const AccountSwitchScreen({super.key});

  @override
  State<AccountSwitchScreen> createState() => _AccountSwitchScreenState();
}

class _AccountSwitchScreenState extends State<AccountSwitchScreen> {
  final _auth = AuthService();
  late Future<List<Map<String, String>>> _accounts;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _accounts = _auth.savedAccounts();
  }

  Future<void> _switchTo(Map<String, String> account) async {
    if (_switching) return;
    setState(() => _switching = true);

    await _auth.logout();
    final loginError = await _auth.loginSavedAccount(account);

    if (!mounted) return;

    if (loginError != null) {
      setState(() => _switching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loginError)),
      );
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _addAccount() async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool loading = false;

    try {
      final added = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                final email = emailCtrl.text.trim();
                final password = passwordCtrl.text;
                if (email.isEmpty || password.isEmpty || loading) return;

                setDialogState(() => loading = true);
                final error = await _auth.login(email, password);
                if (!dialogContext.mounted) return;

                if (error != null) {
                  setDialogState(() => loading = false);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(true);
              }

              return AlertDialog(
                title: const Text('Добавить аккаунт'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !loading,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      enabled: !loading,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Добавить'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (added == true && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      emailCtrl.dispose();
      passwordCtrl.dispose();
    }
  }

  Future<void> _remove(Map<String, String> account) async {
    final email = account['email'];
    if (email == null) return;
    await _auth.removeSavedAccount(email);
    if (!mounted) return;
    setState(() {
      _accounts = _auth.savedAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сменить аккаунт'),
        actions: [
          IconButton(
            tooltip: 'Добавить аккаунт',
            onPressed: _switching ? null : _addAccount,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'На этом устройстве пока нет сохранённых аккаунтов.\n\n'
                  'После следующего входа аккаунт появится здесь.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final account = accounts[index];
              final username = account['username'] ?? 'Аккаунт';
              final email = account['email'] ?? '';

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline),
                ),
                title: Text('@$username'),
                subtitle: Text(email),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') _remove(account);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Убрать с устройства'),
                    ),
                  ],
                ),
                onTap: _switching ? null : () => _switchTo(account),
              );
            },
          );
        },
      ),
    );
  }
}
