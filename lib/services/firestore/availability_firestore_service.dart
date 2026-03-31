import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/availability.dart';
import 'package:agenda_app/services/current_user.dart';

class AvailabilityFirestoreService {
  final FirebaseFirestore _db;

  AvailabilityFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  Future<void> saveAvailability({
    required String type,
    required String title,
    required String note,
    required String visibility,
    required String day,
    required String startTime,
    required String endTime,
  }) async {
    await _db.collection(FirestoreCollections.availabilities).add({
      'type': type,
      'title': title,
      'note': note,
      'visibility': visibility,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'userId': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Availability>> getAvailabilities() {
    return _db
        .collection(FirestoreCollections.availabilities)
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Availability.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> deleteAvailability(String availabilityId) async {
    await _db
        .collection(FirestoreCollections.availabilities)
        .doc(availabilityId)
        .delete();
  }
}