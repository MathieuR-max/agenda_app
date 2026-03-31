import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/services/current_user.dart';

class UserFirestoreService {
  final FirebaseFirestore _db;

  UserFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  Future<String> getCurrentUserPseudo() async {
    final userDoc = await _db
        .collection(FirestoreCollections.users)
        .doc(currentUserId)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      return (userDoc.data()!['pseudo'] ?? '').toString();
    }

    return '';
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final doc =
        await _db.collection(FirestoreCollections.users).doc(userId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final data = doc.data()!;

    return {
      'id': doc.id,
      'pseudo': data['pseudo'] ?? '',
      'prenom': data['prenom'] ?? '',
      'nom': data['nom'] ?? '',
      'lieu': data['lieu'] ?? data['Lieu'] ?? '',
      'genre': data['genre'] ?? '',
    };
  }
}