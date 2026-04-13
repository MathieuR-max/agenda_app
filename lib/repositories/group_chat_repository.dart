import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/models/group_message.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class GroupChatRepository {
  final FirebaseFirestore _db;
  final UserFirestoreService _userService;
  final GroupsRepository _groupsRepository;

  GroupChatRepository({
    FirebaseFirestore? db,
    UserFirestoreService? userService,
    GroupsRepository? groupsRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _userService = userService ?? UserFirestoreService(db: db),
        _groupsRepository = groupsRepository ?? GroupsRepository(db: db);

  String get currentUserId => CurrentUser.id;

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) {
    return _db.collection('groups').doc(groupId).collection('messages');
  }

  DocumentReference<Map<String, dynamic>> _messageReadRef(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messageReads')
        .doc(currentUserId);
  }

  Stream<List<GroupMessage>> watchMessages(String groupId) {
    return _messagesRef(groupId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupMessage.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<bool> sendMessage({
    required String groupId,
    required String text,
  }) async {
    final trimmedGroupId = groupId.trim();
    final trimmedText = text.trim();

    if (trimmedGroupId.isEmpty || trimmedText.isEmpty) {
      return false;
    }

    final isMember = await _groupsRepository.isCurrentUserMember(trimmedGroupId);
    if (!isMember) {
      return false;
    }

    final senderPseudo = await _userService.getCurrentUserPseudo();

    await _addMessage(
      groupId: trimmedGroupId,
      text: trimmedText,
      senderId: currentUserId,
      senderPseudo: senderPseudo,
      type: GroupMessage.typeUser,
    );

    await _groupsRepository.touchGroup(trimmedGroupId);

    return true;
  }

  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  }) async {
    final trimmedGroupId = groupId.trim();
    final trimmedText = text.trim();

    if (trimmedGroupId.isEmpty || trimmedText.isEmpty) {
      return;
    }

    await _addMessage(
      groupId: trimmedGroupId,
      text: trimmedText,
      senderId: '',
      senderPseudo: 'Système',
      type: GroupMessage.typeSystem,
    );

    await _groupsRepository.touchGroup(trimmedGroupId);
  }

  Future<void> markGroupChatAsRead(String groupId) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) return;
    if (currentUserId.trim().isEmpty) return;

    final isMember = await _groupsRepository.isCurrentUserMember(trimmedGroupId);
    if (!isMember) return;

    await _messageReadRef(trimmedGroupId).set({
      'userId': currentUserId,
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DateTime?> watchLastReadAt(String groupId) {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty || currentUserId.trim().isEmpty) {
      return Stream.value(null);
    }

    return _messageReadRef(trimmedGroupId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;

      final value = data['lastReadAt'];
      if (value is Timestamp) return value.toDate();
      return null;
    });
  }

  Stream<int> watchUnreadCount(String groupId) {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty || currentUserId.trim().isEmpty) {
      return Stream.value(0);
    }

    return watchLastReadAt(trimmedGroupId).asyncMap((lastReadAt) async {
      final isMember = await _groupsRepository.isCurrentUserMember(trimmedGroupId);
      if (!isMember) return 0;

      final snapshot = await _messagesRef(trimmedGroupId)
          .orderBy('createdAt', descending: false)
          .get();

      int unreadCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = (data['senderId'] ?? '').toString();
        final type = (data['type'] ?? '').toString();
        final createdAtRaw = data['createdAt'];

        if (type == GroupMessage.typeSystem) {
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

  Future<void> _addMessage({
    required String groupId,
    required String text,
    required String senderId,
    required String senderPseudo,
    required String type,
  }) async {
    await _messagesRef(groupId).add({
      'text': text,
      'senderId': senderId,
      'senderPseudo': senderPseudo,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}