import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/models/activity_message.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/chat_firestore_service.dart';

class ChatRepository {
  final ChatFirestoreService _service = ChatFirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  CollectionReference<Map<String, dynamic>> _messagesRef(String activityId) {
    return _db
        .collection('activities')
        .doc(activityId)
        .collection('messages');
  }

  DocumentReference<Map<String, dynamic>> _messageReadRef(String activityId) {
    return _db
        .collection('activities')
        .doc(activityId)
        .collection('messageReads')
        .doc(currentUserId);
  }

  Stream<List<ActivityMessage>> streamMessages(String activityId) {
    return _service.getMessages(activityId).map(
      (messages) => messages.map((data) {
        return ActivityMessage(
          id: (data['id'] ?? '').toString(),
          activityId: activityId,
          senderId: (data['senderId'] ?? '').toString(),
          senderPseudo: (data['senderPseudo'] ?? '').toString(),
          content: (data['text'] ?? '').toString(),
          type: (data['type'] ?? 'text').toString(),
          createdAt: _parseDate(data['createdAt']),
        );
      }).toList(),
    );
  }

  Future<void> sendMessage({
    required String activityId,
    required String senderId,
    required String senderPseudo,
    required String content,
  }) async {
    await _service.sendMessage(
      activityId: activityId,
      senderId: senderId,
      senderPseudo: senderPseudo,
      text: content,
    );
  }

  Future<void> sendSystemMessage({
    required String activityId,
    required String content,
  }) async {
    await _service.addSystemMessage(
      activityId: activityId,
      text: content,
    );
  }

  Future<void> markActivityChatAsRead(String activityId) async {
    final trimmedActivityId = activityId.trim();
    if (trimmedActivityId.isEmpty) return;
    if (currentUserId.trim().isEmpty) return;

    await _messageReadRef(trimmedActivityId).set({
      'userId': currentUserId,
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DateTime?> watchLastReadAt(String activityId) {
    final trimmedActivityId = activityId.trim();
    if (trimmedActivityId.isEmpty || currentUserId.trim().isEmpty) {
      return Stream.value(null);
    }

    return _messageReadRef(trimmedActivityId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;

      final value = data['lastReadAt'];
      if (value is Timestamp) return value.toDate();
      return null;
    });
  }

  Stream<int> watchUnreadCount(String activityId) {
    final trimmedActivityId = activityId.trim();
    if (trimmedActivityId.isEmpty || currentUserId.trim().isEmpty) {
      return Stream.value(0);
    }

    return watchLastReadAt(trimmedActivityId).asyncMap((lastReadAt) async {
      final snapshot = await _messagesRef(trimmedActivityId)
          .orderBy('createdAt', descending: false)
          .get();

      int unreadCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = (data['senderId'] ?? '').toString();
        final type = (data['type'] ?? '').toString();
        final createdAtRaw = data['createdAt'];

        if (type == 'system') {
          continue;
        }

        if (senderId == currentUserId) {
          continue;
        }

        DateTime? createdAt;
        if (createdAtRaw is Timestamp) {
          createdAt = createdAtRaw.toDate();
        }

        if (createdAt == null) {
          unreadCount++;
          continue;
        }

        if (lastReadAt == null || createdAt.isAfter(lastReadAt)) {
          unreadCount++;
        }
      }

      return unreadCount;
    });
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}