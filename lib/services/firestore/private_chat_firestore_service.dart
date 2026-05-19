import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/services/current_user.dart';

class PrivateChatFirestoreService {
  final FirebaseFirestore _db;

  static const String _collection = 'private_chats';

  PrivateChatFirestoreService({
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  String? get currentUserIdOrNull {
    final uid = AuthUser.uidOrNull?.trim();
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  String buildChatId(String uid1, String uid2) {
    final ids = [uid1.trim(), uid2.trim()]..sort();
    return ids.join('_');
  }

  DocumentReference<Map<String, dynamic>> _chatRef(String chatId) =>
      _db.collection(_collection).doc(chatId);

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) =>
      _chatRef(chatId).collection('messages');

  DocumentReference<Map<String, dynamic>> _messageReadRef({
    required String chatId,
    required String userId,
  }) =>
      _chatRef(chatId).collection('messageReads').doc(userId.trim());

  Future<String> getOrCreateChat(String uid1, String uid2) async {
    final trimmedUid1 = uid1.trim();
    final trimmedUid2 = uid2.trim();

    if (trimmedUid1.isEmpty || trimmedUid2.isEmpty) {
      throw Exception('Invalid user IDs for private chat');
    }

    final chatId = buildChatId(trimmedUid1, trimmedUid2);
    final ref = _chatRef(chatId);
    final ids = [trimmedUid1, trimmedUid2]..sort();

    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) {
        transaction.set(ref, {
          'participantIds': ids,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessageText': null,
          'lastMessageAt': null,
        });
      }
    });

    return chatId;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderPseudo,
    required String text,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedText = text.trim();
    final trimmedPseudo = senderPseudo.trim();

    if (trimmedChatId.isEmpty || trimmedText.isEmpty || trimmedPseudo.isEmpty) {
      return;
    }

    await _messagesRef(trimmedChatId).add({
      'senderId': senderId.trim(),
      'senderPseudo': trimmedPseudo,
      'text': trimmedText,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _chatRef(trimmedChatId).update({
      'lastMessageText': trimmedText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _messagesRef(trimmedChatId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'senderId': (data['senderId'] ?? '').toString(),
          'senderPseudo': (data['senderPseudo'] ?? '').toString(),
          'text': (data['text'] ?? '').toString(),
          'type': (data['type'] ?? 'text').toString(),
          'createdAt': data['createdAt'],
        };
      }).toList();
    });
  }

  Future<void> markAsRead({
    required String chatId,
    required String userId,
  }) async {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) return;

    await _messageReadRef(chatId: trimmedChatId, userId: trimmedUserId).set({
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DateTime?> watchLastReadAt({
    required String chatId,
    required String userId,
  }) {
    final trimmedChatId = chatId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedChatId.isEmpty || trimmedUserId.isEmpty) {
      return Stream.value(null);
    }

    return _messageReadRef(chatId: trimmedChatId, userId: trimmedUserId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final value = data['lastReadAt'];
      if (value is Timestamp) return value.toDate();
      return null;
    });
  }
}
