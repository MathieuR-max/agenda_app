import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/services/current_user.dart';

class FriendshipFirestoreService {
  final FirebaseFirestore _db;

  FriendshipFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  Stream<List<Friendship>> getReceivedFriendRequests() {
    return _db
        .collection(FirestoreCollections.friendships)
        .where('addresseeId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<Friendship>> getPendingReceivedFriendRequests() {
    return _db
        .collection(FirestoreCollections.friendships)
        .where('addresseeId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<Friendship>> getSentFriendRequests() {
    return _db
        .collection(FirestoreCollections.friendships)
        .where('requesterId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<Friendship?> watchFriendshipWithUser(String otherUserId) {
    return _db.collection(FirestoreCollections.friendships).snapshots().map((
      snapshot,
    ) {
      for (final doc in snapshot.docs) {
        final data = doc.data();

        final requesterId = (data['requesterId'] ?? '').toString();
        final addresseeId = (data['addresseeId'] ?? '').toString();

        final matches =
            (requesterId == currentUserId && addresseeId == otherUserId) ||
            (requesterId == otherUserId && addresseeId == currentUserId);

        if (matches) {
          return Friendship.fromFirestore(data, doc.id);
        }
      }

      return null;
    });
  }
  Stream<List<Friendship>> getAcceptedFriendships() {
  return _db
      .collection(FirestoreCollections.friendships)
      .where('status', isEqualTo: 'accepted')
      .snapshots()
      .map((snapshot) {
    final all = snapshot.docs
        .map((doc) => Friendship.fromFirestore(doc.data(), doc.id))
        .toList();

    return all.where((friendship) {
      return friendship.requesterId == currentUserId ||
          friendship.addresseeId == currentUserId;
    }).toList();
  });
}
}