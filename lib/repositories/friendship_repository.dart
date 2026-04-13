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

  String get currentUserId => CurrentUser.id.trim();

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection(FirestoreCollections.friendships);

  bool get _hasCurrentUser => currentUserId.isNotEmpty;

  Future<bool> sendFriendRequest({
    required String toUserId,
  }) async {
    final trimmedToUserId = toUserId.trim();

    if (!_hasCurrentUser || trimmedToUserId.isEmpty) {
      return false;
    }

    if (trimmedToUserId == currentUserId) {
      return false;
    }

    final currentUserPseudo = await _userService.getCurrentUserPseudo();
    final toUserRef = _db.collection(FirestoreCollections.users).doc(trimmedToUserId);

    return _db.runTransaction((transaction) async {
      final toUserDoc = await transaction.get(toUserRef);

      if (!toUserDoc.exists || toUserDoc.data() == null) {
        return false;
      }

      final toUserPseudo = (toUserDoc.data()!['pseudo'] ?? '').toString().trim();

      final existingRequest1 = await _friendships
          .where('requesterId', isEqualTo: currentUserId)
          .where('addresseeId', isEqualTo: trimmedToUserId)
          .limit(1)
          .get();

      final existingRequest2 = await _friendships
          .where('requesterId', isEqualTo: trimmedToUserId)
          .where('addresseeId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existingRequest1.docs.isNotEmpty || existingRequest2.docs.isNotEmpty) {
        return false;
      }

      final friendshipRef = _friendships.doc();

      transaction.set(friendshipRef, {
        'requesterId': currentUserId,
        'requesterPseudo': currentUserPseudo.trim(),
        'addresseeId': trimmedToUserId,
        'addresseePseudo': toUserPseudo,
        'status': FriendshipStatusValues.pending,
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      return true;
    });
  }

  Future<bool> acceptFriendRequest(String friendshipId) async {
    final trimmedFriendshipId = friendshipId.trim();

    if (!_hasCurrentUser || trimmedFriendshipId.isEmpty) {
      return false;
    }

    final friendshipRef = _friendships.doc(trimmedFriendshipId);

    return _db.runTransaction((transaction) async {
      final friendshipDoc = await transaction.get(friendshipRef);

      if (!friendshipDoc.exists || friendshipDoc.data() == null) {
        return false;
      }

      final data = friendshipDoc.data()!;
      final addresseeId = (data['addresseeId'] ?? '').toString().trim();
      final status =
          (data['status'] ?? FriendshipStatusValues.pending).toString().trim();

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
    final trimmedFriendshipId = friendshipId.trim();

    if (!_hasCurrentUser || trimmedFriendshipId.isEmpty) {
      return false;
    }

    final friendshipRef = _friendships.doc(trimmedFriendshipId);

    return _db.runTransaction((transaction) async {
      final friendshipDoc = await transaction.get(friendshipRef);

      if (!friendshipDoc.exists || friendshipDoc.data() == null) {
        return false;
      }

      final data = friendshipDoc.data()!;
      final addresseeId = (data['addresseeId'] ?? '').toString().trim();
      final status =
          (data['status'] ?? FriendshipStatusValues.pending).toString().trim();

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
    if (!_hasCurrentUser) {
      return <Friendship>[];
    }

    final sentQuery = await _friendships
        .where('requesterId', isEqualTo: currentUserId)
        .where('status', isEqualTo: FriendshipStatusValues.accepted)
        .get();

    final receivedQuery = await _friendships
        .where('addresseeId', isEqualTo: currentUserId)
        .where('status', isEqualTo: FriendshipStatusValues.accepted)
        .get();

    final Map<String, Friendship> byId = <String, Friendship>{};

    for (final doc in sentQuery.docs) {
      byId[doc.id] = Friendship.fromMap(doc.id, doc.data());
    }

    for (final doc in receivedQuery.docs) {
      byId[doc.id] = Friendship.fromMap(doc.id, doc.data());
    }

    final friendships = byId.values.toList();
    _sortFriendshipsByRecentResponse(friendships);

    return friendships;
  }

  String getOtherUserId(Friendship friendship) {
    final requesterId = friendship.requesterId.trim();
    final addresseeId = friendship.addresseeId.trim();

    if (requesterId == currentUserId) {
      return addresseeId;
    }

    return requesterId;
  }

  String getOtherUserPseudo(Friendship friendship) {
    final requesterId = friendship.requesterId.trim();

    if (requesterId == currentUserId) {
      return friendship.addresseePseudo.trim();
    }

    return friendship.requesterPseudo.trim();
  }

  Future<Map<String, dynamic>?> getFriendUserData(Friendship friendship) async {
    final otherUserId = getOtherUserId(friendship).trim();

    if (otherUserId.isEmpty) {
      return null;
    }

    return _userService.getUserById(otherUserId);
  }

  Future<bool> removeFriend(String friendshipId) async {
    final trimmedFriendshipId = friendshipId.trim();

    if (!_hasCurrentUser || trimmedFriendshipId.isEmpty) {
      return false;
    }

    final friendshipRef = _friendships.doc(trimmedFriendshipId);

    return _db.runTransaction((transaction) async {
      final friendshipDoc = await transaction.get(friendshipRef);

      if (!friendshipDoc.exists || friendshipDoc.data() == null) {
        return false;
      }

      final data = friendshipDoc.data()!;
      final requesterId = (data['requesterId'] ?? '').toString().trim();
      final addresseeId = (data['addresseeId'] ?? '').toString().trim();
      final status =
          (data['status'] ?? FriendshipStatusValues.pending).toString().trim();

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
    final trimmedOtherUserId = otherUserId.trim();

    if (!_hasCurrentUser || trimmedOtherUserId.isEmpty) {
      return Stream.value(null);
    }

    return _friendships
        .where('requesterId', whereIn: [currentUserId, trimmedOtherUserId])
        .where('addresseeId', whereIn: [currentUserId, trimmedOtherUserId])
        .snapshots()
        .map((snapshot) {
      Friendship? matched;

      for (final doc in snapshot.docs) {
        final friendship = Friendship.fromMap(doc.id, doc.data());

        final requesterId = friendship.requesterId.trim();
        final addresseeId = friendship.addresseeId.trim();

        final isExactMatch =
            (requesterId == currentUserId && addresseeId == trimmedOtherUserId) ||
                (requesterId == trimmedOtherUserId &&
                    addresseeId == currentUserId);

        if (!isExactMatch) {
          continue;
        }

        if (matched == null) {
          matched = friendship;
          continue;
        }

        final matchedDate =
            matched.respondedAt ?? matched.createdAt ?? DateTime(2000);
        final friendshipDate =
            friendship.respondedAt ?? friendship.createdAt ?? DateTime(2000);

        if (friendshipDate.isAfter(matchedDate)) {
          matched = friendship;
        }
      }

      return matched;
    });
  }

  void _sortFriendshipsByRecentResponse(List<Friendship> friendships) {
    friendships.sort((a, b) {
      final aDate = a.respondedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.respondedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
  }
}