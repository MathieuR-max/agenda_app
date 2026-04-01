import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/services/current_user.dart';

class ActivityFirestoreService {
  final FirebaseFirestore _db;

  ActivityFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _db.collection(FirestoreCollections.activities);

  Future<String> createActivityDocument({
    required String title,
    required String description,
    required String category,
    required String day,
    required String startTime,
    required String endTime,
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
    final rawGroupId = groupId?.trim();
    final trimmedGroupId =
        rawGroupId != null && rawGroupId.isNotEmpty ? rawGroupId : null;

    final rawGroupName = groupName?.trim();
    final trimmedGroupName =
        trimmedGroupId != null && rawGroupName != null && rawGroupName.isNotEmpty
            ? rawGroupName
            : null;

    final activityRef = await _activities.add({
      'title': title,
      'description': description,
      'category': category,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'maxParticipants': maxParticipants,
      'level': level,
      'groupType': groupType,
      'ownerId': ownerId,
      'ownerPseudo': ownerPseudo,
      'ownerPending': false,
      'participantCount': 1,
      'lastMessageText': null,
      'lastMessageAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'visibility': visibility,
      'status': initialStatus,
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

    await _activities
        .doc(trimmedActivityId)
        .collection(FirestoreCollections.participants)
        .doc(trimmedUserId)
        .set({
      'userId': trimmedUserId,
      'pseudo': pseudo,
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

    await _activities
        .doc(trimmedActivityId)
        .collection(FirestoreCollections.participants)
        .doc(trimmedUserId)
        .delete();
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

    final doc = await _activities
        .doc(trimmedActivityId)
        .collection(FirestoreCollections.participants)
        .doc(trimmedUserId)
        .get();

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

    await _activities.doc(trimmedActivityId).update(fields);
  }

  Future<void> deleteActivity(String activityId) async {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return;
    }

    await _activities.doc(trimmedActivityId).delete();
  }

  Future<Activity?> getActivityById(String activityId) async {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return null;
    }

    final doc = await _activities.doc(trimmedActivityId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Activity.fromFirestore(doc.data()!, doc.id);
  }

  Stream<Map<String, dynamic>?> watchActivity(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(null);
    }

    return _activities.doc(trimmedActivityId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return {
        'id': doc.id,
        ...doc.data()!,
      };
    });
  }

  Stream<List<Activity>> getCreatedActivities() {
    return _activities
        .where('ownerId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      final activities = snapshot.docs
          .map((doc) => Activity.fromFirestore(doc.data(), doc.id))
          .toList();

      _sortActivitiesByRecency(activities);
      return activities;
    });
  }

  Stream<List<Activity>> getAllActivities() {
    return _activities
        .where('visibility', isEqualTo: Activity.visibilityPublic)
        .snapshots()
        .map((snapshot) {
      final activities = snapshot.docs
          .map((doc) => Activity.fromFirestore(doc.data(), doc.id))
          .where((activity) => !activity.isGroupActivity)
          .toList();

      _sortActivitiesByRecency(activities);
      return activities;
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
      final activities = snapshot.docs
          .map((doc) => Activity.fromFirestore(doc.data(), doc.id))
          .toList();

      _sortActivitiesByRecency(activities);
      return activities;
    });
  }

  Future<int> getParticipantCount(String activityId) async {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return 0;
    }

    final activityDoc = await _activities.doc(trimmedActivityId).get();

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

    return _activities.doc(trimmedActivityId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return 0;
      return _parseInt(doc.data()!['participantCount']);
    });
  }

  Stream<List<String>> getParticipants(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(<String>[]);
    }

    return _activities
        .doc(trimmedActivityId)
        .collection(FirestoreCollections.participants)
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

    return _activities
        .doc(trimmedActivityId)
        .collection(FirestoreCollections.participants)
        .orderBy('joinedAt')
        .snapshots()
        .asyncMap((participantSnapshot) async {
      final List<Map<String, dynamic>> users = [];

      for (final participantDoc in participantSnapshot.docs) {
        final data = participantDoc.data();
        final String userId = (data['userId'] ?? '').toString().trim();

        if (userId.isEmpty) continue;

        final userDoc =
            await _db.collection(FirestoreCollections.users).doc(userId).get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;

          users.add({
            'id': userDoc.id,
            'pseudo': userData['pseudo'] ?? '',
            'prenom': userData['prenom'] ?? '',
            'nom': userData['nom'] ?? '',
            'lieu': userData['lieu'] ?? userData['Lieu'] ?? '',
            'genre': userData['genre'] ?? '',
          });
        }
      }

      return users;
    });
  }

  Stream<List<Map<String, dynamic>>> getInviteableUsers(String activityId) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    final activityRef = _db
        .collection(FirestoreCollections.activities)
        .doc(trimmedActivityId);

    return activityRef
        .collection(FirestoreCollections.participants)
        .snapshots()
        .asyncMap((participantSnapshot) async {
      final participantIds = participantSnapshot.docs
          .map((doc) => (doc.data()['userId'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      participantIds.add(currentUserId);

      final usersSnapshot =
          await _db.collection(FirestoreCollections.users).get();

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
    });
  }

  Stream<List<String>> getJoinedActivityIds() {
    return _activities.snapshots().asyncMap((snapshot) async {
      final List<String> joinedIds = [];

      for (final doc in snapshot.docs) {
        final participantDoc = await _activities
            .doc(doc.id)
            .collection(FirestoreCollections.participants)
            .doc(currentUserId)
            .get();

        if (participantDoc.exists) {
          joinedIds.add(doc.id);
        }
      }

      return joinedIds;
    });
  }

  Stream<List<Activity>> getJoinedActivities() {
    return getJoinedActivityIds().asyncMap((ids) async {
      if (ids.isEmpty) return <Activity>[];

      final snapshot = await _activities
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      final activities = snapshot.docs
          .map((doc) => Activity.fromFirestore(doc.data(), doc.id))
          .toList();

      _sortActivitiesByRecency(activities);
      return activities;
    });
  }

  Future<bool> deleteActivityIfNoParticipants(String activityId) async {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return false;
    }

    final activityRef = _activities.doc(trimmedActivityId);

    return await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);

      if (!activityDoc.exists || activityDoc.data() == null) {
        return false;
      }

      final data = activityDoc.data()!;
      final String ownerId = (data['ownerId'] ?? '').toString();
      final int participantCount = _parseInt(data['participantCount']);

      final bool isOwner = ownerId == currentUserId;

      if (!isOwner) {
        return false;
      }

      if (participantCount > 1) {
        return false;
      }

      final participantsSnapshot =
          await activityRef.collection(FirestoreCollections.participants).get();

      for (final doc in participantsSnapshot.docs) {
        transaction.delete(doc.reference);
      }

      final messagesSnapshot =
          await activityRef.collection(FirestoreCollections.messages).get();

      for (final doc in messagesSnapshot.docs) {
        transaction.delete(doc.reference);
      }

      transaction.delete(activityRef);
      return true;
    });
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _sortActivitiesByRecency(List<Activity> activities) {
    activities.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
  }
}