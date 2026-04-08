import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/services/current_user.dart';

class ActivityInvitationFirestoreService {
  final FirebaseFirestore _db;

  ActivityInvitationFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _db.collection(FirestoreCollections.activityInvitations);

  Stream<List<ActivityInvitation>> getReceivedInvitations() {
    return _invitations
        .where('toUserId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityInvitation.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ActivityInvitation>> getPendingReceivedInvitations() {
    return _invitations
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: ActivityInvitation.statusPending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityInvitation.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ActivityInvitation>> getSentInvitationsForActivity(
    String activityId,
  ) {
    final trimmedActivityId = activityId.trim();

    if (trimmedActivityId.isEmpty) {
      return Stream.value(<ActivityInvitation>[]);
    }

    return _invitations
        .where('activityId', isEqualTo: trimmedActivityId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityInvitation.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ActivityInvitation>> getSentInvitations() {
    return _invitations
        .where('fromUserId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityInvitation.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }
}