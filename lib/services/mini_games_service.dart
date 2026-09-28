import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MiniGamesService {
  static const _workerUrl = 'https://pipisgram-media.burmaldat199.workers.dev';

  final _db = FirebaseFirestore.instance;
  final _myUid = FirebaseAuth.instance.currentUser!.uid;

  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<Map<String, dynamic>> _getTodayStats(String gameId) async {
    final docId = '${_myUid}_${gameId}_$_today';
    final doc = await _db.collection('gameStats').doc(docId).get();
    return doc.data() ?? {};
  }

  Future<int> getClickerTapsToday() async {
    final stats = await _getTodayStats('clicker');
    return stats['taps'] ?? 0;
  }

  Future<int> registerClickerTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить Firebase ID token');
    }

    final response = await http.post(
      Uri.parse('$_workerUrl/economy/clicker/tap'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'date': _today}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Clicker tap failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['taps'] as num?)?.toInt() ?? 0;
  }

  Future<int> getClickerAvailableTaps() async {
    final stats = await _getTodayStats('clicker');
    final taps = ((stats['taps'] ?? 0) as num).toInt().clamp(0, 1000);
    final cashedOutTaps =
        ((stats['cashedOutTaps'] ?? 0) as num).toInt().clamp(0, taps);
    return taps - cashedOutTaps;
  }

  Future<int> cashOutClickerStars() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить Firebase ID token');
    }

    final response = await http.post(
      Uri.parse('$_workerUrl/economy/clicker/cashout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'date': _today}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Clicker cashout failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['stars'] as num?)?.toInt() ?? 0;
  }
  Future<Map<String, dynamic>> economyAction({
    required String action,
    int? amount,
    String? targetUid,
    String? giftId,
    String? reason,
    String? code,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить Firebase ID token');
    }

    final response = await http.post(
      Uri.parse('$_workerUrl/economy/action'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': action,
        if (amount != null) 'amount': amount,
        if (targetUid != null) 'targetUid': targetUid,
        if (giftId != null) 'giftId': giftId,
        if (reason != null) 'reason': reason,
        if (code != null) 'code': code,
      }),
    );

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ?? 'Economy action failed: ${response.statusCode}',
      );
    }

    return data;
  }

  Future<int> getGuessAttemptsLeft() async {
    final stats = await _getTodayStats('guess');
    final used = (stats['attempts'] ?? 0) as int;
    final left = 3 - used;
    if (left < 0) return 0;
    if (left > 3) return 3;
    return left;
  }

  Future<Map<String, dynamic>> submitGuess(int number) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить Firebase ID token');
    }

    final response = await http.post(
      Uri.parse('$_workerUrl/economy/guess'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'date': _today,
        'number': number,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Guess failed: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }


  Future<int> cashOutDinoStars(int jumps) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить Firebase ID token');
    }

    final response = await http.post(
      Uri.parse('$_workerUrl/economy/dino/cashout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'jumps': jumps, 'date': _today}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Dino cashout failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['stars'] as num?)?.toInt() ?? 0;
  }
}