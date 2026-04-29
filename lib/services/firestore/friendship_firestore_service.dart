import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/friendship.dart';

class FriendshipFirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FriendshipFirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get currentUserId {
    final uid = _auth.currentUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      throw Exception('No authenticated Firebase user');
    }

    return uid;
  }

  Stream<List<Friendship>> getReceivedFriendRequests() {
    final uid = currentUserId;

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
    final uid = currentUserId;

    return _db
        .collection(FirestoreCollections.friendships)
        .where('addresseeId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
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
    final uid = currentUserId;

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
    final uid = currentUserId;
    final other = otherUserId.trim();

    if (other.isEmpty) {
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
    final uid = currentUserId;

    final sentAcceptedQuery = _db
        .collection(FirestoreCollections.friendships)
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted');

    final receivedAcceptedQuery = _db
        .collection(FirestoreCollections.friendships)
        .where('addresseeId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted');

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