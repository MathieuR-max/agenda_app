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

  /// Writes only the fields the user can edit from their profile page.
  /// Never touches pseudo, explorerFilters, centresInteret, or uid.
  Future<void> updateProfile({
    required String userId,
    required String prenom,
    required String nom,
    required String lieu,
    required String genre,
    required String dateNaissance,
    required String bio,
    required List<String> favoriteCategories,
    String? photoUrl,
  }) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      throw ArgumentError('userId ne peut pas être vide');
    }

    if (prenom.trim().isEmpty) {
      throw ArgumentError('Le prénom est obligatoire');
    }

    await _usersCollection.doc(trimmedUserId).set(
      {
        'prenom': prenom.trim(),
        'nom': nom.trim(),
        'lieu': lieu.trim(),
        'genre': genre.trim(),
        'dateNaissance': dateNaissance.trim(),
        'bio': bio.trim(),
        'favoriteCategories': favoriteCategories,
        'photoUrl': photoUrl?.trim() ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
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
      'updatedAt': FieldValue.serverTimestamp(),
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
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
