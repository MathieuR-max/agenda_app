import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/core/utils/parsers.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/activity_invitation.dart';
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

  CollectionReference<Map<String, dynamic>> get _activitiesRef =>
      _db.collection(FirestoreCollections.activities);

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _activityInvitationsRef =>
      _db.collection(FirestoreCollections.activityInvitations);

  Future<bool> isUserAlreadyParticipant({
    required String activityId,
    required String userId,
  }) async {
    final trimmedActivityId = activityId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedActivityId.isEmpty || trimmedUserId.isEmpty) {
      return false;
    }

    final participantDoc = await _activitiesRef
        .doc(trimmedActivityId)
        .collection(FirestoreCollections.participants)
        .doc(trimmedUserId)
        .get();

    return participantDoc.exists;
  }

  Future<bool> hasPendingInvitation({
    required String activityId,
    required String toUserId,
  }) async {
    final trimmedActivityId = activityId.trim();
    final trimmedToUserId = toUserId.trim();

    if (trimmedActivityId.isEmpty || trimmedToUserId.isEmpty) {
      return false;
    }

    final query = await _activityInvitationsRef
        .where('activityId', isEqualTo: trimmedActivityId)
        .where('toUserId', isEqualTo: trimmedToUserId)
        .where('status', isEqualTo: InvitationStatusValues.pending)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<Set<String>> getPendingInvitationTargetIds(String activityId) async {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return <String>{};
    }

    final snapshot = await _activityInvitationsRef
        .where('activityId', isEqualTo: trimmedActivityId)
        .where('status', isEqualTo: InvitationStatusValues.pending)
        .get();

    return snapshot.docs
        .map((doc) => (doc.data()['toUserId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Stream<Set<String>> watchPendingInvitationTargetIds(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(<String>{});
    }

    return _activityInvitationsRef
        .where('activityId', isEqualTo: trimmedActivityId)
        .where('status', isEqualTo: InvitationStatusValues.pending)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => (doc.data()['toUserId'] ?? '').toString().trim())
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
  }

  Future<bool> sendActivityInvitation({
    required Activity activity,
    required String toUserId,
  }) async {
    final trimmedActivityId = activity.id.trim();
    final trimmedToUserId = toUserId.trim();

    if (trimmedActivityId.isEmpty || trimmedToUserId.isEmpty) {
      return false;
    }

    if (trimmedToUserId == currentUserId) {
      return false;
    }

    final activityRef = _activitiesRef.doc(trimmedActivityId);
    final toUserRef = _usersRef.doc(trimmedToUserId);
    final fromUserPseudo = await _userService.getCurrentUserPseudo();

    return await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);
      final toUserDoc = await transaction.get(toUserRef);

      if (!activityDoc.exists || !toUserDoc.exists) {
        return false;
      }

      final activityData = activityDoc.data();
      final toUserData = toUserDoc.data();

      if (activityData == null || toUserData == null) {
        return false;
      }

      final currentActivity = Activity.fromMap(activityDoc.id, activityData);
      final status = currentActivity.status;

      if (status == ActivityStatusValues.cancelled ||
          status == ActivityStatusValues.done ||
          currentActivity.hasEnded) {
        return false;
      }

      final participantRef = activityRef
          .collection(FirestoreCollections.participants)
          .doc(trimmedToUserId);

      final participantDoc = await transaction.get(participantRef);

      if (participantDoc.exists) {
        return false;
      }

      final existingInviteQuery = await _activityInvitationsRef
          .where('activityId', isEqualTo: currentActivity.id)
          .where('toUserId', isEqualTo: trimmedToUserId)
          .where('status', isEqualTo: InvitationStatusValues.pending)
          .limit(1)
          .get();

      if (existingInviteQuery.docs.isNotEmpty) {
        return false;
      }

      final toUserPseudo = (toUserData['pseudo'] ?? '').toString().trim();

      final newInvitationRef = _activityInvitationsRef.doc();

      transaction.set(newInvitationRef, {
        'activityId': currentActivity.id,
        'activityTitle': currentActivity.title,
        'activityDay': currentActivity.effectiveDay,
        'activityStartTime': currentActivity.effectiveStartTime,
        'activityLocation': currentActivity.location,
        'fromUserId': currentUserId,
        'fromUserPseudo': fromUserPseudo,
        'toUserId': trimmedToUserId,
        'toUserPseudo': toUserPseudo,
        'status': InvitationStatusValues.pending,
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      return true;
    });
  }

  Future<bool> acceptInvitation(ActivityInvitation invitation) async {
    final invitationRef =
        _activityInvitationsRef.doc(invitation.id.trim());
    final activityRef = _activitiesRef.doc(invitation.activityId.trim());
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

      final currentActivity = Activity.fromMap(activityDoc.id, activityData);
      final activityStatus = currentActivity.status;

      if (activityStatus == ActivityStatusValues.cancelled ||
          activityStatus == ActivityStatusValues.done ||
          activityStatus == ActivityStatusValues.full ||
          currentActivity.hasEnded) {
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
    final invitationRef = _activityInvitationsRef.doc(invitationId.trim());

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
    final invitationRef = _activityInvitationsRef.doc(invitationId.trim());

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