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

  String? get currentUserIdOrNull {
    final uid = AuthUser.uidOrNull?.trim();

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

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) {
    return _db.collection('groups').doc(groupId.trim()).collection('messages');
  }

  DocumentReference<Map<String, dynamic>> _messageReadRef(String groupId) {
    final uid = currentUserId;

    return _db
        .collection('groups')
        .doc(groupId.trim())
        .collection('messageReads')
        .doc(uid);
  }

  Stream<List<GroupMessage>> watchMessages(String groupId) {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return Stream.value(<GroupMessage>[]);
    }

    return _messagesRef(trimmedGroupId)
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
    final uid = currentUserIdOrNull;

    if (trimmedGroupId.isEmpty || trimmedText.isEmpty || uid == null) {
      return false;
    }

    final isMember = await _groupsRepository.isCurrentUserMember(trimmedGroupId);

    if (!isMember) {
      return false;
    }

    final senderPseudo = await _userService.getCurrentUserPseudo();

    await _addTextMessage(
      groupId: trimmedGroupId,
      text: trimmedText,
      senderId: uid,
      senderPseudo: senderPseudo,
    );

    await _groupsRepository.touchGroup(trimmedGroupId);

    return true;
  }

  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  }) async {
    throw UnsupportedError(
      'Les messages système ne doivent plus être écrits côté client. '
      'Ils doivent être créés par un backend / Cloud Function.',
    );
  }

  Future<void> markGroupChatAsRead(String groupId) async {
    final trimmedGroupId = groupId.trim();
    final uid = currentUserIdOrNull;

    if (trimmedGroupId.isEmpty || uid == null) {
      return;
    }

    final isMember = await _groupsRepository.isCurrentUserMember(trimmedGroupId);

    if (!isMember) {
      return;
    }

    await _messageReadRef(trimmedGroupId).set({
      'userId': uid,
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DateTime?> watchLastReadAt(String groupId) {
    final trimmedGroupId = groupId.trim();
    final uid = currentUserIdOrNull;

    if (trimmedGroupId.isEmpty || uid == null) {
      return Stream.value(null);
    }

    return _db
        .collection('groups')
        .doc(trimmedGroupId)
        .collection('messageReads')
        .doc(uid)
        .snapshots()
        .map((doc) {
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

  Stream<int> watchUnreadCount(String groupId) {
    final trimmedGroupId = groupId.trim();
    final uid = currentUserIdOrNull;

    if (trimmedGroupId.isEmpty || uid == null) {
      return Stream.value(0);
    }

    return watchLastReadAt(trimmedGroupId).asyncMap((lastReadAt) async {
      final isMember = await _groupsRepository.isCurrentUserMember(
        trimmedGroupId,
      );

      if (!isMember) {
        return 0;
      }

      final snapshot = await _messagesRef(trimmedGroupId)
          .orderBy('createdAt', descending: false)
          .get();

      int unreadCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = (data['senderId'] ?? '').toString().trim();
        final type = (data['type'] ?? '').toString().trim();
        final createdAtRaw = data['createdAt'];

        if (type == GroupMessage.typeSystem) {
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

  Future<void> _addTextMessage({
    required String groupId,
    required String text,
    required String senderId,
    required String senderPseudo,
  }) async {
    await _messagesRef(groupId).add({
      'text': text,
      'senderId': senderId,
      'senderPseudo': senderPseudo,
      'type': GroupMessage.typeUser,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}