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
  }) async {
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
    });

    return activityRef.id;
  }

  Future<void> addParticipant({
    required String activityId,
    required String userId,
    required String pseudo,
  }) async {
    await _activities
        .doc(activityId)
        .collection(FirestoreCollections.participants)
        .doc(userId)
        .set({
      'userId': userId,
      'pseudo': pseudo,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeParticipant({
    required String activityId,
    required String userId,
  }) async {
    await _activities
        .doc(activityId)
        .collection(FirestoreCollections.participants)
        .doc(userId)
        .delete();
  }

  Future<bool> isParticipant({
    required String activityId,
    required String userId,
  }) async {
    final doc = await _activities
        .doc(activityId)
        .collection(FirestoreCollections.participants)
        .doc(userId)
        .get();

    return doc.exists;
  }

  Future<void> updateActivityFields({
    required String activityId,
    required Map<String, dynamic> fields,
  }) async {
    await _activities.doc(activityId).update(fields);
  }

  Future<void> deleteActivity(String activityId) async {
    await _activities.doc(activityId).delete();
  }

  Future<Activity?> getActivityById(String activityId) async {
    final doc = await _activities.doc(activityId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Activity.fromFirestore(doc.data()!, doc.id);
  }

  Stream<Map<String, dynamic>?> watchActivity(String activityId) {
    return _activities.doc(activityId).snapshots().map((doc) {
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
      return snapshot.docs
          .map((doc) => Activity.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<Activity>> getAllActivities() {
    return _activities
        .where('visibility', isEqualTo: 'public')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Activity.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<int> getParticipantCount(String activityId) async {
    final activityDoc = await _activities.doc(activityId).get();

    if (!activityDoc.exists || activityDoc.data() == null) {
      return 0;
    }

    final data = activityDoc.data()!;
    final value = data['participantCount'];

    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Stream<int> getParticipantCountStream(String activityId) {
    return _activities.doc(activityId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return 0;

      final value = doc.data()!['participantCount'];

      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    });
  }

  Stream<List<String>> getParticipants(String activityId) {
    return _activities
        .doc(activityId)
        .collection(FirestoreCollections.participants)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => (doc.data()['userId'] ?? '').toString())
          .where((userId) => userId.isNotEmpty)
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getParticipantUsers(String activityId) {
    return _activities
        .doc(activityId)
        .collection(FirestoreCollections.participants)
        .snapshots()
        .asyncMap((participantSnapshot) async {
      final List<Map<String, dynamic>> users = [];

      for (final participantDoc in participantSnapshot.docs) {
        final data = participantDoc.data();
        final String userId = (data['userId'] ?? '').toString();

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
  final activityRef = _db
      .collection(FirestoreCollections.activities)
      .doc(activityId);

  return activityRef
      .collection(FirestoreCollections.participants)
      .snapshots()
      .asyncMap((participantSnapshot) async {
    final participantIds = participantSnapshot.docs
        .map((doc) => (doc.data()['userId'] ?? '').toString())
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

      return snapshot.docs
          .map((doc) => Activity.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<bool> deleteActivityIfNoParticipants(String activityId) async {
    final activityRef = _activities.doc(activityId);

    return await _db.runTransaction((transaction) async {
      final activityDoc = await transaction.get(activityRef);

      if (!activityDoc.exists || activityDoc.data() == null) {
        return false;
      }

      final data = activityDoc.data()!;
      final String ownerId = (data['ownerId'] ?? '').toString();
      final dynamic participantCountValue = data['participantCount'];

      int participantCount = 0;
      if (participantCountValue is int) {
        participantCount = participantCountValue;
      } else if (participantCountValue is double) {
        participantCount = participantCountValue.toInt();
      } else if (participantCountValue is String) {
        participantCount = int.tryParse(participantCountValue) ?? 0;
      }

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
  
}