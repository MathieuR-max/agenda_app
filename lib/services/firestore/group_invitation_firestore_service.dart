import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agenda_app/models/group_invitation.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/current_user.dart';

class GroupInvitationFirestoreService {
  final FirebaseFirestore _db;
  final GroupsRepository _groupsRepository;

  static const String _groupInvitationsCollection = 'group_invitations';

  GroupInvitationFirestoreService({
    FirebaseFirestore? db,
    GroupsRepository? groupsRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _groupsRepository =
            groupsRepository ?? GroupsRepository(db: db);

  String? get currentUserId {
    final uid = AuthUser.uidOrNull?.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _db.collection(_groupInvitationsCollection);

  Stream<List<GroupInvitation>> getReceivedInvitations() {
    final userId = currentUserId;

    if (userId == null) {
      return Stream.value(<GroupInvitation>[]);
    }

    return _streamInvitationsForQuery(
      _invitations.where('toUserId', isEqualTo: userId),
      debugLabel: 'received',
    );
  }

  Stream<List<GroupInvitation>> getPendingReceivedInvitations() {
    final userId = currentUserId;

    if (userId == null) {
      return Stream.value(<GroupInvitation>[]);
    }

    return _streamInvitationsForQuery(
      _invitations
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: GroupInvitation.statusPending),
      debugLabel: 'pending_received',
    );
  }

  Stream<List<GroupInvitation>> getSentInvitationsForGroup(String groupId) {
    final userId = currentUserId;
    final trimmedGroupId = groupId.trim();

    if (userId == null || trimmedGroupId.isEmpty) {
      return Stream.value(<GroupInvitation>[]);
    }

    return _streamInvitationsForQuery(
      _invitations
          .where('fromUserId', isEqualTo: userId)
          .where('groupId', isEqualTo: trimmedGroupId),
      debugLabel: 'sent_for_group',
    );
  }

  Stream<List<GroupInvitation>> getSentInvitations() {
    final userId = currentUserId;

    if (userId == null) {
      return Stream.value(<GroupInvitation>[]);
    }

    return _streamInvitationsForQuery(
      _invitations.where('fromUserId', isEqualTo: userId),
      debugLabel: 'sent',
    );
  }

  Future<bool> createInvitation({
    required String groupId,
    required String groupName,
    required String fromUserId,
    required String fromUserPseudo,
    required String toUserId,
    required String toUserPseudo,
  }) async {
    final authenticatedUserId = currentUserId;

    if (authenticatedUserId == null) {
      return false;
    }

    final trimmedGroupId = groupId.trim();
    final trimmedGroupName = groupName.trim();
    final trimmedFromUserId = fromUserId.trim();
    final trimmedFromUserPseudo = fromUserPseudo.trim();
    final trimmedToUserId = toUserId.trim();
    final trimmedToUserPseudo = toUserPseudo.trim();

    if (trimmedGroupId.isEmpty ||
        trimmedGroupName.isEmpty ||
        trimmedFromUserId.isEmpty ||
        trimmedToUserId.isEmpty) {
      return false;
    }

    if (trimmedFromUserId != authenticatedUserId) {
      return false;
    }

    if (trimmedFromUserId == trimmedToUserId) {
      return false;
    }

    try {
      final existingPending = await _invitations
          .where('groupId', isEqualTo: trimmedGroupId)
          .where('toUserId', isEqualTo: trimmedToUserId)
          .where('status', isEqualTo: GroupInvitation.statusPending)
          .limit(1)
          .get();

      if (existingPending.docs.isNotEmpty) {
        return false;
      }

      await _invitations.add({
        'groupId': trimmedGroupId,
        'groupName': trimmedGroupName,
        'fromUserId': authenticatedUserId,
        'fromUserPseudo': trimmedFromUserPseudo,
        'toUserId': trimmedToUserId,
        'toUserPseudo': trimmedToUserPseudo,
        'status': GroupInvitation.statusPending,
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      return true;
    } catch (e) {
      debugPrint('GROUP_INVITATIONS createInvitation error: $e');
      return false;
    }
  }

  Future<bool> acceptInvitation(GroupInvitation invitation) async {
    final userId = currentUserId;

    if (userId == null) {
      return false;
    }

    final invitationId = invitation.id.trim();
    final groupId = invitation.groupId.trim();

    if (invitationId.isEmpty || groupId.isEmpty) {
      return false;
    }

    final invitationRef = _invitations.doc(invitationId);

    try {
      final invitationSnap = await invitationRef.get();

      if (!invitationSnap.exists || invitationSnap.data() == null) {
        return false;
      }

      final invitationData = invitationSnap.data()!;
      final toUserId = (invitationData['toUserId'] ?? '').toString().trim();
      final status = (invitationData['status'] ?? '').toString().trim();

      if (toUserId != userId) {
        return false;
      }

      if (status == GroupInvitation.statusRefused ||
          status == GroupInvitation.statusCancelled) {
        return false;
      }

      final alreadyMember =
          await _groupsRepository.isUserMember(groupId, userId);

      if (status == GroupInvitation.statusAccepted && alreadyMember) {
        return true;
      }

      if (!alreadyMember) {
        final addSuccess = await _groupsRepository.addMember(
          groupId: groupId,
          userId: userId,
        );

        if (!addSuccess) {
          return false;
        }
      }

      await invitationRef.update({
        'status': GroupInvitation.statusAccepted,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('GROUP_INVITATIONS acceptInvitation error: $e');
      return false;
    }
  }

  Future<bool> declineInvitation(GroupInvitation invitation) async {
    final userId = currentUserId;

    if (userId == null) {
      return false;
    }

    final invitationId = invitation.id.trim();

    if (invitationId.isEmpty) {
      return false;
    }

    final invitationRef = _invitations.doc(invitationId);

    try {
      return await _db.runTransaction((transaction) async {
        final invitationSnap = await transaction.get(invitationRef);

        if (!invitationSnap.exists || invitationSnap.data() == null) {
          return false;
        }

        final data = invitationSnap.data()!;
        final toUserId = (data['toUserId'] ?? '').toString().trim();
        final status = (data['status'] ?? '').toString().trim();

        if (toUserId != userId) {
          return false;
        }

        if (status != GroupInvitation.statusPending) {
          return false;
        }

        transaction.update(invitationRef, {
          'status': GroupInvitation.statusRefused,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('GROUP_INVITATIONS declineInvitation error: $e');
      return false;
    }
  }

  Future<bool> cancelInvitation(GroupInvitation invitation) async {
    final userId = currentUserId;

    if (userId == null) {
      return false;
    }

    final invitationId = invitation.id.trim();

    if (invitationId.isEmpty) {
      return false;
    }

    final invitationRef = _invitations.doc(invitationId);

    try {
      return await _db.runTransaction((transaction) async {
        final invitationSnap = await transaction.get(invitationRef);

        if (!invitationSnap.exists || invitationSnap.data() == null) {
          return false;
        }

        final data = invitationSnap.data()!;
        final fromUserId = (data['fromUserId'] ?? '').toString().trim();
        final status = (data['status'] ?? '').toString().trim();

        if (fromUserId != userId) {
          return false;
        }

        if (status != GroupInvitation.statusPending) {
          return false;
        }

        transaction.update(invitationRef, {
          'status': GroupInvitation.statusCancelled,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('GROUP_INVITATIONS cancelInvitation error: $e');
      return false;
    }
  }

  Stream<List<GroupInvitation>> _streamInvitationsForQuery(
    Query<Map<String, dynamic>> query, {
    required String debugLabel,
  }) {
    return query.snapshots().map((snapshot) {
      final invitations = snapshot.docs
          .map((doc) =>
              GroupInvitation.fromFirestore(doc.data(), doc.id))
          .toList();

      invitations.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      return invitations;
    });
  }
}