import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/services/current_user.dart';

class ActivityInvitationFirestoreService {
  final FirebaseFirestore _db;

  ActivityInvitationFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String? get currentUserId {
    final value = CurrentUser.idOrNull?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _db.collection(FirestoreCollections.activityInvitations);

  Stream<List<ActivityInvitation>> getReceivedInvitations() {
    final userId = currentUserId;
    debugPrint('INVITATIONS getReceivedInvitations currentUserId=$userId');

    if (userId == null) {
      return Stream.value(<ActivityInvitation>[]);
    }

    return _streamInvitationsForQuery(
      _invitations
          .where('toUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true),
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
          .where('status', isEqualTo: ActivityInvitation.statusPending)
          .orderBy('createdAt', descending: true),
      debugLabel: 'pending_received',
    );
  }

  Stream<List<ActivityInvitation>> getSentInvitationsForActivity(
    String activityId,
  ) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      debugPrint(
        'INVITATIONS getSentInvitationsForActivity activityId=<vide>',
      );
      return Stream.value(<ActivityInvitation>[]);
    }

    debugPrint(
      'INVITATIONS getSentInvitationsForActivity activityId=$trimmedActivityId',
    );

    return _streamInvitationsForQuery(
      _invitations
          .where('activityId', isEqualTo: trimmedActivityId)
          .orderBy('createdAt', descending: true),
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
      _invitations
          .where('fromUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true),
      debugLabel: 'sent',
    );
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