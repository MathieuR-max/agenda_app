import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';

class UserFirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  UserFirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get currentUserId {
    final uid = _auth.currentUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      throw Exception('No authenticated Firebase user');
    }

    return uid;
  }

  Future<String> getCurrentUserPseudo() async {
    final uid = currentUserId;

    final userDoc = await _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      return (userDoc.data()!['pseudo'] ?? '').toString().trim();
    }

    return '';
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      return null;
    }

    final doc = await _db
        .collection(FirestoreCollections.users)
        .doc(trimmedUserId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final data = doc.data()!;

    return {
      'id': doc.id,
      'pseudo': (data['pseudo'] ?? '').toString().trim(),
      'prenom': (data['prenom'] ?? '').toString().trim(),
      'nom': (data['nom'] ?? '').toString().trim(),
      'lieu': (data['lieu'] ?? data['Lieu'] ?? '').toString().trim(),
      'genre': (data['genre'] ?? '').toString().trim(),
    };
  }
}