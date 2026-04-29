import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';

class ActivityInvitationFirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ActivityFirestoreService _activityService;

  ActivityInvitationFirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    ActivityFirestoreService? activityService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _activityService = activityService ??
            ActivityFirestoreService(
              db: db,
              auth: auth,
            );

  String? get currentUserId {
    final uid = _auth.currentUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _db.collection(FirestoreCollections.activityInvitations);

  CollectionReference<Map<String, dynamic>> get _activities =>
      _db.collection(FirestoreCollections.activities);

  DocumentReference<Map<String, dynamic>> _activityDoc(String activityId) =>
      _activities.doc(activityId.trim());

  CollectionReference<Map<String, dynamic>> _participantsRef(
    String activityId,
  ) =>
      _activityDoc(activityId).collection(FirestoreCollections.participants);

  Stream<List<ActivityInvitation>> getReceivedInvitations() {
    final userId = currentUserId;
    debugPrint('INVITATIONS getReceivedInvitations currentUserId=$userId');

    if (userId == null) {
      return Stream.value(<ActivityInvitation>[]);
    }

    return _streamInvitationsForQuery(
      _invitations.where('toUserId', isEqualTo: userId),
      debugLabel: 'received',
    );
  }

  Stream<List<ActivityInvitation>> getPendingReceivedInvitations() {
    final userId = currentUserId;
    debugPrint(
      'INVITATIONS getPendingReceivedInvitations currentUserId=$userId',
    );

    if (userId == null) {
      return Stream.value(<ActivityInvitation>[]);
    }

    return _streamInvitationsForQuery(
      _invitations
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: ActivityInvitation.statusPending),
      debugLabel: 'pending_received',
    );
  }

  Stream<List<ActivityInvitation>> getSentInvitationsForActivity(
    String activityId,
  ) {
    final userId = currentUserId;
    final trimmedActivityId = activityId.trim();

    if (userId == null || trimmedActivityId.isEmpty) {
      debugPrint(
        'INVITATIONS getSentInvitationsForActivity activityId=<vide> or currentUserId=<null>',
      );
      return Stream.value(<ActivityInvitation>[]);
    }

    debugPrint(
      'INVITATIONS getSentInvitationsForActivity activityId=$trimmedActivityId currentUserId=$userId',
    );

    return _streamInvitationsForQuery(
      _invitations
          .where('fromUserId', isEqualTo: userId)
          .where('activityId', isEqualTo: trimmedActivityId),
      debugLabel: 'sent_for_activity',
    );
  }

  Stream<List<ActivityInvitation>> getSentInvitations() {
    final userId = currentUserId;
    debugPrint('INVITATIONS getSentInvitations currentUserId=$userId');

    if (userId == null) {
      return Stream.value(<ActivityInvitation>[]);
    }

    return _streamInvitationsForQuery(
      _invitations.where('fromUserId', isEqualTo: userId),
      debugLabel: 'sent',
    );
  }

  Future<bool> acceptInvitation(ActivityInvitation invitation) async {
    final userId = currentUserId;

    if (userId == null) {
      debugPrint('INVITATIONS acceptInvitation aborted: currentUserId is null');
      return false;
    }

    final invitationId = invitation.id.trim();
    final activityId = invitation.activityId.trim();

    if (invitationId.isEmpty || activityId.isEmpty) {
      debugPrint(
        'INVITATIONS acceptInvitation aborted: invitationId/activityId empty',
      );
      return false;
    }

    final invitationRef = _invitations.doc(invitationId);
    final activityRef = _activityDoc(activityId);
    final participantRef = _participantsRef(activityId).doc(userId);

    try {
      final success = await _db.runTransaction((transaction) async {
        final invitationSnap = await transaction.get(invitationRef);
        final participantSnap = await transaction.get(participantRef);

        if (!invitationSnap.exists || invitationSnap.data() == null) {
          debugPrint(
            'INVITATIONS acceptInvitation failed: invitation not found',
          );
          return false;
        }

        final invitationData = invitationSnap.data()!;

        final toUserId = (invitationData['toUserId'] ?? '').toString().trim();
        final status = (invitationData['status'] ?? '').toString().trim();

        if (toUserId != userId) {
          debugPrint(
            'INVITATIONS acceptInvitation failed: invitation target mismatch',
          );
          return false;
        }

        if (status == ActivityInvitation.statusRefused ||
            status == ActivityInvitation.statusCancelled) {
          debugPrint(
            'INVITATIONS acceptInvitation failed: invitation already closed',
          );
          return false;
        }

        if (status == ActivityInvitation.statusAccepted &&
            participantSnap.exists) {
          debugPrint(
            'INVITATIONS acceptInvitation already accepted and participant exists',
          );
          return true;
        }

        final alreadyParticipant = participantSnap.exists;

        if (!alreadyParticipant) {
          final pseudo = invitation.toUserPseudo.trim().isNotEmpty
              ? invitation.toUserPseudo.trim()
              : userId;

          transaction.set(participantRef, {
            'userId': userId,
            'pseudo': pseudo,
            'joinedAt': FieldValue.serverTimestamp(),
          });

          transaction.update(activityRef, {
            'participantCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(activityRef, {
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(invitationRef, {
          'status': ActivityInvitation.statusAccepted,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });

      if (success) {
        await _activityService.addJoinedActivityMirror(
          userId: userId,
          activityId: activityId,
          source: 'invitation',
        );
      }

      return success;
    } catch (e, stackTrace) {
      debugPrint('INVITATIONS acceptInvitation error: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Future<bool> declineInvitation(ActivityInvitation invitation) async {
    final userId = currentUserId;

    if (userId == null) {
      debugPrint('INVITATIONS declineInvitation aborted: currentUserId is null');
      return false;
    }

    final invitationId = invitation.id.trim();

    if (invitationId.isEmpty) {
      debugPrint('INVITATIONS declineInvitation aborted: invitationId empty');
      return false;
    }

    final invitationRef = _invitations.doc(invitationId);

    try {
      return await _db.runTransaction((transaction) async {
        final invitationSnap = await transaction.get(invitationRef);

        if (!invitationSnap.exists || invitationSnap.data() == null) {
          debugPrint(
            'INVITATIONS declineInvitation failed: invitation not found',
          );
          return false;
        }

        final invitationData = invitationSnap.data()!;
        final toUserId = (invitationData['toUserId'] ?? '').toString().trim();
        final status = (invitationData['status'] ?? '').toString().trim();

        if (toUserId != userId) {
          debugPrint(
            'INVITATIONS declineInvitation failed: invitation target mismatch',
          );
          return false;
        }

        if (status != ActivityInvitation.statusPending) {
          debugPrint(
            'INVITATIONS declineInvitation failed: invitation not pending',
          );
          return false;
        }

        transaction.update(invitationRef, {
          'status': ActivityInvitation.statusRefused,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e, stackTrace) {
      debugPrint('INVITATIONS declineInvitation error: $e');
      debugPrint(stackTrace.toString());
      return false;
    }
  }

  Stream<List<ActivityInvitation>> _streamInvitationsForQuery(
    Query<Map<String, dynamic>> query, {
    required String debugLabel,
  }) {
    return query.snapshots().map((snapshot) {
      debugPrint(
        'INVITATIONS [$debugLabel] firestore docs count=${snapshot.docs.length}',
      );

      final List<ActivityInvitation> invitations = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('INVITATIONS [$debugLabel] docId=${doc.id}');
        debugPrint('INVITATIONS [$debugLabel] rawData=$data');

        try {
          final invitation = ActivityInvitation.fromFirestore(data, doc.id);
          invitations.add(invitation);

          debugPrint(
            'INVITATIONS [$debugLabel] parsed -> '
            'id=${invitation.id}, '
            'activityId=${invitation.activityId}, '
            'toUserId=${invitation.toUserId}, '
            'fromUserId=${invitation.fromUserId}, '
            'status=${invitation.status}, '
            'title=${invitation.activityTitle}',
          );
        } catch (e, stackTrace) {
          debugPrint(
            'INVITATIONS [$debugLabel] parse error for doc ${doc.id}: $e',
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
        'INVITATIONS [$debugLabel] parsed invitations count=${invitations.length}',
      );

      return invitations;
    });
  }
}