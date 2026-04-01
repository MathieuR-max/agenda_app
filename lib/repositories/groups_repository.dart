import 'package:cloud_firestore/cloud_firestore.dart';
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

  String get currentUserId => CurrentUser.id;

  Future<bool> createGroup({
    required String name,
    required String description,
    required String visibility,
  }) async {
    final trimmedName = name.trim();
    final trimmedDescription = description.trim();

    if (trimmedName.isEmpty) {
      return false;
    }

    final ownerPseudo = await _userService.getCurrentUserPseudo();
    final groupRef = _db.collection(_groupsCollection).doc();
    final memberRef = groupRef.collection(_membersCollection).doc(currentUserId);

    return _db.runTransaction((transaction) async {
      transaction.set(groupRef, {
        'name': trimmedName,
        'description': trimmedDescription,
        'ownerId': currentUserId,
        'ownerPseudo': ownerPseudo,
        'visibility': visibility,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(memberRef, {
        'userId': currentUserId,
        'pseudo': ownerPseudo,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Stream<List<GroupModel>> watchMyGroups() {
    return _db.collection(_groupsCollection).snapshots().asyncMap((snapshot) async {
      final groups = <GroupModel>[];

      for (final doc in snapshot.docs) {
        final memberDoc = await doc.reference
            .collection(_membersCollection)
            .doc(currentUserId)
            .get();

        if (memberDoc.exists) {
          groups.add(GroupModel.fromMap(doc.id, doc.data()));
        }
      }

      groups.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      return groups;
    });
  }

  Stream<GroupModel?> watchGroup(String groupId) {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return Stream.value(null);
    }

    return _db.collection(_groupsCollection).doc(trimmedGroupId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return GroupModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<Map<String, dynamic>>> watchGroupMembers(String groupId) {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return Stream.value([]);
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

    if (trimmedGroupId.isEmpty) {
      return false;
    }

    final memberDoc = await _db
        .collection(_groupsCollection)
        .doc(trimmedGroupId)
        .collection(_membersCollection)
        .doc(currentUserId)
        .get();

    return memberDoc.exists;
  }

  Future<bool> isUserMember(String groupId, String userId) async {
    final trimmedGroupId = groupId.trim();
    final trimmedUserId = userId.trim();

    if (trimmedGroupId.isEmpty || trimmedUserId.isEmpty) {
      return false;
    }

    final memberDoc = await _db
        .collection(_groupsCollection)
        .doc(trimmedGroupId)
        .collection(_membersCollection)
        .doc(trimmedUserId)
        .get();

    return memberDoc.exists;
  }

  Future<List<String>> getGroupMemberIds(String groupId) async {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return [];
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

      transaction.set(memberRef, {
        'userId': trimmedUserId,
        'pseudo': pseudo,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(groupRef, {
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

      final ownerId = (groupDoc.data()?['ownerId'] ?? '').toString();

      if (trimmedUserId == ownerId) {
        return false;
      }

      transaction.delete(memberRef);
      transaction.update(groupRef, {
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<bool> leaveGroup({
    required String groupId,
  }) async {
    final trimmedGroupId = groupId.trim();

    if (trimmedGroupId.isEmpty) {
      return false;
    }

    final groupRef = _db.collection(_groupsCollection).doc(trimmedGroupId);
    final memberRef = groupRef.collection(_membersCollection).doc(currentUserId);

    return _db.runTransaction((transaction) async {
      final groupDoc = await transaction.get(groupRef);
      final memberDoc = await transaction.get(memberRef);

      if (!groupDoc.exists || !memberDoc.exists) {
        return false;
      }

      final data = memberDoc.data();
      final role = (data?['role'] ?? 'member').toString();

      if (role == 'owner') {
        return false;
      }

      transaction.delete(memberRef);
      transaction.update(groupRef, {
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