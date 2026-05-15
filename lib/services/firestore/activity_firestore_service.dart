import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/services/current_user.dart';

class ActivityFirestoreService {
  final FirebaseFirestore _db;

  ActivityFirestoreService({
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

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

  CollectionReference<Map<String, dynamic>> get _activities =>
      _db.collection(FirestoreCollections.activities);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _activityInvitations =>
      _db.collection(FirestoreCollections.activityInvitations);

  DocumentReference<Map<String, dynamic>> _activityDoc(String activityId) =>
      _activities.doc(activityId.trim());

  CollectionReference<Map<String, dynamic>> _participantsRef(
    String activityId,
  ) =>
      _activityDoc(activityId).collection(FirestoreCollections.participants);

  CollectionReference<Map<String, dynamic>> _messagesRef(String activityId) =>
      _activityDoc(activityId).collection(FirestoreCollections.messages);

  DocumentReference<Map<String, dynamic>> _joinedActivityRef({
    required String userId,
    required String activityId,
  }) {
    return _users
        .doc(userId.trim())
        .collection('joined_activities')
        .doc(activityId.trim());
  }

  void _log(String message) {
    debugPrint('ACTIVITY_FS $message');
  }

  Future<void> addJoinedActivityMirror({
    required String userId,
    required String activityId,
    required String source,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedActivityId = activityId.trim();
    final trimmedSource = source.trim();

    if (trimmedUserId.isEmpty || trimmedActivityId.isEmpty) {
      return;
    }

    await _joinedActivityRef(
      userId: trimmedUserId,
      activityId: trimmedActivityId,
    ).set({
      'activityId': trimmedActivityId,
      'joinedAt': FieldValue.serverTimestamp(),
      'source': trimmedSource.isEmpty ? 'unknown' : trimmedSource,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeJoinedActivityMirror({
    required String userId,
    required String activityId,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedActivityId = activityId.trim();

    if (trimmedUserId.isEmpty || trimmedActivityId.isEmpty) {
      return;
    }

    await _joinedActivityRef(
      userId: trimmedUserId,
      activityId: trimmedActivityId,
    ).delete();
  }

  Stream<List<String>> watchJoinedActivityIds() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<String>[]);
    }

    _log('watchJoinedActivityIds uid=$uid');

    return _users
        .doc(uid)
        .collection('joined_activities')
        .snapshots()
        .map((snapshot) {
      final ids = snapshot.docs
          .map((doc) => (doc.data()['activityId'] ?? doc.id).toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      _log('watchJoinedActivityIds result=$ids');
      return ids;
    }).handleError((error, stackTrace) {
      _log('watchJoinedActivityIds ERROR: $error');
    });
  }

  Stream<List<String>> getJoinedActivityIds() {
    return watchJoinedActivityIds();
  }

  Future<String> createActivityDocument({
    required String title,
    required String description,
    required String category,
    required String day,
    required String startTime,
    required String endTime,
    DateTime? startDateTime,
    DateTime? endDateTime,
    required String location,
    required int maxParticipants,
    required String level,
    required String groupType,
    required String visibility,
    required String ownerId,
    required String ownerPseudo,
    required String initialStatus,
    String? groupId,
    String? groupName,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    final trimmedCategory = category.trim();
    final trimmedDay = day.trim();
    final trimmedStartTime = startTime.trim();
    final trimmedEndTime = endTime.trim();
    final trimmedLocation = location.trim();
    final trimmedLevel = level.trim();
    final trimmedGroupType = groupType.trim();
    final trimmedVisibility = visibility.trim();
    final trimmedOwnerId = ownerId.trim();
    final trimmedOwnerPseudo = ownerPseudo.trim();

    final rawGroupId = groupId?.trim();
    final trimmedGroupId =
        rawGroupId != null && rawGroupId.isNotEmpty ? rawGroupId : null;

    final rawGroupName = groupName?.trim();
    final trimmedGroupName =
        trimmedGroupId != null && rawGroupName != null && rawGroupName.isNotEmpty
            ? rawGroupName
            : null;

    final activityRef = await _activities.add({
      'title': trimmedTitle,
      'description': trimmedDescription,
      'category': trimmedCategory,
      'day': trimmedDay,
      'startTime': trimmedStartTime,
      'endTime': trimmedEndTime,
      'startDateTime':
          startDateTime != null ? Timestamp.fromDate(startDateTime) : null,
      'endDateTime':
          endDateTime != null ? Timestamp.fromDate(endDateTime) : null,
      'location': trimmedLocation,
      'maxParticipants': maxParticipants,
      'level': trimmedLevel,
      'groupType': trimmedGroupType,
      'ownerId': trimmedOwnerId,
      'ownerPseudo': trimmedOwnerPseudo,
      'ownerPending': false,
      'createdById': trimmedOwnerId,
      'createdByPseudo': trimmedOwnerPseudo,
      'reclaimedById': null,
      'reclaimedByPseudo': null,
      'reclaimedAt': null,
      'participantCount': 1,
      'participantVisibility': 'participants_only',
      'lastMessageText': null,
      'lastMessageAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'visibility': trimmedVisibility,
      'status': initialStatus.trim(),
      'groupId': trimmedGroupId,
      'groupName': trimmedGroupName,
    });

    return activityRef.id;
  }

  Future<void> addParticipant({
    required String activityId,
    required String userId,
    required String pseudo,
  }) async {
    final trimmedActivityId = activityId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedActivityId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    await _participantsRef(trimmedActivityId).doc(trimmedUserId).set({
      'userId': trimmedUserId,
      'pseudo': pseudo.trim(),
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeParticipant({
    required String activityId,
    required String userId,
  }) async {
    final trimmedActivityId = activityId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedActivityId.isEmpty || trimmedUserId.isEmpty) {
      return;
    }

    await _participantsRef(trimmedActivityId).doc(trimmedUserId).delete();
  }

  Future<bool> isParticipant({
    required String activityId,
    required String userId,
  }) async {
    final trimmedActivityId = activityId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedActivityId.isEmpty || trimmedUserId.isEmpty) {
      return false;
    }

    final doc =
        await _participantsRef(trimmedActivityId).doc(trimmedUserId).get();
    return doc.exists;
  }

  Future<void> updateActivityFields({
    required String activityId,
    required Map<String, dynamic> fields,
  }) async {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return;
    }

    final sanitizedFields = <String, dynamic>{
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _activityDoc(trimmedActivityId).update(sanitizedFields);
  }

  Future<void> deleteActivity(String activityId) async {
    await deleteActivityWithDependencies(activityId);
  }

  Future<Activity?> getActivityById(String activityId) async {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return null;
    }

    final doc = await _activityDoc(trimmedActivityId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Activity.fromDocument(doc);
  }

  Stream<Activity?> watchActivity(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(null);
    }

    return _activityDoc(trimmedActivityId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return Activity.fromDocument(doc);
    });
  }

  Stream<List<Activity>> getCreatedActivities() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<Activity>[]);
    }

    _log('getCreatedActivities uid=$uid');

    return _activities.where('ownerId', isEqualTo: uid).snapshots().map((
      snapshot,
    ) {
      final activities =
          snapshot.docs.map((doc) => Activity.fromDocument(doc)).toList();

      _sortActivitiesByRecency(activities);
      _log('getCreatedActivities resultCount=${activities.length}');
      return activities;
    });
  }

  Stream<List<Activity>> getAllActivities() {
    return _activities
        .where('visibility', isEqualTo: Activity.visibilityPublic)
        .snapshots()
        .map((snapshot) {
      final activities = snapshot.docs
          .map((doc) => Activity.fromDocument(doc))
          .where((activity) => !activity.isGroupActivity)
          .toList();

      _sortActivitiesByRecency(activities);
      return activities;
    });
  }

  // Requires a composite index in Firebase Console:
  //   Collection : activities
  //   Fields     : visibility ASC, status ASC, startDateTime ASC
  Stream<List<Activity>> getPublicDiscoverActivities() {
    return _activities
        .where('visibility', isEqualTo: Activity.visibilityPublic)
        .where('status', whereIn: ['open', 'full'])
        .where(
          'startDateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()),
        )
        .orderBy('startDateTime')
        .snapshots()
        .map((snapshot) {
      final activities =
          snapshot.docs.map((doc) => Activity.fromDocument(doc)).toList();

      _log('getPublicDiscoverActivities resultCount=${activities.length}');
      return activities;
    }).handleError((error, stackTrace) {
      _log('getPublicDiscoverActivities ERROR: $error');
      return <Activity>[];
    });
  }

  Stream<List<Activity>> getGroupActivities(String groupId) {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return Stream.value(<Activity>[]);
    }

    return _activities
        .where('groupId', isEqualTo: trimmedGroupId)
        .snapshots()
        .map((snapshot) {
      final activities =
          snapshot.docs.map((doc) => Activity.fromDocument(doc)).toList();

      _sortActivitiesByRecency(activities);
      return activities;
    });
  }

  Future<int> getParticipantCount(String activityId) async {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return 0;
    }

    final activityDoc = await _activityDoc(trimmedActivityId).get();

    if (!activityDoc.exists || activityDoc.data() == null) {
      return 0;
    }

    final data = activityDoc.data()!;
    return _parseInt(data['participantCount']);
  }

  Stream<int> getParticipantCountStream(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(0);
    }

    return _activityDoc(trimmedActivityId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return 0;
      return _parseInt(doc.data()!['participantCount']);
    });
  }

  Stream<List<String>> getParticipants(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(<String>[]);
    }

    return _participantsRef(trimmedActivityId)
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => (doc.data()['userId'] ?? '').toString().trim())
          .where((userId) => userId.isNotEmpty)
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getParticipantUsers(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _participantsRef(trimmedActivityId)
        .orderBy('joinedAt')
        .snapshots()
        .asyncMap((participantSnapshot) async {
      final List<Map<String, dynamic>> users = [];

      for (final participantDoc in participantSnapshot.docs) {
        final data = participantDoc.data();
        final userId = (data['userId'] ?? '').toString().trim();

        if (userId.isEmpty) continue;

        final userDoc = await _users.doc(userId).get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;

          users.add({
            'id': userDoc.id,
            'pseudo': (userData['pseudo'] ?? '').toString(),
            'prenom': (userData['prenom'] ?? '').toString(),
            'nom': (userData['nom'] ?? '').toString(),
            'lieu': ((userData['lieu'] ?? userData['Lieu']) ?? '').toString(),
            'genre': (userData['genre'] ?? '').toString(),
          });
        }
      }

      return users;
    });
  }

  Stream<List<Map<String, dynamic>>> getInviteableUsers(String activityId) {
    final trimmedActivityId = activityId.trim();
    final uid = currentUserIdOrNull;

    if (trimmedActivityId.isEmpty || uid == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _participantsRef(trimmedActivityId).snapshots().asyncMap(
      (participantSnapshot) async {
        final participantIds = participantSnapshot.docs
            .map((doc) => (doc.data()['userId'] ?? '').toString().trim())
            .where((id) => id.isNotEmpty)
            .toSet();

        participantIds.add(uid);

        final usersSnapshot = await _users
    .orderBy('pseudo')
    .limit(50)
    .get();

        final List<Map<String, dynamic>> users = [];

        for (final userDoc in usersSnapshot.docs) {
          if (participantIds.contains(userDoc.id)) continue;

          final data = userDoc.data();

          users.add({
            'id': userDoc.id,
            'pseudo': (data['pseudo'] ?? '').toString(),
            'prenom': (data['prenom'] ?? '').toString(),
            'nom': (data['nom'] ?? '').toString(),
            'lieu': ((data['lieu'] ?? data['Lieu']) ?? '').toString(),
            'genre': (data['genre'] ?? '').toString(),
          });
        }

        users.sort((a, b) {
          final aName = ((a['pseudo'] ?? '').toString().trim().isNotEmpty)
              ? (a['pseudo'] ?? '').toString().toLowerCase()
              : (a['prenom'] ?? '').toString().toLowerCase();

          final bName = ((b['pseudo'] ?? '').toString().trim().isNotEmpty)
              ? (b['pseudo'] ?? '').toString().toLowerCase()
              : (b['prenom'] ?? '').toString().toLowerCase();

          return aName.compareTo(bName);
        });

        return users;
      },
    );
  }

  Stream<List<Activity>> getJoinedActivities() {
  return getJoinedActivityIds().asyncMap((ids) async {
    if (ids.isEmpty) {
      _log('getJoinedActivities -> no ids');
      return <Activity>[];
    }

    final List<Activity> activities = [];

    for (final activityId in ids) {
      try {
        final doc = await _activityDoc(activityId).get();

        if (!doc.exists || doc.data() == null) {
          continue;
        }

        activities.add(Activity.fromDocument(doc));
      } catch (e) {
        _log(
          'getJoinedActivities skipped activity=$activityId error=$e',
        );
      }
    }

    _sortActivitiesByRecency(activities);

    _log('getJoinedActivities resultCount=${activities.length}');

    return activities;
  }).handleError((error, stackTrace) {
    _log('getJoinedActivities ERROR: $error');
  });
}

  Future<bool> deleteActivityIfNoParticipants(String activityId) async {
    try {
      await deleteActivityWithDependencies(activityId);
      return true;
    } catch (e) {
      _log('deleteActivityIfNoParticipants refused: $e');
      return false;
    }
  }

  Future<void> deleteActivityWithDependencies(String activityId) async {
    final trimmedActivityId = activityId.trim();
    final uid = currentUserIdOrNull;

    if (trimmedActivityId.isEmpty || uid == null) {
      throw Exception('Utilisateur non connecté ou activité invalide.');
    }

    final activityRef = _activityDoc(trimmedActivityId);

    final canDelete = await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);

      if (!activityDoc.exists || activityDoc.data() == null) {
        return false;
      }

      final data = activityDoc.data()!;
      final ownerId = (data['ownerId'] ?? '').toString().trim();
      final participantCount = _parseInt(data['participantCount']);

      return ownerId == uid && participantCount <= 1;
    });

    if (!canDelete) {
      throw Exception(
        'Suppression impossible : vous devez être organisateur et seul participant.',
      );
    }

    await _deleteSubcollection(_participantsRef(trimmedActivityId));
    await _deleteSubcollection(_messagesRef(trimmedActivityId));
    await _deleteInvitationDocsForActivity(trimmedActivityId);

    await activityRef.delete();
  }

  Future<void> _deleteInvitationDocsForActivity(String activityId) async {
    while (true) {
      final snapshot = await _activityInvitations
          .where('activityId', isEqualTo: activityId)
          .limit(100)
          .get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _db.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(100).get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _db.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  List<List<String>> _chunkList(List<String> items, int chunkSize) {
    final List<List<String>> chunks = [];

    for (int i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;

      chunks.add(items.sublist(i, end));
    }

    return chunks;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  void _sortActivitiesByRecency(List<Activity> activities) {
    activities.sort((a, b) {
      final aDate = a.resolvedStartDateTime ??
          a.updatedAt ??
          a.createdAt ??
          DateTime(2000);

      final bDate = b.resolvedStartDateTime ??
          b.updatedAt ??
          b.createdAt ??
          DateTime(2000);

      return bDate.compareTo(aDate);
    });
  }
}