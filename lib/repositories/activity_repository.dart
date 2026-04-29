import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/core/utils/parsers.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class ActivityRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ActivityFirestoreService _activityService;
  final UserFirestoreService _userService;
  final GroupsRepository _groupsRepository;

  ActivityRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    ActivityFirestoreService? activityService,
    UserFirestoreService? userService,
    GroupsRepository? groupsRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _activityService = activityService ??
            ActivityFirestoreService(
              db: db,
              auth: auth,
            ),
        _userService = userService ??
            UserFirestoreService(
              db: db,
              auth: auth,
            ),
        _groupsRepository = groupsRepository ??
            GroupsRepository(
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

  Future<String> createActivity({
    required String title,
    required String description,
    required String category,
    required String day,
    required String startTime,
    required String endTime,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String location,
    required String maxParticipants,
    required String level,
    required String groupType,
    String visibility = ActivityVisibilityValues.public,
    String? groupId,
    String? groupName,
  }) async {
    final uid = currentUserId;
    final resolvedTitle = title.trim();
    final resolvedDescription = description.trim();
    final resolvedCategory = category.trim();
    final resolvedLocation = location.trim();
    final resolvedLevel = level.trim();
    final resolvedGroupType = groupType.trim();
    final resolvedVisibility = visibility.trim();

    if (resolvedTitle.isEmpty ||
        resolvedDescription.isEmpty ||
        resolvedCategory.isEmpty ||
        resolvedLocation.isEmpty ||
        resolvedLevel.isEmpty ||
        resolvedGroupType.isEmpty) {
      throw Exception('Tous les champs obligatoires doivent être remplis.');
    }

    if (!endDateTime.isAfter(startDateTime)) {
      throw Exception('La date de fin doit être après la date de début.');
    }

    final ownerPseudo = await _userService.getCurrentUserPseudo();

    final normalizedMaxParticipants =
        maxParticipants.trim().isEmpty ? '0' : maxParticipants.trim();
    final maxParticipantsInt = parseInt(normalizedMaxParticipants);

    if (maxParticipantsInt < 0) {
      throw Exception('Le nombre maximum de participants est invalide.');
    }

    final rawGroupId = groupId?.trim();
    final trimmedGroupId =
        rawGroupId != null && rawGroupId.isNotEmpty ? rawGroupId : null;

    final rawGroupName = groupName?.trim();
    final trimmedGroupName =
        trimmedGroupId != null && rawGroupName != null && rawGroupName.isNotEmpty
            ? rawGroupName
            : null;

    if (trimmedGroupId != null) {
      final isMember =
          await _groupsRepository.isCurrentUserMember(trimmedGroupId);

      if (!isMember) {
        throw Exception(
          'Impossible de créer une activité de groupe sans être membre du groupe.',
        );
      }
    }

    final initialStatus = computeActivityStatus(
      participantCount: 1,
      maxParticipants: maxParticipantsInt,
      currentStatus: ActivityStatusValues.open,
    );

    final activityId = await _activityService.createActivityDocument(
      title: resolvedTitle,
      description: resolvedDescription,
      category: resolvedCategory,
      day: day.trim(),
      startTime: startTime.trim(),
      endTime: endTime.trim(),
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      location: resolvedLocation,
      maxParticipants: maxParticipantsInt,
      level: resolvedLevel,
      groupType: resolvedGroupType,
      visibility: resolvedVisibility,
      ownerId: uid,
      ownerPseudo: ownerPseudo,
      initialStatus: initialStatus,
      groupId: trimmedGroupId,
      groupName: trimmedGroupName,
    );

    await _activityService.addParticipant(
      activityId: activityId,
      userId: uid,
      pseudo: ownerPseudo,
    );

    await _activityService.addJoinedActivityMirror(
      userId: uid,
      activityId: activityId,
      source: 'created',
    );

    return activityId;
  }

  Future<void> updateActivity({
    required String activityId,
    String? title,
    String? description,
    String? category,
    String? day,
    String? startTime,
    String? endTime,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? location,
    String? maxParticipants,
    String? level,
    String? groupType,
    String? visibility,
    bool isLimitedEdit = false,
  }) async {
    final uid = currentUserId;
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      throw Exception('Identifiant d’activité invalide.');
    }

    final activityRef = _activitiesRef.doc(trimmedActivityId);

    await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);

      if (!activityDoc.exists || activityDoc.data() == null) {
        throw Exception('Activité introuvable.');
      }

      final data = activityDoc.data()!;
      final currentActivity = Activity.fromMap(activityDoc.id, data);

      if (currentActivity.ownerId != uid) {
        throw Exception('Seul l’organisateur peut modifier cette activité.');
      }

      final participantCount = parseInt(data['participantCount']);

      if (isLimitedEdit) {
        if (participantCount <= 1) {
          throw Exception('Cette activité peut être modifiée complètement.');
        }

        final limitedDescription =
            (description ?? currentActivity.description).trim();
        final limitedLocation = (location ?? currentActivity.location).trim();

        if (limitedDescription.isEmpty || limitedLocation.isEmpty) {
          throw Exception('La description et le lieu sont obligatoires.');
        }

        transaction.update(activityRef, {
          'description': limitedDescription,
          'location': limitedLocation,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return;
      }

      if (participantCount > 1) {
        throw Exception(
          'Modification complète impossible : des participants ont déjà rejoint l’activité.',
        );
      }

      final resolvedTitle = (title ?? currentActivity.title).trim();
      final resolvedDescription =
          (description ?? currentActivity.description).trim();
      final resolvedCategory = (category ?? currentActivity.category).trim();
      final resolvedLocation = (location ?? currentActivity.location).trim();
      final resolvedLevel = (level ?? currentActivity.level).trim();
      final resolvedGroupType = (groupType ?? currentActivity.groupType).trim();
      final resolvedVisibility =
          (visibility ?? currentActivity.visibility).trim();

      final normalizedMaxParticipants = maxParticipants == null
          ? currentActivity.maxParticipants.toString()
          : (maxParticipants.trim().isEmpty ? '0' : maxParticipants.trim());

      final resolvedMaxParticipants = parseInt(normalizedMaxParticipants);

      final fallbackDay = (day ?? currentActivity.day).trim();
      final fallbackStartTime = (startTime ?? currentActivity.startTime).trim();
      final fallbackEndTime = (endTime ?? currentActivity.endTime).trim();

      final resolvedStartDateTime = startDateTime ??
          currentActivity.startDateTime ??
          _combineLegacyDateAndTime(fallbackDay, fallbackStartTime);

      final resolvedEndDateTime = endDateTime ??
          currentActivity.endDateTime ??
          _combineLegacyDateAndTime(fallbackDay, fallbackEndTime);

      if (resolvedTitle.isEmpty ||
          resolvedDescription.isEmpty ||
          resolvedCategory.isEmpty ||
          resolvedLocation.isEmpty ||
          resolvedLevel.isEmpty ||
          resolvedGroupType.isEmpty ||
          resolvedVisibility.isEmpty) {
        throw Exception('Tous les champs obligatoires doivent être remplis.');
      }

      if (resolvedStartDateTime == null || resolvedEndDateTime == null) {
        throw Exception('Les dates de début et de fin sont invalides.');
      }

      if (!resolvedEndDateTime.isAfter(resolvedStartDateTime)) {
        throw Exception('La date de fin doit être après la date de début.');
      }

      if (resolvedMaxParticipants < 0) {
        throw Exception('Le nombre maximum de participants est invalide.');
      }

      final resolvedDay = _formatDateOnly(resolvedStartDateTime);
      final resolvedStartTime = _formatTimeOnly(resolvedStartDateTime);
      final resolvedEndTime = _formatTimeOnly(resolvedEndDateTime);

      final newStatus = computeActivityStatus(
        participantCount: participantCount,
        maxParticipants: resolvedMaxParticipants,
        currentStatus: currentActivity.status,
      );

      transaction.update(activityRef, {
        'title': resolvedTitle,
        'description': resolvedDescription,
        'category': resolvedCategory,
        'day': resolvedDay,
        'startTime': resolvedStartTime,
        'endTime': resolvedEndTime,
        'startDateTime': Timestamp.fromDate(resolvedStartDateTime),
        'endDateTime': Timestamp.fromDate(resolvedEndDateTime),
        'location': resolvedLocation,
        'maxParticipants': resolvedMaxParticipants,
        'level': resolvedLevel,
        'groupType': resolvedGroupType,
        'visibility': resolvedVisibility,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> joinActivity(Activity activity) async {
    final uid = currentUserId;
    final activityId = activity.id.trim();

    if (activityId.isEmpty) return false;

    final activityRef = _activitiesRef.doc(activityId);
    final participantRef =
        activityRef.collection(FirestoreCollections.participants).doc(uid);
    final userRef = _usersRef.doc(uid);

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

      final currentActivity = Activity.fromMap(activityDoc.id, activityData);

      if (!_canJoinBasedOnActivityState(currentActivity)) {
        return false;
      }

      if (currentActivity.isGroupActivity) {
        final groupId = currentActivity.groupId!.trim();
        final isGroupMember =
            await _groupsRepository.isCurrentUserMember(groupId);

        if (!isGroupMember &&
            currentActivity.visibility != ActivityVisibilityValues.public) {
          return false;
        }
      }

      final participantCount = currentActivity.participantCount;
      final maxParticipants = currentActivity.maxParticipants;

      if (maxParticipants > 0 && participantCount >= maxParticipants) {
        return false;
      }

      if (userDoc.exists && userDoc.data() != null) {
        joinedPseudo = (userDoc.data()!['pseudo'] ?? '').toString().trim();
      }

      if (joinedPseudo.isEmpty) {
        joinedPseudo = await _userService.getCurrentUserPseudo();
      }

      final newParticipantCount = participantCount + 1;
      final newStatus = computeActivityStatus(
        participantCount: newParticipantCount,
        maxParticipants: maxParticipants,
        currentStatus: currentActivity.status,
      );

      transaction.set(participantRef, {
        'userId': uid,
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
      await _activityService.addJoinedActivityMirror(
        userId: uid,
        activityId: activityId,
        source: 'join',
      );
    }

    return success;
  }

  Future<void> leaveActivity(String activityId) async {
    final uid = currentUserId;
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) return;

    final activityRef = _activitiesRef.doc(trimmedActivityId);
    final participantRef =
        activityRef.collection(FirestoreCollections.participants).doc(uid);

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

      final participantCount = parseInt(activityData['participantCount']);
      final maxParticipants = parseInt(activityData['maxParticipants']);
      final currentStatus =
          (activityData['status'] ?? ActivityStatusValues.open).toString();

      final newParticipantCount = participantCount > 0 ? participantCount - 1 : 0;

      final newStatus = computeActivityStatus(
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

    await _activityService.removeJoinedActivityMirror(
      userId: uid,
      activityId: trimmedActivityId,
    );
  }

  Future<void> leaveActivityWithOwnerHandling(String activityId) async {
    final uid = currentUserId;
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) return;

    final activityRef = _activitiesRef.doc(trimmedActivityId);
    final participantRef =
        activityRef.collection(FirestoreCollections.participants).doc(uid);

    bool deletedActivity = false;

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

      final ownerId = (data['ownerId'] ?? '').toString().trim();
      final participantCount = parseInt(data['participantCount']);
      final maxParticipants = parseInt(data['maxParticipants']);
      final currentStatus =
          (data['status'] ?? ActivityStatusValues.open).toString();
      final isOwner = ownerId == uid;

      if (!isOwner) {
        final newParticipantCount =
            participantCount > 0 ? participantCount - 1 : 0;

        final newStatus = computeActivityStatus(
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

      final newParticipantCount = participantCount - 1;

      final newStatus = computeActivityStatus(
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
    });

    await _activityService.removeJoinedActivityMirror(
      userId: uid,
      activityId: trimmedActivityId,
    );

    if (deletedActivity) {
      return;
    }
  }

  Future<bool> claimOwnership(String activityId) async {
    final uid = currentUserId;
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) return false;

    final activityRef = _activitiesRef.doc(trimmedActivityId);
    final participantRef =
        activityRef.collection(FirestoreCollections.participants).doc(uid);
    final userRef = _usersRef.doc(uid);

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

      final ownerPending = _parseBool(activityData['ownerPending']);
      final existingOwnerId = (activityData['ownerId'] ?? '').toString().trim();

      if (!ownerPending || existingOwnerId.isNotEmpty) {
        return false;
      }

      if (userDoc.exists && userDoc.data() != null) {
        pseudo = (userDoc.data()!['pseudo'] ?? '').toString().trim();
      }

      if (pseudo.isEmpty) {
        pseudo = await _userService.getCurrentUserPseudo();
      }

      transaction.update(activityRef, {
        'ownerId': uid,
        'ownerPseudo': pseudo,
        'ownerPending': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });

    return success;
  }

  Future<bool> canJoinActivity(Activity activity) async {
    final freshActivity = await _activityService.getActivityById(activity.id);

    if (freshActivity == null) {
      return false;
    }

    if (!_canJoinBasedOnActivityState(freshActivity)) {
      return false;
    }

    if (freshActivity.isGroupActivity) {
      final groupId = freshActivity.groupId!.trim();
      final isGroupMember =
          await _groupsRepository.isCurrentUserMember(groupId);

      if (!isGroupMember &&
          freshActivity.visibility != ActivityVisibilityValues.public) {
        return false;
      }
    }

    if (freshActivity.maxParticipants <= 0) {
      return true;
    }

    final participantCount =
        await _activityService.getParticipantCount(freshActivity.id);

    return participantCount < freshActivity.maxParticipants;
  }

  Future<bool> canEditActivity(Activity activity) async {
    final participantCount =
        await _activityService.getParticipantCount(activity.id);

    return participantCount <= 1;
  }

  Future<bool> canDeleteOrEditNoteActivity(Activity activity) async {
    final participantCount =
        await _activityService.getParticipantCount(activity.id);

    return participantCount <= 1;
  }

  bool _canJoinBasedOnActivityState(Activity activity) {
    if (activity.status == ActivityStatusValues.cancelled ||
        activity.status == ActivityStatusValues.done ||
        activity.status == ActivityStatusValues.full) {
      return false;
    }

    if (activity.visibility == ActivityVisibilityValues.inviteOnly) {
      return false;
    }

    if (activity.hasEnded) {
      return false;
    }

    return true;
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.trim().toLowerCase() == 'true';
    return false;
  }

  DateTime? _combineLegacyDateAndTime(String day, String time) {
    try {
      final parsedDay = day.trim();
      final parsedTime = time.trim();

      if (parsedDay.isEmpty || parsedTime.isEmpty) {
        return null;
      }

      final date = DateTime.parse(parsedDay);
      final parts = parsedTime.split(':');

      if (parts.length < 2) return null;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      return DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
    } catch (_) {
      return null;
    }
  }

  String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTimeOnly(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}