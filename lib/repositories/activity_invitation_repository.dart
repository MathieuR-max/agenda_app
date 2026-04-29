import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/core/utils/parsers.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/chat_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class ActivityInvitationRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final UserFirestoreService _userService;
  final ChatFirestoreService _chatService;
  final ActivityFirestoreService _activityService;

  ActivityInvitationRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    UserFirestoreService? userService,
    ChatFirestoreService? chatService,
    ActivityFirestoreService? activityService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _userService = userService ??
            UserFirestoreService(
              db: db,
              auth: auth,
            ),
        _chatService = chatService ??
            ChatFirestoreService(
              db: db,
              auth: auth,
            ),
        _activityService = activityService ??
            ActivityFirestoreService(
              db: db,
              auth: auth,
            );

  String? get currentUserIdOrNull {
    final uid = _auth.currentUser?.uid.trim();

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

  CollectionReference<Map<String, dynamic>> get _activitiesRef =>
      _db.collection(FirestoreCollections.activities);

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _activityInvitationsRef =>
      _db.collection(FirestoreCollections.activityInvitations);

  CollectionReference<Map<String, dynamic>> _participantsRef(
    String activityId,
  ) {
    return _activitiesRef
        .doc(activityId.trim())
        .collection(FirestoreCollections.participants);
  }

  Future<bool> isUserAlreadyParticipant({
    required String activityId,
    required String userId,
  }) async {
    final trimmedActivityId = activityId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedActivityId.isEmpty || trimmedUserId.isEmpty) {
      return false;
    }

    final participantDoc =
        await _participantsRef(trimmedActivityId).doc(trimmedUserId).get();

    return participantDoc.exists;
  }

  Future<bool> hasPendingInvitation({
    required String activityId,
    required String toUserId,
  }) async {
    final uid = currentUserIdOrNull;
    final trimmedActivityId = activityId.trim();
    final trimmedToUserId = toUserId.trim();

    if (uid == null || trimmedActivityId.isEmpty || trimmedToUserId.isEmpty) {
      return false;
    }

    final query = await _activityInvitationsRef
        .where('fromUserId', isEqualTo: uid)
        .where('activityId', isEqualTo: trimmedActivityId)
        .where('toUserId', isEqualTo: trimmedToUserId)
        .where('status', isEqualTo: InvitationStatusValues.pending)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<Set<String>> getPendingInvitationTargetIds(String activityId) async {
    final uid = currentUserIdOrNull;
    final trimmedActivityId = activityId.trim();

    if (uid == null || trimmedActivityId.isEmpty) {
      return <String>{};
    }

    final snapshot = await _activityInvitationsRef
        .where('fromUserId', isEqualTo: uid)
        .where('activityId', isEqualTo: trimmedActivityId)
        .where('status', isEqualTo: InvitationStatusValues.pending)
        .get();

    return snapshot.docs
        .map((doc) => (doc.data()['toUserId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Stream<Set<String>> watchPendingInvitationTargetIds(String activityId) {
    final uid = currentUserIdOrNull;
    final trimmedActivityId = activityId.trim();

    if (uid == null || trimmedActivityId.isEmpty) {
      return Stream.value(<String>{});
    }

    return _activityInvitationsRef
        .where('fromUserId', isEqualTo: uid)
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
    final uid = currentUserIdOrNull;
    final trimmedActivityId = activity.id.trim();
    final trimmedToUserId = toUserId.trim();

    if (uid == null || trimmedActivityId.isEmpty || trimmedToUserId.isEmpty) {
      return false;
    }

    if (trimmedToUserId == uid) {
      return false;
    }

    final alreadyParticipant = await isUserAlreadyParticipant(
      activityId: trimmedActivityId,
      userId: trimmedToUserId,
    );

    if (alreadyParticipant) {
      return false;
    }

    final alreadyInvited = await hasPendingInvitation(
      activityId: trimmedActivityId,
      toUserId: trimmedToUserId,
    );

    if (alreadyInvited) {
      return false;
    }

    final activityRef = _activitiesRef.doc(trimmedActivityId);
    final toUserRef = _usersRef.doc(trimmedToUserId);
    final participantRef =
        _participantsRef(trimmedActivityId).doc(trimmedToUserId);
    final fromUserPseudo = await _userService.getCurrentUserPseudo();

    return _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);
      final toUserDoc = await transaction.get(toUserRef);
      final participantDoc = await transaction.get(participantRef);

      if (!activityDoc.exists || !toUserDoc.exists) {
        return false;
      }

      if (participantDoc.exists) {
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

      final toUserPseudo = (toUserData['pseudo'] ?? '').toString().trim();
      final newInvitationRef = _activityInvitationsRef.doc();

      transaction.set(newInvitationRef, {
        'activityId': currentActivity.id,
        'activityTitle': currentActivity.title,
        'activityDay': currentActivity.effectiveDay,
        'activityStartTime': currentActivity.effectiveStartTime,
        'activityLocation': currentActivity.location,
        'fromUserId': uid,
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
    final uid = currentUserIdOrNull;
    final trimmedInvitationId = invitation.id.trim();
    final trimmedActivityId = invitation.activityId.trim();

    if (uid == null ||
        trimmedInvitationId.isEmpty ||
        trimmedActivityId.isEmpty) {
      return false;
    }

    final invitationRef = _activityInvitationsRef.doc(trimmedInvitationId);
    final activityRef = _activitiesRef.doc(trimmedActivityId);
    final participantRef = _participantsRef(trimmedActivityId).doc(uid);

    final currentUserPseudo = await _userService.getCurrentUserPseudo();

    final success = await _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);
      final activityDoc = await transaction.get(activityRef);
      final participantDoc = await transaction.get(participantRef);

      if (!invitationDoc.exists || !activityDoc.exists) {
        return false;
      }

      final invitationData = invitationDoc.data();
      final activityData = activityDoc.data();

      if (invitationData == null || activityData == null) {
        return false;
      }

      final invitationStatus =
          (invitationData['status'] ?? InvitationStatusValues.pending)
              .toString()
              .trim();

      if (invitationStatus != InvitationStatusValues.pending) {
        return false;
      }

      final invitationToUserId =
          (invitationData['toUserId'] ?? '').toString().trim();

      if (invitationToUserId.isNotEmpty && invitationToUserId != uid) {
        return false;
      }

      if (participantDoc.exists) {
        transaction.update(invitationRef, {
          'status': InvitationStatusValues.accepted,
          'respondedAt': FieldValue.serverTimestamp(),
        });
        return true;
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
        'userId': uid,
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
      await _activityService.addJoinedActivityMirror(
        userId: uid,
        activityId: trimmedActivityId,
        source: 'invitation',
      );
    }

    return success;
  }

  Future<bool> refuseInvitation(String invitationId) async {
    final uid = currentUserIdOrNull;
    final trimmedInvitationId = invitationId.trim();

    if (uid == null || trimmedInvitationId.isEmpty) {
      return false;
    }

    final invitationRef = _activityInvitationsRef.doc(trimmedInvitationId);

    return _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);

      if (!invitationDoc.exists || invitationDoc.data() == null) {
        return false;
      }

      final data = invitationDoc.data()!;
      final status =
          (data['status'] ?? InvitationStatusValues.pending).toString().trim();
      final toUserId = (data['toUserId'] ?? '').toString().trim();

      if (status != InvitationStatusValues.pending) {
        return false;
      }

      if (toUserId.isNotEmpty && toUserId != uid) {
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
    final uid = currentUserIdOrNull;
    final trimmedInvitationId = invitationId.trim();

    if (uid == null || trimmedInvitationId.isEmpty) {
      return false;
    }

    final invitationRef = _activityInvitationsRef.doc(trimmedInvitationId);

    return _db.runTransaction((transaction) async {
      final invitationDoc = await transaction.get(invitationRef);

      if (!invitationDoc.exists || invitationDoc.data() == null) {
        return false;
      }

      final data = invitationDoc.data()!;
      final status =
          (data['status'] ?? InvitationStatusValues.pending).toString().trim();
      final fromUserId = (data['fromUserId'] ?? '').toString().trim();

      if (status != InvitationStatusValues.pending) {
        return false;
      }

      if (fromUserId.isNotEmpty && fromUserId != uid) {
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