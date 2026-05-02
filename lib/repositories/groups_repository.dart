import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agenda_app/models/group_model.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class GroupsRepository {
  final FirebaseFirestore _db;
  final UserFirestoreService _userService;

  static const String _groupsCollection = 'groups';
  static const String _membersCollection = 'members';

  GroupsRepository({
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

  void _log(String message) {
    debugPrint('GROUPS $message');
  }

  List<String> _extractMemberIds(Map<String, dynamic>? data) {
    if (data == null) {
      return <String>[];
    }

    final raw = data['memberIds'];

    if (raw is Iterable) {
      return raw
          .where((item) => item != null)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  Future<bool> createGroup({
    required String name,
    required String description,
    required String visibility,
  }) async {
    final trimmedName = name.trim();
    final trimmedDescription = description.trim();
    final uid = currentUserId;

    if (trimmedName.isEmpty) {
      return false;
    }

    final ownerPseudo = await _userService.getCurrentUserPseudo();
    final groupRef = _db.collection(_groupsCollection).doc();
    final memberRef = groupRef.collection(_membersCollection).doc(uid);

    return _db.runTransaction((transaction) async {
      transaction.set(groupRef, {
        'name': trimmedName,
        'description': trimmedDescription,
        'ownerId': uid,
        'ownerPseudo': ownerPseudo,
        'visibility': visibility.trim(),
        'memberIds': [uid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(memberRef, {
        'userId': uid,
        'pseudo': ownerPseudo,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Stream<List<GroupModel>> watchMyGroups() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<GroupModel>[]);
    }

    _log('watchMyGroups currentUserId=$uid');

    return _db
        .collection(_groupsCollection)
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      _log('watchMyGroups docs count=${snapshot.docs.length}');

      final groups = snapshot.docs
          .where((doc) => doc.exists && doc.data().isNotEmpty)
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList();

      groups.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      _log('watchMyGroups resultCount=${groups.length}');
      return groups;
    });
  }

  Stream<GroupModel?> watchGroup(String groupId) {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return Stream.value(null);
    }

    return _db
        .collection(_groupsCollection)
        .doc(trimmedGroupId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return GroupModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<GroupModel?> getGroupById(String groupId) async {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return null;
    }

    try {
      final doc =
          await _db.collection(_groupsCollection).doc(trimmedGroupId).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return GroupModel.fromMap(doc.id, doc.data()!);
    } catch (e) {
      _log('Error fetching group by id: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> watchGroupMembers(String groupId) {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _db
        .collection(_groupsCollection)
        .doc(trimmedGroupId)
        .collection(_membersCollection)
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'userId': (data['userId'] ?? '').toString(),
          'pseudo': (data['pseudo'] ?? '').toString(),
          'role': (data['role'] ?? 'member').toString(),
        };
      }).toList();
    });
  }

  Future<bool> isCurrentUserMember(String groupId) async {
    final trimmedGroupId = groupId.trim();
    final uid = currentUserIdOrNull;

    if (uid == null || trimmedGroupId.isEmpty) {
      return false;
    }

    try {
      final groupDoc =
          await _db.collection(_groupsCollection).doc(trimmedGroupId).get();

      if (!groupDoc.exists || groupDoc.data() == null) {
        return false;
      }

      final memberIds = _extractMemberIds(groupDoc.data());
      return memberIds.contains(uid);
    } catch (e) {
      _log('Error checking current user membership: $e');
      return false;
    }
  }

  Future<bool> isUserMember(String groupId, String userId) async {
    final trimmedGroupId = groupId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedGroupId.isEmpty || trimmedUserId.isEmpty) {
      return false;
    }

    try {
      final groupDoc =
          await _db.collection(_groupsCollection).doc(trimmedGroupId).get();

      if (!groupDoc.exists || groupDoc.data() == null) {
        return false;
      }

      final memberIds = _extractMemberIds(groupDoc.data());
      return memberIds.contains(trimmedUserId);
    } catch (e) {
      _log('Error checking user membership: $e');
      return false;
    }
  }

  Future<List<String>> getGroupMemberIds(String groupId) async {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return <String>[];
    }

    try {
      final groupDoc =
          await _db.collection(_groupsCollection).doc(trimmedGroupId).get();

      if (groupDoc.exists && groupDoc.data() != null) {
        final memberIds = _extractMemberIds(groupDoc.data());
        if (memberIds.isNotEmpty) {
          return memberIds;
        }
      }

      final snapshot = await _db
          .collection(_groupsCollection)
          .doc(trimmedGroupId)
          .collection(_membersCollection)
          .get();

      return snapshot.docs
          .map((doc) => (doc.data()['userId'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      _log('Error fetching group member ids: $e');
      return <String>[];
    }
  }

  Future<bool> addMember({
    required String groupId,
    required String userId,
  }) async {
    final trimmedGroupId = groupId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedGroupId.isEmpty || trimmedUserId.isEmpty) {
      return false;
    }

    final groupRef = _db.collection(_groupsCollection).doc(trimmedGroupId);
    final memberRef = groupRef.collection(_membersCollection).doc(trimmedUserId);

    final userData = await _userService.getUserById(trimmedUserId);

    if (userData == null) {
      return false;
    }

    final pseudo = (userData['pseudo'] ?? '').toString();

    return _db.runTransaction((transaction) async {
      final groupDoc = await transaction.get(groupRef);

      if (!groupDoc.exists) {
        return false;
      }

      final existingMember = await transaction.get(memberRef);

      if (existingMember.exists) {
        return false;
      }

      final groupData = groupDoc.data();
      final memberIds = _extractMemberIds(groupData);

      if (!memberIds.contains(trimmedUserId)) {
        memberIds.add(trimmedUserId);
      }

      transaction.set(memberRef, {
        'userId': trimmedUserId,
        'pseudo': pseudo,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(groupRef, {
        'memberIds': memberIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<bool> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final trimmedGroupId = groupId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedGroupId.isEmpty || trimmedUserId.isEmpty) {
      return false;
    }

    final groupRef = _db.collection(_groupsCollection).doc(trimmedGroupId);
    final memberRef = groupRef.collection(_membersCollection).doc(trimmedUserId);

    return _db.runTransaction((transaction) async {
      final groupDoc = await transaction.get(groupRef);
      final memberDoc = await transaction.get(memberRef);

      if (!groupDoc.exists || !memberDoc.exists) {
        return false;
      }

      final groupData = groupDoc.data();
      final ownerId = (groupData?['ownerId'] ?? '').toString().trim();

      if (trimmedUserId == ownerId) {
        return false;
      }

      final memberIds = _extractMemberIds(groupData)
        ..removeWhere((id) => id == trimmedUserId);

      transaction.delete(memberRef);

      transaction.update(groupRef, {
        'memberIds': memberIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<bool> leaveGroup({
    required String groupId,
  }) async {
    final trimmedGroupId = groupId.trim();
    final uid = currentUserIdOrNull;

    if (trimmedGroupId.isEmpty || uid == null) {
      return false;
    }

    final groupRef = _db.collection(_groupsCollection).doc(trimmedGroupId);
    final memberRef = groupRef.collection(_membersCollection).doc(uid);

    return _db.runTransaction((transaction) async {
      final groupDoc = await transaction.get(groupRef);
      final memberDoc = await transaction.get(memberRef);

      if (!groupDoc.exists || !memberDoc.exists) {
        return false;
      }

      final memberData = memberDoc.data();
      final role = (memberData?['role'] ?? 'member').toString();

      if (role == 'owner') {
        return false;
      }

      final groupData = groupDoc.data();
      final memberIds = _extractMemberIds(groupData)
        ..removeWhere((id) => id == uid);

      transaction.delete(memberRef);

      transaction.update(groupRef, {
        'memberIds': memberIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<void> touchGroup(String groupId) async {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return;
    }

    await _db.collection(_groupsCollection).doc(trimmedGroupId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}