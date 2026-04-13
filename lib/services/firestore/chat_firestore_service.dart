import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/services/current_user.dart';

class ChatFirestoreService {
  final FirebaseFirestore _db;

  ChatFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  DocumentReference<Map<String, dynamic>> _activityRef(String activityId) {
    return _db
        .collection(FirestoreCollections.activities)
        .doc(activityId);
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String activityId) {
    return _activityRef(activityId).collection(FirestoreCollections.messages);
  }

  Stream<List<Map<String, dynamic>>> getMessages(String activityId) {
    return _messagesRef(activityId)
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
    final trimmedText = text.trim();
    final trimmedPseudo = senderPseudo.trim();

    if (activityId.trim().isEmpty) return;
    if (senderId.trim().isEmpty) return;
    if (trimmedPseudo.isEmpty) return;
    if (trimmedText.isEmpty) return;

    await _addMessage(
      activityId: activityId,
      senderId: senderId,
      senderPseudo: trimmedPseudo,
      text: trimmedText,
      type: MessageTypeValues.text,
    );
  }

  Future<void> addSystemMessage({
    required String activityId,
    required String text,
  }) async {
    final trimmedText = text.trim();

    if (activityId.trim().isEmpty) return;
    if (trimmedText.isEmpty) return;

    await _addMessage(
      activityId: activityId,
      senderId: 'system',
      senderPseudo: 'Système',
      text: trimmedText,
      type: MessageTypeValues.system,
    );
  }

  Future<void> _addMessage({
    required String activityId,
    required String senderId,
    required String senderPseudo,
    required String text,
    required String type,
  }) async {
    final activityRef = _activityRef(activityId);
    final messagesRef = _messagesRef(activityId);

    await messagesRef.add({
      'senderId': senderId,
      'senderPseudo': senderPseudo,
      'text': text,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await activityRef.update({
      'lastMessageText': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}