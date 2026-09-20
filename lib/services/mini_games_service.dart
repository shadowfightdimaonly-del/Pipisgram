import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MiniGamesService {
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

  Future<void> _saveTodayStats(String gameId, Map<String, dynamic> data) async {
    final docId = '${_myUid}_${gameId}_$_today';
    await _db.collection('gameStats').doc(docId).set(data, SetOptions(merge: true));
  }

  Future<int> getClickerTapsToday() async {
    final stats = await _getTodayStats('clicker');
    return stats['taps'] ?? 0;
  }

  Future<int> registerClickerTap() async {
    final current = await getClickerTapsToday();
    if (current >= 1000) return current;
    final newCount = current + 1;
    await _saveTodayStats('clicker', {'taps': newCount});
    return newCount;
  }

  Future<void> cashOutClickerStars(int taps) async {
    final wholeStars = (taps * 0.3).floor();
    if (wholeStars <= 0) return;
    await _db.collection('users').doc(_myUid).update({
      'shadowStars': FieldValue.increment(wholeStars),
    });
  }

  Future<int> getGuessAttemptsLeft() async {
    final stats = await _getTodayStats('guess');
    final used = (stats['attempts'] ?? 0) as int;
    final left = 3 - used;
    if (left < 0) return 0;
    if (left > 3) return 3;
    return left;
  }

  Future<bool> useGuessAttempt() async {
    final stats = await _getTodayStats('guess');
    final used = (stats['attempts'] ?? 0) as int;
    if (used >= 3) return false;
    await _saveTodayStats('guess', {'attempts': used + 1});
    return true;
  }

  Future<void> rewardGuessWin() async {
    await _db.collection('users').doc(_myUid).update({
      'shadowStars': FieldValue.increment(1),
    });
  }

  Future<void> cashOutDinoStars(int jumps) async {
    final wholeStars = (jumps * 0.5).floor();
    if (wholeStars <= 0) return;
    await _db.collection('users').doc(_myUid).update({
      'shadowStars': FieldValue.increment(wholeStars),
    });
  }
}