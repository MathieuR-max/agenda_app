import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class FriendshipRepository {
  final FirebaseFirestore _db;
  final UserFirestoreService _userService;

  FriendshipRepository({
    FirebaseFirestore? db,
    UserFirestoreService? userService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _userService = userService ?? UserFirestoreService(db: db);

  String get currentUserId => CurrentUser.id;

  Future<bool> sendFriendRequest({
    required String toUserId,
  }) async {
    if (toUserId == currentUserId) {
      return false;
    }

    final currentUserPseudo = await _userService.getCurrentUserPseudo();
    final toUserRef = _db.collection(FirestoreCollections.users).doc(toUserId);

    return await _db.runTransaction((transaction) async {
      final toUserDoc = await transaction.get(toUserRef);

      if (!toUserDoc.exists || toUserDoc.data() == null) {
        return false;
      }

      final toUserPseudo = (toUserDoc.data()!['pseudo'] ?? '').toString();

      final existingRequest1 = await _db
          .collection(FirestoreCollections.friendships)
          .where('requesterId', isEqualTo: currentUserId)
          .where('addresseeId', isEqualTo: toUserId)
          .limit(1)
          .get();

      final existingRequest2 = await _db
          .collection(FirestoreCollections.friendships)
          .where('requesterId', isEqualTo: toUserId)
          .where('addresseeId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existingRequest1.docs.isNotEmpty || existingRequest2.docs.isNotEmpty) {
        return false;
      }

      final friendshipRef =
          _db.collection(FirestoreCollections.friendships).doc();

      transaction.set(friendshipRef, {
        'requesterId': currentUserId,
        'requesterPseudo': currentUserPseudo,
        'addresseeId': toUserId,
        'addresseePseudo': toUserPseudo,
        'status': FriendshipStatusValues.pending,
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      return true;
    });
  }

  Future<bool> acceptFriendRequest(String friendshipId) async {
    final friendshipRef = _db
        .collection(FirestoreCollections.friendships)
        .doc(friendshipId);

    return await _db.runTransaction((transaction) async {
      final friendshipDoc = await transaction.get(friendshipRef);

      if (!friendshipDoc.exists || friendshipDoc.data() == null) {
        return false;
      }

      final data = friendshipDoc.data()!;
      final addresseeId = (data['addresseeId'] ?? '').toString();
      final status =
          (data['status'] ?? FriendshipStatusValues.pending).toString();

      if (addresseeId != currentUserId) {
        return false;
      }

      if (status != FriendshipStatusValues.pending) {
        return false;
      }

      transaction.update(friendshipRef, {
        'status': FriendshipStatusValues.accepted,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<bool> refuseFriendRequest(String friendshipId) async {
    final friendshipRef = _db
        .collection(FirestoreCollections.friendships)
        .doc(friendshipId);

    return await _db.runTransaction((transaction) async {
      final friendshipDoc = await transaction.get(friendshipRef);

      if (!friendshipDoc.exists || friendshipDoc.data() == null) {
        return false;
      }

      final data = friendshipDoc.data()!;
      final addresseeId = (data['addresseeId'] ?? '').toString();
      final status =
          (data['status'] ?? FriendshipStatusValues.pending).toString();

      if (addresseeId != currentUserId) {
        return false;
      }

      if (status != FriendshipStatusValues.pending) {
        return false;
      }

      transaction.update(friendshipRef, {
        'status': FriendshipStatusValues.refused,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<List<Friendship>> getAcceptedFriendships() async {
    final sentQuery = await _db
        .collection(FirestoreCollections.friendships)
        .where('requesterId', isEqualTo: currentUserId)
        .where('status', isEqualTo: FriendshipStatusValues.accepted)
        .get();

    final receivedQuery = await _db
        .collection(FirestoreCollections.friendships)
        .where('addresseeId', isEqualTo: currentUserId)
        .where('status', isEqualTo: FriendshipStatusValues.accepted)
        .get();

    final sentFriendships = sentQuery.docs
        .map((doc) => Friendship.fromMap(doc.id, doc.data()))
        .toList();

    final receivedFriendships = receivedQuery.docs
        .map((doc) => Friendship.fromMap(doc.id, doc.data()))
        .toList();

    final friendships = [...sentFriendships, ...receivedFriendships];

    friendships.sort((a, b) {
      final aDate = a.respondedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.respondedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return friendships;
  }

  String getOtherUserId(Friendship friendship) {
    return friendship.requesterId == currentUserId
        ? friendship.addresseeId
        : friendship.requesterId;
  }

  String getOtherUserPseudo(Friendship friendship) {
    return friendship.requesterId == currentUserId
        ? friendship.addresseePseudo
        : friendship.requesterPseudo;
  }

  Future<Map<String, dynamic>?> getFriendUserData(Friendship friendship) async {
    final otherUserId = getOtherUserId(friendship);
    return _userService.getUserById(otherUserId);
  }

  Future<bool> removeFriend(String friendshipId) async {
    final friendshipRef = _db
        .collection(FirestoreCollections.friendships)
        .doc(friendshipId);

    return await _db.runTransaction((transaction) async {
      final friendshipDoc = await transaction.get(friendshipRef);

      if (!friendshipDoc.exists || friendshipDoc.data() == null) {
        return false;
      }

      final data = friendshipDoc.data()!;
      final requesterId = (data['requesterId'] ?? '').toString();
      final addresseeId = (data['addresseeId'] ?? '').toString();
      final status =
          (data['status'] ?? FriendshipStatusValues.pending).toString();

      if (requesterId != currentUserId && addresseeId != currentUserId) {
        return false;
      }

      if (status != FriendshipStatusValues.accepted) {
        return false;
      }

      transaction.update(friendshipRef, {
        'status': FriendshipStatusValues.cancelled,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }
  Stream<Friendship?> watchFriendshipWithUser(String otherUserId) {
  return _db
      .collection(FirestoreCollections.friendships)
      .where('requesterId', whereIn: [currentUserId, otherUserId])
      .where('addresseeId', whereIn: [currentUserId, otherUserId])
      .snapshots()
      .map((snapshot) {
    for (final doc in snapshot.docs) {
      final friendship = Friendship.fromMap(doc.id, doc.data());

      final isExactMatch =
          (friendship.requesterId == currentUserId &&
                  friendship.addresseeId == otherUserId) ||
              (friendship.requesterId == otherUserId &&
                  friendship.addresseeId == currentUserId);

      if (isExactMatch) {
        return friendship;
      }
    }

    return null;
  });
}
}