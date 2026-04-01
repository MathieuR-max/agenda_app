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

  Stream<List<GroupMessage>> watchMessages(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
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
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return false;
    }

    final isMember = await _groupsRepository.isCurrentUserMember(groupId);
    if (!isMember) {
      return false;
    }

    final senderPseudo = await _userService.getCurrentUserPseudo();

    await _addMessage(
      groupId: groupId,
      text: trimmedText,
      senderId: currentUserId,
      senderPseudo: senderPseudo,
      type: GroupMessage.typeUser,
    );

    await _groupsRepository.touchGroup(groupId);

    return true;
  }

  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  }) async {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return;
    }

    await _addMessage(
      groupId: groupId,
      text: trimmedText,
      senderId: '',
      senderPseudo: 'Système',
      type: GroupMessage.typeSystem,
    );

    await _groupsRepository.touchGroup(groupId);
  }

  Future<void> _addMessage({
    required String groupId,
    required String text,
    required String senderId,
    required String senderPseudo,
    required String type,
  }) async {
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': senderId,
      'senderPseudo': senderPseudo,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}