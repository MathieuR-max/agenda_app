import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
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
}