import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/group_invitation.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class GroupInvitationRepository {
  final FirebaseFirestore _db;
  final UserFirestoreService _userService;
  final GroupsRepository _groupsRepository;

  static const String _groupInvitationsCollection = 'group_invitations';

  GroupInvitationRepository({
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

  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _db.collection(FirestoreCollections.groups);

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _groupInvitationsRef =>
      _db.collection(_groupInvitationsCollection);

  Future<bool> isUserAlreadyMember({
    required String groupId,
    required String userId,
  }) async {
    final trimmedGroupId = groupId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedGroupId.isEmpty || trimmedUserId.isEmpty) {
      return false;
    }

    return _groupsRepository.isUserMember(
      trimmedGroupId,
      trimmedUserId,
    );
  }

  Future<bool> hasPendingInvitation({
    required String groupId,
    required String toUserId,
  }) async {
    final uid = currentUserIdOrNull;
    final trimmedGroupId = groupId.trim();
    final trimmedToUserId = toUserId.trim();

    if (uid == null || trimmedGroupId.isEmpty || trimmedToUserId.isEmpty) {
      return false;
    }

    final query = await _groupInvitationsRef
        .where('fromUserId', isEqualTo: uid)
        .where('groupId', isEqualTo: trimmedGroupId)
        .where('toUserId', isEqualTo: trimmedToUserId)
        .where('status', isEqualTo: GroupInvitation.statusPending)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<Set<String>> getPendingInvitationTargetIds(String groupId) async {
    final uid = currentUserIdOrNull;
    final trimmedGroupId = groupId.trim();

    if (uid == null || trimmedGroupId.isEmpty) {
      return <String>{};
    }

    final snapshot = await _groupInvitationsRef
        .where('fromUserId', isEqualTo: uid)
        .where('groupId', isEqualTo: trimmedGroupId)
        .where('status', isEqualTo: GroupInvitation.statusPending)
        .get();

    return snapshot.docs
        .map((doc) => (doc.data()['toUserId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Stream<Set<String>> watchPendingInvitationTargetIds(String groupId) {
    final uid = currentUserIdOrNull;
    final trimmedGroupId = groupId.trim();

    if (uid == null || trimmedGroupId.isEmpty) {
      return Stream.value(<String>{});
    }

    return _groupInvitationsRef
        .where('fromUserId', isEqualTo: uid)
        .where('groupId', isEqualTo: trimmedGroupId)
        .where('status', isEqualTo: GroupInvitation.statusPending)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => (doc.data()['toUserId'] ?? '').toString().trim())
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
  }

  Stream<List<GroupInvitation>> getReceivedInvitations() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<GroupInvitation>[]);
    }

    return _groupInvitationsRef
        .where('toUserId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<GroupInvitation>> getPendingReceivedInvitations() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<GroupInvitation>[]);
    }

    return _groupInvitationsRef
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: GroupInvitation.statusPending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<GroupInvitation>> getSentInvitationsForGroup(String groupId) {
    final uid = currentUserIdOrNull;
    final trimmedGroupId = groupId.trim();

    if (uid == null || trimmedGroupId.isEmpty) {
      return Stream.value(<GroupInvitation>[]);
    }

    return _groupInvitationsRef
        .where('fromUserId', isEqualTo: uid)
        .where('groupId', isEqualTo: trimmedGroupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<bool> sendGroupInvitation({
    required String groupId,
    required String toUserId,
  }) async {
    final uid = currentUserIdOrNull;
    final trimmedGroupId = groupId.trim();
    final trimmedToUserId = toUserId.trim();

    if (uid == null || trimmedGroupId.isEmpty || trimmedToUserId.isEmpty) {
      return false;
    }

    if (trimmedToUserId == uid) {
      return false;
    }

    final alreadyMember = await isUserAlreadyMember(
      groupId: trimmedGroupId,
      userId: trimmedToUserId,
    );

    if (alreadyMember) {
      return false;
    }

    final alreadyInvited = await hasPendingInvitation(
      groupId: trimmedGroupId,
      toUserId: trimmedToUserId,
    );

    if (alreadyInvited) {
      return false;
    }

    final groupRef = _groupsRef.doc(trimmedGroupId);
    final toUserRef = _usersRef.doc(trimmedToUserId);
    final fromUserPseudo = await _userService.getCurrentUserPseudo();

    return _db.runTransaction((transaction) async {
      final groupDoc = await transaction.get(groupRef);
      final toUserDoc = await transaction.get(toUserRef);

      if (!groupDoc.exists || !toUserDoc.exists) {
        return false;
      }

      final groupData = groupDoc.data();
      final toUserData = toUserDoc.data();

      if (groupData == null || toUserData == null) {
        return false;
      }

      final ownerId = (groupData['ownerId'] ?? '').toString().trim();
      final groupName = (groupData['name'] ?? '').toString().trim();
      final memberIds = (groupData['memberIds'] is Iterable)
          ? (groupData['memberIds'] as Iterable)
              .map((item) => item.toString().trim())
              .where((id) => id.isNotEmpty)
              .toSet()
          : <String>{};

      if (ownerId.isEmpty || groupName.isEmpty) {
        return false;
      }

      if (ownerId != uid) {
        return false;
      }

      if (memberIds.contains(trimmedToUserId)) {
        return false;
      }

      final toUserPseudo = (toUserData['pseudo'] ?? '').toString().trim();
      final newInvitationRef = _groupInvitationsRef.doc();

      transaction.set(newInvitationRef, {
        'groupId': trimmedGroupId,
        'groupName': groupName,
        'fromUserId': uid,
        'fromUserPseudo': fromUserPseudo,
        'toUserId': trimmedToUserId,
        'toUserPseudo': toUserPseudo,
        'status': GroupInvitation.statusPending,
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      return true;
    });
  }

  Future<bool> acceptInvitation(GroupInvitation invitation) async {
    final uid = currentUserIdOrNull;
    final trimmedInvitationId = invitation.id.trim();
    final trimmedGroupId = invitation.groupId.trim();

    if (uid == null ||
        trimmedInvitationId.isEmpty ||
        trimmedGroupId.isEmpty) {
      return false;
    }

    final invitationRef = _groupInvitationsRef.doc(trimmedInvitationId);

    final success = await _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);

      if (!invitationDoc.exists || invitationDoc.data() == null) {
        return false;
      }

      final invitationData = invitationDoc.data()!;
      final invitationStatus =
          (invitationData['status'] ?? GroupInvitation.statusPending)
              .toString()
              .trim();

      if (invitationStatus != GroupInvitation.statusPending) {
        return false;
      }

      final invitationToUserId =
          (invitationData['toUserId'] ?? '').toString().trim();

      if (invitationToUserId.isNotEmpty && invitationToUserId != uid) {
        return false;
      }

      transaction.update(invitationRef, {
        'status': GroupInvitation.statusAccepted,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });

    if (!success) {
      return false;
    }

    return _groupsRepository.addMember(
      groupId: trimmedGroupId,
      userId: uid,
    );
  }

  Future<bool> refuseInvitation(String invitationId) async {
    final uid = currentUserIdOrNull;
    final trimmedInvitationId = invitationId.trim();

    if (uid == null || trimmedInvitationId.isEmpty) {
      return false;
    }

    final invitationRef = _groupInvitationsRef.doc(trimmedInvitationId);

    return _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);

      if (!invitationDoc.exists || invitationDoc.data() == null) {
        return false;
      }

      final data = invitationDoc.data()!;
      final status =
          (data['status'] ?? GroupInvitation.statusPending).toString().trim();
      final toUserId = (data['toUserId'] ?? '').toString().trim();

      if (status != GroupInvitation.statusPending) {
        return false;
      }

      if (toUserId.isNotEmpty && toUserId != uid) {
        return false;
      }

      transaction.update(invitationRef, {
        'status': GroupInvitation.statusRefused,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<bool> cancelInvitation(String invitationId) async {
    final uid = currentUserIdOrNull;
    final trimmedInvitationId = invitationId.trim();

    if (uid == null || trimmedInvitationId.isEmpty) {
      return false;
    }

    final invitationRef = _groupInvitationsRef.doc(trimmedInvitationId);

    return _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);

      if (!invitationDoc.exists || invitationDoc.data() == null) {
        return false;
      }

      final data = invitationDoc.data()!;
      final status =
          (data['status'] ?? GroupInvitation.statusPending).toString().trim();
      final fromUserId = (data['fromUserId'] ?? '').toString().trim();

      if (status != GroupInvitation.statusPending) {
        return false;
      }

      if (fromUserId.isNotEmpty && fromUserId != uid) {
        return false;
      }

      transaction.update(invitationRef, {
        'status': GroupInvitation.statusCancelled,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }
}