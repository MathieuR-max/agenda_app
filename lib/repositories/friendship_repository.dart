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

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection(FirestoreCollections.friendships);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreCollections.users);

  Future<bool> sendFriendRequest({
    required String toUserId,
  }) async {
    final uid = currentUserIdOrNull;
    final trimmedToUserId = toUserId.trim();

    if (uid == null || trimmedToUserId.isEmpty) {
      return false;
    }

    if (trimmedToUserId == uid) {
      return false;
    }

    final currentUserPseudo = await _userService.getCurrentUserPseudo();
    final toUserRef = _users.doc(trimmedToUserId);

    final existingRequest1 = await _friendships
        .where('requesterId', isEqualTo: uid)
        .where('addresseeId', isEqualTo: trimmedToUserId)
        .limit(1)
        .get();

    final existingRequest2 = await _friendships
        .where('requesterId', isEqualTo: trimmedToUserId)
        .where('addresseeId', isEqualTo: uid)
        .limit(1)
        .get();

    if (existingRequest1.docs.isNotEmpty || existingRequest2.docs.isNotEmpty) {
      return false;
    }

    return _db.runTransaction((transaction) async {
      final toUserDoc = await transaction.get(toUserRef);

      if (!toUserDoc.exists || toUserDoc.data() == null) {
        return false;
      }

      final toUserData = toUserDoc.data()!;
      final toUserPseudo = (toUserData['pseudo'] ?? '').toString().trim();

      final friendshipRef = _friendships.doc();

      transaction.set(friendshipRef, {
        'requesterId': uid,
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
    final uid = currentUserIdOrNull;
    final trimmedFriendshipId = friendshipId.trim();

    if (uid == null || trimmedFriendshipId.isEmpty) {
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

      if (addresseeId != uid) {
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
    final uid = currentUserIdOrNull;
    final trimmedFriendshipId = friendshipId.trim();

    if (uid == null || trimmedFriendshipId.isEmpty) {
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

      if (addresseeId != uid) {
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
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return <Friendship>[];
    }

    final sentQuery = await _friendships
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: FriendshipStatusValues.accepted)
        .get();

    final receivedQuery = await _friendships
        .where('addresseeId', isEqualTo: uid)
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
    final uid = currentUserId;
    final requesterId = friendship.requesterId.trim();
    final addresseeId = friendship.addresseeId.trim();

    if (requesterId == uid) {
      return addresseeId;
    }

    return requesterId;
  }

  String getOtherUserPseudo(Friendship friendship) {
    final uid = currentUserId;
    final requesterId = friendship.requesterId.trim();

    if (requesterId == uid) {
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
    final uid = currentUserIdOrNull;
    final trimmedFriendshipId = friendshipId.trim();

    if (uid == null || trimmedFriendshipId.isEmpty) {
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

      if (requesterId != uid && addresseeId != uid) {
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
    final uid = currentUserIdOrNull;
    final other = otherUserId.trim();

    if (uid == null || other.isEmpty) {
      return Stream.value(null);
    }

    final sentQuery = _friendships
        .where('requesterId', isEqualTo: uid)
        .where('addresseeId', isEqualTo: other);

    final receivedQuery = _friendships
        .where('requesterId', isEqualTo: other)
        .where('addresseeId', isEqualTo: uid);

    return sentQuery.snapshots().asyncMap((sentSnapshot) async {
      final receivedSnapshot = await receivedQuery.get();

      final friendships = <Friendship>[
        ...sentSnapshot.docs
            .map((doc) => Friendship.fromMap(doc.id, doc.data())),
        ...receivedSnapshot.docs
            .map((doc) => Friendship.fromMap(doc.id, doc.data())),
      ];

      if (friendships.isEmpty) {
        return null;
      }

      _sortFriendshipsByRecentResponse(friendships);
      return friendships.first;
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