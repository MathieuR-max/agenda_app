import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/core/utils/parsers.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/chat_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class ActivityRepository {
  final FirebaseFirestore _db;
  final ActivityFirestoreService _activityService;
  final ChatFirestoreService _chatService;
  final UserFirestoreService _userService;

  ActivityRepository({
    FirebaseFirestore? db,
    ActivityFirestoreService? activityService,
    ChatFirestoreService? chatService,
    UserFirestoreService? userService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _activityService =
            activityService ?? ActivityFirestoreService(db: db),
        _chatService = chatService ?? ChatFirestoreService(db: db),
        _userService = userService ?? UserFirestoreService(db: db);

  String get currentUserId => CurrentUser.id;

  String computeActivityStatus({
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

  Future<void> createActivity({
    required String title,
    required String description,
    required String category,
    required String day,
    required String startTime,
    required String endTime,
    required String location,
    required String maxParticipants,
    required String level,
    required String groupType,
    String visibility = ActivityVisibilityValues.public,
  }) async {
    final ownerPseudo = await _userService.getCurrentUserPseudo();
    final maxParticipantsInt = parseInt(maxParticipants);

    final initialStatus = computeActivityStatus(
      participantCount: 1,
      maxParticipants: maxParticipantsInt,
      currentStatus: ActivityStatusValues.open,
    );

    final activityId = await _activityService.createActivityDocument(
      title: title,
      description: description,
      category: category,
      day: day,
      startTime: startTime,
      endTime: endTime,
      location: location,
      maxParticipants: maxParticipantsInt,
      level: level,
      groupType: groupType,
      visibility: visibility,
      ownerId: currentUserId,
      ownerPseudo: ownerPseudo,
      initialStatus: initialStatus,
    );

    await _activityService.addParticipant(
      activityId: activityId,
      userId: currentUserId,
      pseudo: ownerPseudo,
    );

    await _chatService.addSystemMessage(
      activityId: activityId,
      text: 'Activité créée par $ownerPseudo',
    );
  }

  Future<bool> joinActivity(Activity activity) async {
    final activityId = activity.id;
    final activityRef = _db
        .collection(FirestoreCollections.activities)
        .doc(activityId);
    final participantRef = activityRef
        .collection(FirestoreCollections.participants)
        .doc(currentUserId);
    final userRef =
        _db.collection(FirestoreCollections.users).doc(currentUserId);

    String joinedPseudo = '';

    final success = await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);
      final participantDoc = await transaction.get(participantRef);
      final userDoc = await transaction.get(userRef);

      if (!activityDoc.exists || participantDoc.exists) {
        return false;
      }

      final activityData = activityDoc.data();
      if (activityData == null) {
        return false;
      }

      final String status =
          (activityData['status'] ?? ActivityStatusValues.open).toString();
      final String visibility =
          (activityData['visibility'] ?? ActivityVisibilityValues.public)
              .toString();
      final int participantCount = parseInt(activityData['participantCount']);
      final int maxParticipants = parseInt(activityData['maxParticipants']);

      if (status == ActivityStatusValues.cancelled ||
          status == ActivityStatusValues.done ||
          status == ActivityStatusValues.full) {
        return false;
      }

      if (visibility == ActivityVisibilityValues.inviteOnly) {
        return false;
      }

      if (maxParticipants > 0 && participantCount >= maxParticipants) {
        return false;
      }

      if (userDoc.exists && userDoc.data() != null) {
        joinedPseudo = (userDoc.data()!['pseudo'] ?? '').toString();
      }

      final int newParticipantCount = participantCount + 1;
      final String newStatus = computeActivityStatus(
        participantCount: newParticipantCount,
        maxParticipants: maxParticipants,
        currentStatus: status,
      );

      transaction.set(participantRef, {
        'userId': currentUserId,
        'pseudo': joinedPseudo,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(activityRef, {
        'participantCount': newParticipantCount,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });

    if (success) {
      await _chatService.addSystemMessage(
        activityId: activityId,
        text: '$joinedPseudo a rejoint l’activité',
      );
    }

    return success;
  }

  Future<void> leaveActivity(String activityId) async {
    final activityRef = _db
        .collection(FirestoreCollections.activities)
        .doc(activityId);
    final participantRef = activityRef
        .collection(FirestoreCollections.participants)
        .doc(currentUserId);

    String leavingPseudo = '';

    await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);
      final participantDoc = await transaction.get(participantRef);

      if (!activityDoc.exists || !participantDoc.exists) {
        return;
      }

      final activityData = activityDoc.data();
      if (activityData == null) {
        return;
      }

      leavingPseudo = (participantDoc.data()?['pseudo'] ?? '').toString();

      final int participantCount = parseInt(activityData['participantCount']);
      final int maxParticipants = parseInt(activityData['maxParticipants']);
      final String currentStatus =
          (activityData['status'] ?? ActivityStatusValues.open).toString();

      final int newParticipantCount =
          participantCount > 0 ? participantCount - 1 : 0;

      final String newStatus = computeActivityStatus(
        participantCount: newParticipantCount,
        maxParticipants: maxParticipants,
        currentStatus: currentStatus,
      );

      transaction.delete(participantRef);

      transaction.update(activityRef, {
        'participantCount': newParticipantCount,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (leavingPseudo.isNotEmpty) {
      await _chatService.addSystemMessage(
        activityId: activityId,
        text: '$leavingPseudo a quitté l’activité',
      );
    }
  }

  Future<void> leaveActivityWithOwnerHandling(String activityId) async {
    final activityRef = _db
        .collection(FirestoreCollections.activities)
        .doc(activityId);
    final participantRef = activityRef
        .collection(FirestoreCollections.participants)
        .doc(currentUserId);

    String leavingPseudo = '';
    bool deletedActivity = false;
    bool ownerPendingSet = false;

    await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);
      final participantDoc = await transaction.get(participantRef);

      if (!activityDoc.exists || !participantDoc.exists) {
        return;
      }

      final data = activityDoc.data();
      if (data == null) {
        return;
      }

      leavingPseudo = (participantDoc.data()?['pseudo'] ?? '').toString();

      final String ownerId = (data['ownerId'] ?? '').toString();
      final int participantCount = parseInt(data['participantCount']);
      final int maxParticipants = parseInt(data['maxParticipants']);
      final String currentStatus =
          (data['status'] ?? ActivityStatusValues.open).toString();
      final bool isOwner = ownerId == currentUserId;

      if (!isOwner) {
        final int newParticipantCount =
            participantCount > 0 ? participantCount - 1 : 0;

        final String newStatus = computeActivityStatus(
          participantCount: newParticipantCount,
          maxParticipants: maxParticipants,
          currentStatus: currentStatus,
        );

        transaction.delete(participantRef);
        transaction.update(activityRef, {
          'participantCount': newParticipantCount,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      if (participantCount <= 1) {
        transaction.delete(participantRef);
        transaction.delete(activityRef);
        deletedActivity = true;
        return;
      }

      final int newParticipantCount = participantCount - 1;

      final String newStatus = computeActivityStatus(
        participantCount: newParticipantCount,
        maxParticipants: maxParticipants,
        currentStatus: currentStatus,
      );

      transaction.delete(participantRef);
      transaction.update(activityRef, {
        'participantCount': newParticipantCount,
        'ownerId': '',
        'ownerPseudo': '',
        'ownerPending': true,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ownerPendingSet = true;
    });

    if (deletedActivity) {
      return;
    }

    if (leavingPseudo.isNotEmpty) {
      await _chatService.addSystemMessage(
        activityId: activityId,
        text: '$leavingPseudo a quitté l’activité',
      );
    }

    if (ownerPendingSet) {
      await _chatService.addSystemMessage(
        activityId: activityId,
        text: 'L’activité attend un nouvel organisateur',
      );
    }
  }

  Future<bool> claimOwnership(String activityId) async {
    final activityRef = _db
        .collection(FirestoreCollections.activities)
        .doc(activityId);
    final participantRef = activityRef
        .collection(FirestoreCollections.participants)
        .doc(currentUserId);
    final userRef =
        _db.collection(FirestoreCollections.users).doc(currentUserId);

    String pseudo = '';

    final success = await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);
      final participantDoc = await transaction.get(participantRef);
      final userDoc = await transaction.get(userRef);

      if (!activityDoc.exists || !participantDoc.exists) {
        return false;
      }

      final activityData = activityDoc.data();
      if (activityData == null) {
        return false;
      }

      final bool ownerPending =
          (activityData['ownerPending'] ?? false) as bool;
      final String existingOwnerId =
          (activityData['ownerId'] ?? '').toString();

      if (!ownerPending || existingOwnerId.isNotEmpty) {
        return false;
      }

      if (userDoc.exists && userDoc.data() != null) {
        pseudo = (userDoc.data()!['pseudo'] ?? '').toString();
      }

      transaction.update(activityRef, {
        'ownerId': currentUserId,
        'ownerPseudo': pseudo,
        'ownerPending': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });

    if (success) {
      await _chatService.addSystemMessage(
        activityId: activityId,
        text: '$pseudo est devenu organisateur',
      );
    }

    return success;
  }

  Future<bool> canJoinActivity(Activity activity) async {
    if (activity.status == ActivityStatusValues.cancelled ||
        activity.status == ActivityStatusValues.done ||
        activity.status == ActivityStatusValues.full) {
      return false;
    }

    if (activity.visibility == ActivityVisibilityValues.inviteOnly) {
      return false;
    }

    if (activity.maxParticipants <= 0) {
      return true;
    }

    final participantCount =
        await _activityService.getParticipantCount(activity.id);

    return participantCount < activity.maxParticipants;
  }
}