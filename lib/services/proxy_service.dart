import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ProxyConfig {
  final String host;
  final int port;
  final String? username;
  final String? password;

  ProxyConfig({
    required this.host,
    required this.port,
    this.username,
    this.password,
  });
}

/// Управляет SOCKS5-прокси на уровне HttpClient/сокетов приложения.
/// Настройки хранятся локально на устройстве (SharedPreferences),
/// нигде не отправляются на сторонние сервисы.
class ProxyService {
  ProxyService._();
  static final ProxyService instance = ProxyService._();

  ProxyConfig? config;

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('proxy_host');
    final port = prefs.getInt('proxy_port');
    if (host != null && port != null) {
      config = ProxyConfig(
        host: host,
        port: port,
        username: prefs.getString('proxy_user'),
        password: prefs.getString('proxy_pass'),
      );
    }
  }

  Future<void> configure({
    required String host,
    required int port,
    String? username,
    String? password,
  }) async {
    config = ProxyConfig(
      host: host,
      port: port,
      username: username,
      password: password,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('proxy_host', host);
    await prefs.setInt('proxy_port', port);
    if (username != null) await prefs.setString('proxy_user', username);
    if (password != null) await prefs.setString('proxy_pass', password);
  }

  Future<void> disable() async {
    config = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('proxy_host');
    await prefs.remove('proxy_port');
    await prefs.remove('proxy_user');
    await prefs.remove('proxy_pass');
  }

  Future<bool> testConnection() async {
    if (config == null) return false;
    try {
      final socket = await Socket.connect(
        config!.host,
        config!.port,
        timeout: const Duration(seconds: 5),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
