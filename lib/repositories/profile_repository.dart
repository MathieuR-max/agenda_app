import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Stream<UserModel?> watchUser(String userId) {
    return _usersCollection.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<UserModel?> getUser(String userId) async {
    final doc = await _usersCollection.doc(userId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> createOrUpdateUser(UserModel user) async {
    await _usersCollection.doc(user.id).set(user.toMap());
  }

  Future<void> updateFavoriteCategories(
    String userId,
    List<String> categories,
  ) async {
    await _usersCollection.doc(userId).update({
      'favoriteCategories': categories,
    });
  }
}