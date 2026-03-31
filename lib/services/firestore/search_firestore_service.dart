import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/services/current_user.dart';

class SearchFirestoreService {
  final FirebaseFirestore _db;

  SearchFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  Future<void> saveSearch({
    required String day,
    required String startTime,
    required String endTime,
    required String category,
  }) async {
    await _db.collection(FirestoreCollections.searches).add({
      'userId': currentUserId,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSearches() {
    return _db
        .collection(FirestoreCollections.searches)
        .where('userId', isEqualTo: currentUserId)
        .snapshots();
  }

  Future<void> deleteSearch(String searchId) async {
    await _db.collection(FirestoreCollections.searches).doc(searchId).delete();
  }
}