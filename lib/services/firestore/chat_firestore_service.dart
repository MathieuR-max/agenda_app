import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/services/current_user.dart';

class ChatFirestoreService {
  final FirebaseFirestore _db;

  ChatFirestoreService({
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  String? get currentUserIdOrNull => AuthUser.uidOrNull?.trim();

  String get currentUserId {
    final uid = currentUserIdOrNull;

    if (uid == null || uid.isEmpty) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Aucun utilisateur Firebase authentifié.',
      );
    }

    return uid;
  }

  DocumentReference<Map<String, dynamic>> _activityRef(String activityId) {
    return _db
        .collection(FirestoreCollections.activities)
        .doc(activityId.trim());
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String activityId) {
    return _activityRef(activityId).collection(FirestoreCollections.messages);
  }

  Stream<List<Map<String, dynamic>>> getMessages(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _messagesRef(trimmedActivityId)
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
    required String senderPseudo,
    required String text,
  }) async {
    final authUid = currentUserId;
    final trimmedActivityId = activityId.trim();
    final trimmedText = text.trim();
    final trimmedPseudo = senderPseudo.trim();

    if (trimmedActivityId.isEmpty ||
        trimmedPseudo.isEmpty ||
        trimmedText.isEmpty) {
      return;
    }

    await _addTextMessage(
      activityId: trimmedActivityId,
      senderId: authUid,
      senderPseudo: trimmedPseudo,
      text: trimmedText,
    );
  }

  Future<void> addSystemMessage({
    required String activityId,
    required String text,
  }) async {
    throw UnsupportedError(
      'Les messages système ne doivent plus être écrits côté client. '
      'Ils doivent être créés par un backend / Cloud Function.',
    );
  }

  Future<void> _addTextMessage({
    required String activityId,
    required String senderId,
    required String senderPseudo,
    required String text,
  }) async {
    final activityRef = _activityRef(activityId);
    final messagesRef = _messagesRef(activityId);

    await messagesRef.add({
      'senderId': senderId,
      'senderPseudo': senderPseudo,
      'text': text,
      'type': MessageTypeValues.text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await activityRef.update({
      'lastMessageText': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}