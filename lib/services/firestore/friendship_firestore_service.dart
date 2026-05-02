import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/services/current_user.dart';

class FriendshipFirestoreService {
  final FirebaseFirestore _db;

  FriendshipFirestoreService({
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

  Stream<List<Friendship>> getReceivedFriendRequests() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<Friendship>[]);
    }

    return _db
        .collection(FirestoreCollections.friendships)
        .where('addresseeId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final friendships = snapshot.docs
          .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
          .toList();

      _sortFriendships(friendships);
      return friendships;
    });
  }

  Stream<List<Friendship>> getPendingReceivedFriendRequests() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<Friendship>[]);
    }

    return _db
        .collection(FirestoreCollections.friendships)
        .where('addresseeId', isEqualTo: uid)
        .where('status', isEqualTo: Friendship.statusPending)
        .snapshots()
        .map((snapshot) {
      final friendships = snapshot.docs
          .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
          .toList();

      _sortFriendships(friendships);
      return friendships;
    });
  }

  Stream<List<Friendship>> getSentFriendRequests() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<Friendship>[]);
    }

    return _db
        .collection(FirestoreCollections.friendships)
        .where('requesterId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final friendships = snapshot.docs
          .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
          .toList();

      _sortFriendships(friendships);
      return friendships;
    });
  }

  Stream<Friendship?> watchFriendshipWithUser(String otherUserId) {
    final uid = currentUserIdOrNull;
    final other = otherUserId.trim();

    if (uid == null || other.isEmpty) {
      return Stream.value(null);
    }

    final sentQuery = _db
        .collection(FirestoreCollections.friendships)
        .where('requesterId', isEqualTo: uid)
        .where('addresseeId', isEqualTo: other);

    final receivedQuery = _db
        .collection(FirestoreCollections.friendships)
        .where('requesterId', isEqualTo: other)
        .where('addresseeId', isEqualTo: uid);

    return sentQuery.snapshots().asyncMap((sentSnapshot) async {
      final receivedSnapshot = await receivedQuery.get();

      final friendships = <Friendship>[
        ...sentSnapshot.docs
            .map((doc) => Friendship.fromFirestore(doc.data(), doc.id)),
        ...receivedSnapshot.docs
            .map((doc) => Friendship.fromFirestore(doc.data(), doc.id)),
      ];

      if (friendships.isEmpty) {
        return null;
      }

      _sortFriendships(friendships);
      return friendships.first;
    });
  }

  Stream<List<Friendship>> getAcceptedFriendships() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<Friendship>[]);
    }

    final sentAcceptedQuery = _db
        .collection(FirestoreCollections.friendships)
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: Friendship.statusAccepted);

    final receivedAcceptedQuery = _db
        .collection(FirestoreCollections.friendships)
        .where('addresseeId', isEqualTo: uid)
        .where('status', isEqualTo: Friendship.statusAccepted);

    return sentAcceptedQuery.snapshots().asyncMap((sentSnapshot) async {
      final receivedSnapshot = await receivedAcceptedQuery.get();

      final friendships = <Friendship>[
        ...sentSnapshot.docs
            .map((doc) => Friendship.fromFirestore(doc.data(), doc.id)),
        ...receivedSnapshot.docs
            .map((doc) => Friendship.fromFirestore(doc.data(), doc.id)),
      ];

      final byId = <String, Friendship>{};

      for (final friendship in friendships) {
        byId[friendship.id] = friendship;
      }

      final result = byId.values.toList();
      _sortFriendships(result);
      return result;
    });
  }

  void _sortFriendships(List<Friendship> friendships) {
    friendships.sort((a, b) {
      final aDate = a.respondedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.respondedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
  }
}