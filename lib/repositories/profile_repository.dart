import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore;

  ProfileRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Stream<UserModel?> watchUser(String userId) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return Stream.value(null);
    }

    return _usersCollection.doc(trimmedUserId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<UserModel?> getUser(String userId) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return null;
    }

    final doc = await _usersCollection.doc(trimmedUserId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> createOrUpdateUser(UserModel user) async {
    final trimmedUserId = user.id.trim();

    if (trimmedUserId.isEmpty) {
      throw ArgumentError('user.id ne peut pas être vide');
    }

    await _usersCollection.doc(trimmedUserId).set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> updateFavoriteCategories(
    String userId,
    List<String> categories,
  ) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      throw ArgumentError('userId ne peut pas être vide');
    }

    await _usersCollection.doc(trimmedUserId).update({
      'favoriteCategories': categories,
    });
  }
  Future<void> updateExplorerFilters(
  String userId,
  Map<String, dynamic> filters,
) async {
  final trimmedUserId = userId.trim();

  if (trimmedUserId.isEmpty) {
    throw ArgumentError('userId ne peut pas être vide');
  }

  await _usersCollection.doc(trimmedUserId).set(
    {
      'explorerFilters': filters,
    },
    SetOptions(merge: true),
  );
}
}