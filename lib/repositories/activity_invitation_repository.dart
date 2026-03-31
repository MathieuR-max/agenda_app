import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/core/utils/parsers.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/chat_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class ActivityInvitationRepository {
  final FirebaseFirestore _db;
  final UserFirestoreService _userService;
  final ChatFirestoreService _chatService;

  ActivityInvitationRepository({
    FirebaseFirestore? db,
    UserFirestoreService? userService,
    ChatFirestoreService? chatService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _userService = userService ?? UserFirestoreService(db: db),
        _chatService = chatService ?? ChatFirestoreService(db: db);

  String get currentUserId => CurrentUser.id;

  Future<bool> sendActivityInvitation({
    required Activity activity,
    required String toUserId,
  }) async {
    final activityRef = _db
        .collection(FirestoreCollections.activities)
        .doc(activity.id);
    final toUserRef =
        _db.collection(FirestoreCollections.users).doc(toUserId);
    final invitationsRef =
        _db.collection(FirestoreCollections.activityInvitations);

    final fromUserPseudo = await _userService.getCurrentUserPseudo();

    return await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);
      final toUserDoc = await transaction.get(toUserRef);

      if (!activityDoc.exists || !toUserDoc.exists || toUserId == currentUserId) {
        return false;
      }

      final activityData = activityDoc.data();
      if (activityData == null) {
        return false;
      }

      final status =
          (activityData['status'] ?? ActivityStatusValues.open).toString();

      if (status == ActivityStatusValues.cancelled ||
          status == ActivityStatusValues.done) {
        return false;
      }

      final participantDoc = await _db
          .collection(FirestoreCollections.activities)
          .doc(activity.id)
          .collection(FirestoreCollections.participants)
          .doc(toUserId)
          .get();

      if (participantDoc.exists) {
        return false;
      }

      final existingInviteQuery = await _db
          .collection(FirestoreCollections.activityInvitations)
          .where('activityId', isEqualTo: activity.id)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: InvitationStatusValues.pending)
          .limit(1)
          .get();

      if (existingInviteQuery.docs.isNotEmpty) {
        return false;
      }

      final toUserPseudo = (toUserDoc.data()?['pseudo'] ?? '').toString();

      final newInvitationRef = invitationsRef.doc();

      transaction.set(newInvitationRef, {
        'activityId': activity.id,
        'activityTitle': activity.title,
        'activityDay': activity.day,
        'activityStartTime': activity.startTime,
        'activityLocation': activity.location,
        'fromUserId': currentUserId,
        'fromUserPseudo': fromUserPseudo,
        'toUserId': toUserId,
        'toUserPseudo': toUserPseudo,
        'status': InvitationStatusValues.pending,
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      return true;
    });
  }

  Future<bool> acceptInvitation(ActivityInvitation invitation) async {
    final invitationRef = _db
        .collection(FirestoreCollections.activityInvitations)
        .doc(invitation.id);
    final activityRef = _db
        .collection(FirestoreCollections.activities)
        .doc(invitation.activityId);
    final participantRef = activityRef
        .collection(FirestoreCollections.participants)
        .doc(currentUserId);

    final currentUserPseudo = await _userService.getCurrentUserPseudo();

    final success = await _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);
      final activityDoc = await transaction.get(activityRef);
      final participantDoc = await transaction.get(participantRef);

      if (!invitationDoc.exists || !activityDoc.exists) {
        return false;
      }

      if (participantDoc.exists) {
        transaction.update(invitationRef, {
          'status': InvitationStatusValues.accepted,
          'respondedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      final invitationData = invitationDoc.data();
      final activityData = activityDoc.data();

      if (invitationData == null || activityData == null) {
        return false;
      }

      final invitationStatus =
          (invitationData['status'] ?? InvitationStatusValues.pending)
              .toString();

      if (invitationStatus != InvitationStatusValues.pending) {
        return false;
      }

      final activityStatus =
          (activityData['status'] ?? ActivityStatusValues.open).toString();

      if (activityStatus == ActivityStatusValues.cancelled ||
          activityStatus == ActivityStatusValues.done ||
          activityStatus == ActivityStatusValues.full) {
        return false;
      }

      final participantCount = parseInt(activityData['participantCount']);
      final maxParticipants = parseInt(activityData['maxParticipants']);

      if (maxParticipants > 0 && participantCount >= maxParticipants) {
        return false;
      }

      final newParticipantCount = participantCount + 1;
      final newStatus = _computeActivityStatus(
        participantCount: newParticipantCount,
        maxParticipants: maxParticipants,
        currentStatus: activityStatus,
      );

      transaction.set(participantRef, {
        'userId': currentUserId,
        'pseudo': currentUserPseudo,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(activityRef, {
        'participantCount': newParticipantCount,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(invitationRef, {
        'status': InvitationStatusValues.accepted,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });

    if (success) {
      await _chatService.addSystemMessage(
        activityId: invitation.activityId,
        text: '$currentUserPseudo a rejoint l’activité via invitation',
      );
    }

    return success;
  }

  Future<bool> refuseInvitation(String invitationId) async {
    final invitationRef = _db
        .collection(FirestoreCollections.activityInvitations)
        .doc(invitationId);

    return await _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);

      if (!invitationDoc.exists || invitationDoc.data() == null) {
        return false;
      }

      final data = invitationDoc.data()!;
      final status =
          (data['status'] ?? InvitationStatusValues.pending).toString();

      if (status != InvitationStatusValues.pending) {
        return false;
      }

      transaction.update(invitationRef, {
        'status': InvitationStatusValues.refused,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<bool> cancelInvitation(String invitationId) async {
    final invitationRef = _db
        .collection(FirestoreCollections.activityInvitations)
        .doc(invitationId);

    return await _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);

      if (!invitationDoc.exists || invitationDoc.data() == null) {
        return false;
      }

      final data = invitationDoc.data()!;
      final status =
          (data['status'] ?? InvitationStatusValues.pending).toString();

      if (status != InvitationStatusValues.pending) {
        return false;
      }

      transaction.update(invitationRef, {
        'status': InvitationStatusValues.cancelled,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  String _computeActivityStatus({
    required int participantCount,
    required int maxParticipants,
    required String currentStatus,
  }) {
    if (currentStatus == ActivityStatusValues.cancelled ||
        currentStatus == ActivityStatusValues.done) {
      return currentStatus;
    }

    if (maxParticipants > 0 && participantCount >= maxParticipants) {
      return ActivityStatusValues.full;
    }

    return ActivityStatusValues.open;
  }
}