import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class HelpService {
  static const _workerUrl =
      'https://pipisgram-media.burmaldat199.workers.dev';

  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  String get uid => auth.currentUser!.uid;

  Future<Map<String, dynamic>> _action(
    String action, {
    String? ticketId,
    String? subject,
    String? text,
    String? reason,
    String? targetUid,
    String? mode,
    int? hours,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить Firebase ID token');
    }

    final response = await http.post(
      Uri.parse('$_workerUrl/support/action'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': action,
        if (ticketId != null) 'ticketId': ticketId,
        if (subject != null) 'subject': subject,
        if (text != null) 'text': text,
        if (reason != null) 'reason': reason,
        if (targetUid != null) 'targetUid': targetUid,
        if (mode != null) 'mode': mode,
        if (hours != null) 'hours': hours,
      }),
    );

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ??
            'Support action failed: ${response.statusCode}',
      );
    }

    return data;
  }

  Future<void> submitBlockAppeal(String email, String text) async {
    final response = await http.post(
      Uri.parse('$_workerUrl/support/appeal'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'text': text.trim(),
      }),
    );

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ??
            'Не удалось отправить обращение: ${response.statusCode}',
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> mine() {
    return db.collection('tickets')
        .where('ownerUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> all() {
    return db.collection('tickets')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String id) {
    return db.collection('tickets').doc(id).collection('messages')
        .orderBy('createdAt').snapshots();
  }

  Future<String> create(String subject, String text) async {
    final data = await _action(
      'create_ticket',
      subject: subject.trim(),
      text: text.trim(),
    );
    return data['ticketId'].toString();
  }

  Future<void> send(String id, String text) async {
    await _action(
      'send_message',
      ticketId: id,
      text: text.trim(),
    );
  }

  Future<void> close(String id, String reason) async {
    await _action(
      'close_ticket',
      ticketId: id,
      reason: reason,
    );
  }

  Future<void> reopen(String id) async {
    await _action(
      'reopen_ticket',
      ticketId: id,
    );
  }

  Future<void> warnUser(String targetUid, String reason) async {
    await _action(
      'warn_user',
      targetUid: targetUid,
      reason: reason,
    );
  }

  Future<void> blockUser(
    String targetUid, {
    required String reason,
    int hours = 24,
    bool permanent = false,
  }) async {
    await _action(
      'block_user',
      targetUid: targetUid,
      reason: reason,
      hours: hours,
      mode: permanent ? 'permanent' : 'temporary',
    );
  }

  Future<void> unblockUser(String targetUid) async {
    await _action(
      'unblock_user',
      targetUid: targetUid,
    );
  }

  Future<void> penalizeUser(String targetUid, int amount, String reason) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

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
        'action': 'penalty',
        'amount': amount,
        'targetUid': targetUid,
        'reason': reason,
      }),
    );

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'Не удалось выдать штраф');
    }
  }

  Future<bool> admin() async {
    final doc = await db.collection('users').doc(uid).get();
    return doc.data()?['isAdmin'] == true;
  }
}
