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
      appBar: AppBar(title: const Text('Сменить аккаунт')),
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
