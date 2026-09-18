import 'package:flutter/material.dart';
import '../services/proxy_service.dart';

class ProxySettingsScreen extends StatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  State<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends State<ProxySettingsScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _enabled = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final cfg = ProxyService.instance.config;
    _hostCtrl.text = cfg?.host ?? '';
    _portCtrl.text = cfg?.port.toString() ?? '';
    _userCtrl.text = cfg?.username ?? '';
    _passCtrl.text = cfg?.password ?? '';
    _enabled = cfg != null;
  }

  Future<void> _save() async {
    if (!_enabled) {
      await ProxyService.instance.disable();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Прокси отключён')));
      }
      return;
    }

    final port = int.tryParse(_portCtrl.text.trim());
    if (_hostCtrl.text.trim().isEmpty || port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажи корректные хост и порт')),
      );
      return;
    }

    await ProxyService.instance.configure(
      host: _hostCtrl.text.trim(),
      port: port,
      username: _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(),
      password: _passCtrl.text.trim().isEmpty ? null : _passCtrl.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Прокси сохранён')));
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final ok = await ProxyService.instance.testConnection();
    setState(() {
      _testing = false;
      _testResult = ok ? 'Соединение работает ✅' : 'Не удалось подключиться ❌';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки прокси')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Использовать прокси (SOCKS5)'),
            subtitle: const Text('Обход региональных ограничений'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const Divider(),
          TextField(
            controller: _hostCtrl,
            enabled: _enabled,
            decoration: const InputDecoration(
              labelText: 'Хост (IP или домен)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portCtrl,
            enabled: _enabled,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Порт',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            enabled: _enabled,
            decoration: const InputDecoration(
              labelText: 'Логин (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            enabled: _enabled,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _enabled && !_testing ? _testConnection : null,
                  child: _testing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Проверить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Text(_testResult!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          Text(
            'Подсказка: если встроенные прокси часто отваливаются, '
            'надёжнее держать под рукой 2-3 запасных SOCKS5-сервера '
            'и просто переключаться между ними здесь.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
