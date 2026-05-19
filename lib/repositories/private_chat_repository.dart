import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/models/private_message.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/private_chat_firestore_service.dart';

class PrivateChatRepository {
  final PrivateChatFirestoreService _service;
  final FirebaseFirestore _db;

  static const String _collection = 'private_chats';

  PrivateChatRepository({
    PrivateChatFirestoreService? service,
    FirebaseFirestore? db,
  })  : _db = db ?? FirebaseFirestore.instance,
        _service = service ?? PrivateChatFirestoreService(db: db);

  String? get currentUserIdOrNull {
    final uid = AuthUser.uidOrNull?.trim();
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  String get currentUserId {
    final uid = currentUserIdOrNull;
    if (uid == null) throw Exception('No authenticated Firebase user');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) {
    return _db
        .collection(_collection)
        .doc(chatId.trim())
        .collection('messages');
  }

  Future<String> getOrCreateChatWithUser(String otherUserId) async {
    final uid = currentUserId;
    return _service.getOrCreateChat(uid, otherUserId.trim());
  }

  Stream<List<PrivateMessage>> streamMessages(String chatId) {
    final trimmedChatId = chatId.trim();

    if (trimmedChatId.isEmpty) {
      return Stream.value(<PrivateMessage>[]);
    }

    return _service.getMessages(trimmedChatId).map((messages) {
      return messages.map((data) {
        return PrivateMessage.fromMap(
          (data['id'] ?? '').toString(),
          trimmedChatId,
          data,
        );
      }).toList();
    });
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderPseudo,
    required String text,
  }) async {
    final uid = currentUserIdOrNull;
    final trimmedChatId = chatId.trim();
    final trimmedText = text.trim();
    final trimmedPseudo = senderPseudo.trim();

    if (uid == null ||
        trimmedChatId.isEmpty ||
        trimmedText.isEmpty ||
        trimmedPseudo.isEmpty) {
      return;
    }

    await _service.sendMessage(
      chatId: trimmedChatId,
      senderId: uid,
      senderPseudo: trimmedPseudo,
      text: trimmedText,
    );
  }

  Future<void> markAsRead(String chatId) async {
    final uid = currentUserIdOrNull;
    final trimmedChatId = chatId.trim();

    if (uid == null || trimmedChatId.isEmpty) return;

    await _service.markAsRead(chatId: trimmedChatId, userId: uid);
  }

  Stream<DateTime?> watchLastReadAt(String chatId) {
    final uid = currentUserIdOrNull;
    final trimmedChatId = chatId.trim();

    if (uid == null || trimmedChatId.isEmpty) return Stream.value(null);

    return _service.watchLastReadAt(chatId: trimmedChatId, userId: uid);
  }

  Stream<int> watchUnreadCount(String chatId) {
    final uid = currentUserIdOrNull;
    final trimmedChatId = chatId.trim();

    if (uid == null || trimmedChatId.isEmpty) return Stream.value(0);

    return watchLastReadAt(trimmedChatId).asyncMap((lastReadAt) async {
      final snapshot = await _messagesRef(trimmedChatId)
          .orderBy('createdAt', descending: false)
          .get();

      int unreadCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = (data['senderId'] ?? '').toString().trim();
        final type = (data['type'] ?? '').toString().trim();
        final createdAtRaw = data['createdAt'];

        if (type == PrivateMessage.typeSystem) continue;
        if (senderId == uid) continue;

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
}
