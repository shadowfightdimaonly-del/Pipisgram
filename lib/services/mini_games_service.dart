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
    final docId = '${_myUid}_clicker_$_today';
    final ref = _db.collection('gameStats').doc(docId);

    return _db.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data() ?? {};
      final current = (data['taps'] ?? 0) as int;

      if (current >= 1000) return current;

      final newCount = current + 1;
      transaction.set(
        ref,
        {'taps': newCount},
        SetOptions(merge: true),
      );
      return newCount;
    });
  }

  Future<int> cashOutClickerStars(int ignoredTaps) async {
    final gameRef = _db
        .collection('gameStats')
        .doc('${_myUid}_clicker_$_today');
    final userRef = _db.collection('users').doc(_myUid);

    return _db.runTransaction<int>((transaction) async {
      final gameSnapshot = await transaction.get(gameRef);
      final gameData = gameSnapshot.data() ?? {};

      final taps = ((gameData['taps'] ?? 0) as num).toInt().clamp(0, 1000);
      final cashedOutTaps =
          ((gameData['cashedOutTaps'] ?? 0) as num).toInt().clamp(0, taps);

      final availableTaps = taps - cashedOutTaps;
      final wholeStars = (availableTaps * 3) ~/ 10;

      if (wholeStars <= 0) return 0;

      final tapsToCashOut = wholeStars * 10 ~/ 3;

      transaction.update(userRef, {
        'shadowStars': FieldValue.increment(wholeStars),
      });
      transaction.set(
        gameRef,
        {'cashedOutTaps': cashedOutTaps + tapsToCashOut},
        SetOptions(merge: true),
      );

      return wholeStars;
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
    final ref = _db
        .collection('gameStats')
        .doc('${_myUid}_guess_$_today');

    return _db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data() ?? {};
      final used = ((data['attempts'] ?? 0) as num).toInt();

      if (used >= 3) return false;

      transaction.set(
        ref,
        {'attempts': used + 1},
        SetOptions(merge: true),
      );
      return true;
    });
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