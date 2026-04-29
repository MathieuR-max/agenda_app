import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agenda_app/models/activity_message.dart';
import 'package:agenda_app/services/firestore/chat_firestore_service.dart';

class ChatRepository {
  final ChatFirestoreService _service;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ChatRepository({
    ChatFirestoreService? service,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _service = service ??
            ChatFirestoreService(
              db: db,
              auth: auth,
            );

  String? get currentUserIdOrNull {
    final uid = _auth.currentUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  String get currentUserId {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      throw Exception('No authenticated Firebase user');
    }

    return uid;
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String activityId) {
    return _db
        .collection('activities')
        .doc(activityId.trim())
        .collection('messages');
  }

  DocumentReference<Map<String, dynamic>> _messageReadRef({
    required String activityId,
    required String userId,
  }) {
    return _db
        .collection('activities')
        .doc(activityId.trim())
        .collection('messageReads')
        .doc(userId.trim());
  }

  Stream<List<ActivityMessage>> streamMessages(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(<ActivityMessage>[]);
    }

    return _service.getMessages(trimmedActivityId).map(
      (messages) => messages.map((data) {
        return ActivityMessage(
          id: (data['id'] ?? '').toString(),
          activityId: trimmedActivityId,
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
    final trimmedActivityId = activityId.trim();
    final trimmedSenderId = senderId.trim();
    final trimmedContent = content.trim();

    if (trimmedActivityId.isEmpty ||
        trimmedSenderId.isEmpty ||
        trimmedContent.isEmpty) {
      return;
    }

    await _service.sendMessage(
      activityId: trimmedActivityId,
      senderId: trimmedSenderId,
      senderPseudo: senderPseudo.trim(),
      text: trimmedContent,
    );
  }

  Future<void> sendSystemMessage({
    required String activityId,
    required String content,
  }) async {
    final trimmedActivityId = activityId.trim();
    final trimmedContent = content.trim();

    if (trimmedActivityId.isEmpty || trimmedContent.isEmpty) {
      return;
    }

    await _service.addSystemMessage(
      activityId: trimmedActivityId,
      text: trimmedContent,
    );
  }

  Future<void> markActivityChatAsRead(String activityId) async {
    final uid = currentUserIdOrNull;
    final trimmedActivityId = activityId.trim();

    if (uid == null || trimmedActivityId.isEmpty) {
      return;
    }

    await _messageReadRef(
      activityId: trimmedActivityId,
      userId: uid,
    ).set({
      'userId': uid,
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DateTime?> watchLastReadAt(String activityId) {
    final uid = currentUserIdOrNull;
    final trimmedActivityId = activityId.trim();

    if (uid == null || trimmedActivityId.isEmpty) {
      return Stream.value(null);
    }

    return _messageReadRef(
      activityId: trimmedActivityId,
      userId: uid,
    ).snapshots().map((doc) {
      final data = doc.data();

      if (data == null) {
        return null;
      }

      final value = data['lastReadAt'];

      if (value is Timestamp) {
        return value.toDate();
      }

      return null;
    });
  }

  Stream<int> watchUnreadCount(String activityId) {
    final uid = currentUserIdOrNull;
    final trimmedActivityId = activityId.trim();

    if (uid == null || trimmedActivityId.isEmpty) {
      return Stream.value(0);
    }

    return watchLastReadAt(trimmedActivityId).asyncMap((lastReadAt) async {
      final snapshot = await _messagesRef(trimmedActivityId)
          .orderBy('createdAt', descending: false)
          .get();

      int unreadCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = (data['senderId'] ?? '').toString().trim();
        final type = (data['type'] ?? '').toString().trim();
        final createdAtRaw = data['createdAt'];

        if (type == 'system') {
          continue;
        }

        if (senderId == uid) {
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