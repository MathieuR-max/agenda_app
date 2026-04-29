import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:agenda_app/models/group_invitation.dart';
import 'package:agenda_app/repositories/groups_repository.dart';

class GroupInvitationFirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final GroupsRepository _groupsRepository;

  static const String _groupInvitationsCollection = 'group_invitations';

  GroupInvitationFirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    GroupsRepository? groupsRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _groupsRepository =
            groupsRepository ?? GroupsRepository(db: db, auth: auth);

  String? get currentUserId {
    final uid = _auth.currentUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _db.collection(_groupInvitationsCollection);

  Stream<List<GroupInvitation>> getReceivedInvitations() {
    final userId = currentUserId;
    debugPrint('GROUP_INVITATIONS getReceivedInvitations currentUserId=$userId');

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
    debugPrint(
      'GROUP_INVITATIONS getPendingReceivedInvitations currentUserId=$userId',
    );

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
      debugPrint(
        'GROUP_INVITATIONS getSentInvitationsForGroup groupId=<vide> or currentUserId=<null>',
      );
      return Stream.value(<GroupInvitation>[]);
    }

    debugPrint(
      'GROUP_INVITATIONS getSentInvitationsForGroup groupId=$trimmedGroupId currentUserId=$userId',
    );

    return _streamInvitationsForQuery(
      _invitations
          .where('fromUserId', isEqualTo: userId)
          .where('groupId', isEqualTo: trimmedGroupId),
      debugLabel: 'sent_for_group',
    );
  }

  Stream<List<GroupInvitation>> getSentInvitations() {
    final userId = currentUserId;
    debugPrint('GROUP_INVITATIONS getSentInvitations currentUserId=$userId');

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
      debugPrint(
        'GROUP_INVITATIONS createInvitation aborted: currentUserId is null',
      );
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
      debugPrint('GROUP_INVITATIONS createInvitation aborted: invalid params');
      return false;
    }

    if (trimmedFromUserId != authenticatedUserId) {
      debugPrint(
        'GROUP_INVITATIONS createInvitation aborted: fromUserId does not match authenticated user',
      );
      return false;
    }

    if (trimmedFromUserId == trimmedToUserId) {
      debugPrint('GROUP_INVITATIONS createInvitation aborted: same user');
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
        debugPrint(
          'GROUP_INVITATIONS createInvitation aborted: pending invitation already exists',
        );
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
    } catch (e, stackTrace) {
      debugPrint('GROUP_INVITATIONS createInvitation error: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<bool> acceptInvitation(GroupInvitation invitation) async {
    final userId = currentUserId;

    if (userId == null) {
      debugPrint(
        'GROUP_INVITATIONS acceptInvitation aborted: currentUserId is null',
      );
      return false;
    }

    final invitationId = invitation.id.trim();
    final groupId = invitation.groupId.trim();

    if (invitationId.isEmpty || groupId.isEmpty) {
      debugPrint(
        'GROUP_INVITATIONS acceptInvitation aborted: invitationId/groupId empty',
      );
      return false;
    }

    final invitationRef = _invitations.doc(invitationId);

    try {
      final invitationSnap = await invitationRef.get();

      if (!invitationSnap.exists || invitationSnap.data() == null) {
        debugPrint(
          'GROUP_INVITATIONS acceptInvitation failed: invitation not found',
        );
        return false;
      }

      final invitationData = invitationSnap.data()!;
      final toUserId = (invitationData['toUserId'] ?? '').toString().trim();
      final status = (invitationData['status'] ?? '').toString().trim();

      if (toUserId != userId) {
        debugPrint(
          'GROUP_INVITATIONS acceptInvitation failed: invitation target mismatch',
        );
        return false;
      }

      if (status == GroupInvitation.statusRefused ||
          status == GroupInvitation.statusCancelled) {
        debugPrint(
          'GROUP_INVITATIONS acceptInvitation failed: invitation already closed',
        );
        return false;
      }

      final alreadyMember =
          await _groupsRepository.isUserMember(groupId, userId);

      if (status == GroupInvitation.statusAccepted && alreadyMember) {
        debugPrint(
          'GROUP_INVITATIONS acceptInvitation already accepted and member already present',
        );
        return true;
      }

      if (!alreadyMember) {
        final addSuccess = await _groupsRepository.addMember(
          groupId: groupId,
          userId: userId,
        );

        if (!addSuccess) {
          debugPrint(
            'GROUP_INVITATIONS acceptInvitation failed: addMember returned false',
          );
          return false;
        }
      }

      await invitationRef.update({
        'status': GroupInvitation.statusAccepted,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e, stackTrace) {
      debugPrint('GROUP_INVITATIONS acceptInvitation error: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<bool> declineInvitation(GroupInvitation invitation) async {
    final userId = currentUserId;

    if (userId == null) {
      debugPrint(
        'GROUP_INVITATIONS declineInvitation aborted: currentUserId is null',
      );
      return false;
    }

    final invitationId = invitation.id.trim();

    if (invitationId.isEmpty) {
      debugPrint(
        'GROUP_INVITATIONS declineInvitation aborted: invitationId empty',
      );
      return false;
    }

    final invitationRef = _invitations.doc(invitationId);

    try {
      return await _db.runTransaction((transaction) async {
        final invitationSnap = await transaction.get(invitationRef);

        if (!invitationSnap.exists || invitationSnap.data() == null) {
          debugPrint(
            'GROUP_INVITATIONS declineInvitation failed: invitation not found',
          );
          return false;
        }

        final invitationData = invitationSnap.data()!;
        final toUserId = (invitationData['toUserId'] ?? '').toString().trim();
        final status = (invitationData['status'] ?? '').toString().trim();

        if (toUserId != userId) {
          debugPrint(
            'GROUP_INVITATIONS declineInvitation failed: invitation target mismatch',
          );
          return false;
        }

        if (status != GroupInvitation.statusPending) {
          debugPrint(
            'GROUP_INVITATIONS declineInvitation failed: invitation not pending',
          );
          return false;
        }

        transaction.update(invitationRef, {
          'status': GroupInvitation.statusRefused,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e, stackTrace) {
      debugPrint('GROUP_INVITATIONS declineInvitation error: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<bool> cancelInvitation(GroupInvitation invitation) async {
    final userId = currentUserId;

    if (userId == null) {
      debugPrint(
        'GROUP_INVITATIONS cancelInvitation aborted: currentUserId is null',
      );
      return false;
    }

    final invitationId = invitation.id.trim();

    if (invitationId.isEmpty) {
      debugPrint(
        'GROUP_INVITATIONS cancelInvitation aborted: invitationId empty',
      );
      return false;
    }

    final invitationRef = _invitations.doc(invitationId);

    try {
      return await _db.runTransaction((transaction) async {
        final invitationSnap = await transaction.get(invitationRef);

        if (!invitationSnap.exists || invitationSnap.data() == null) {
          debugPrint(
            'GROUP_INVITATIONS cancelInvitation failed: invitation not found',
          );
          return false;
        }

        final invitationData = invitationSnap.data()!;
        final fromUserId =
            (invitationData['fromUserId'] ?? '').toString().trim();
        final status = (invitationData['status'] ?? '').toString().trim();

        if (fromUserId != userId) {
          debugPrint(
            'GROUP_INVITATIONS cancelInvitation failed: invitation sender mismatch',
          );
          return false;
        }

        if (status != GroupInvitation.statusPending) {
          debugPrint(
            'GROUP_INVITATIONS cancelInvitation failed: invitation not pending',
          );
          return false;
        }

        transaction.update(invitationRef, {
          'status': GroupInvitation.statusCancelled,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e, stackTrace) {
      debugPrint('GROUP_INVITATIONS cancelInvitation error: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Stream<List<GroupInvitation>> _streamInvitationsForQuery(
    Query<Map<String, dynamic>> query, {
    required String debugLabel,
  }) {
    return query.snapshots().map((snapshot) {
      debugPrint(
        'GROUP_INVITATIONS [$debugLabel] firestore docs count=${snapshot.docs.length}',
      );

      final List<GroupInvitation> invitations = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('GROUP_INVITATIONS [$debugLabel] docId=${doc.id}');
        debugPrint('GROUP_INVITATIONS [$debugLabel] rawData=$data');

        try {
          final invitation = GroupInvitation.fromFirestore(data, doc.id);
          invitations.add(invitation);

          debugPrint(
            'GROUP_INVITATIONS [$debugLabel] parsed -> '
            'id=${invitation.id}, '
            'groupId=${invitation.groupId}, '
            'toUserId=${invitation.toUserId}, '
            'fromUserId=${invitation.fromUserId}, '
            'status=${invitation.status}, '
            'groupName=${invitation.groupName}',
          );
        } catch (e, stackTrace) {
          debugPrint(
            'GROUP_INVITATIONS [$debugLabel] parse error for doc ${doc.id}: $e',
          );
          debugPrint(stackTrace.toString());
        }
      }

      invitations.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      debugPrint(
        'GROUP_INVITATIONS [$debugLabel] parsed invitations count=${invitations.length}',
      );

      return invitations;
    });
  }
}