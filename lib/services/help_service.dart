import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HelpService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  String get uid => auth.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> mine() {
    return db.collection('tickets')
        .where('ownerUid', isEqualTo: uid)
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
    final ref = db.collection('tickets').doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'ownerUid': uid,
      'subject': subject.trim(),
      'status': 'open',
      'createdAt': now,
      'updatedAt': now,
      'lastMessage': text.trim(),
    });
    await ref.collection('messages').add({
      'senderUid': uid,
      'text': text.trim(),
      'createdAt': now,
    });
    return ref.id;
  }

  Future<void> send(String id, String text) async {
    final ref = db.collection('tickets').doc(id);
    final doc = await ref.get();
    if (doc.data()?['status'] == 'closed') throw Exception('Тикет закрыт');
    await ref.collection('messages').add({
      'senderUid': uid,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await ref.update({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': text.trim(),
    });
  }

  Future<void> close(String id, String reason) async {
    await db.collection('tickets').doc(id).update({
      'status': 'closed',
      'closedReason': reason,
      'closedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reopen(String id) async {
    await db.collection('tickets').doc(id).update({
      'status': 'open',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> admin() async {
    final doc = await db.collection('users').doc(uid).get();
    return doc.data()?['isAdmin'] == true;
  }
}
