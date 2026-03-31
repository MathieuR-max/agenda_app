import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/services/current_user.dart';

class ChatFirestoreService {
  final FirebaseFirestore _db;

  ChatFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  Stream<List<Map<String, dynamic>>> getMessages(String activityId) {
    return _db
        .collection(FirestoreCollections.activities)
        .doc(activityId)
        .collection(FirestoreCollections.messages)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'id': doc.id,
          'text': (data['text'] ?? '').toString(),
          'senderId': (data['senderId'] ?? '').toString(),
          'senderPseudo': (data['senderPseudo'] ?? '').toString(),
          'type': (data['type'] ?? MessageTypeValues.text).toString(),
          'createdAt': data['createdAt'],
        };
      }).toList();
    });
  }

  Future<void> sendMessage({
    required String activityId,
    required String senderId,
    required String senderPseudo,
    required String text,
  }) async {
    await _db
        .collection(FirestoreCollections.activities)
        .doc(activityId)
        .collection(FirestoreCollections.messages)
        .add({
      'senderId': senderId,
      'senderPseudo': senderPseudo,
      'text': text,
      'type': MessageTypeValues.text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db
        .collection(FirestoreCollections.activities)
        .doc(activityId)
        .update({
      'lastMessageText': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addSystemMessage({
    required String activityId,
    required String text,
  }) async {
    await _db
        .collection(FirestoreCollections.activities)
        .doc(activityId)
        .collection(FirestoreCollections.messages)
        .add({
      'senderId': 'system',
      'senderPseudo': 'Système',
      'text': text,
      'type': MessageTypeValues.system,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db
        .collection(FirestoreCollections.activities)
        .doc(activityId)
        .update({
      'lastMessageText': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}