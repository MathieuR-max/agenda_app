import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationRepository {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<int> watchUnreadMatchCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('type', isEqualTo: 'activity_match')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((_) => 0);
  }

  Future<void> markActivityMatchesAsRead() async {
    try {
      final uid = _uid;
      if (uid == null) return;
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('type', isEqualTo: 'activity_match')
          .where('read', isEqualTo: false)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final uid = _uid;
      if (uid == null || notificationId.trim().isEmpty) return;
      await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('NOTIF_REPO markNotificationAsRead error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActivityMatchNotifications() async {
    try {
      final uid = _uid;
      if (uid == null) return [];
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('type', isEqualTo: 'activity_match')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'activityId': d['activityId'] ?? '',
          'activityTitle': d['activityTitle'] ?? '',
          'searchId': d['searchId'] ?? '',
          'category': d['category'] ?? '',
          'read': d['read'] ?? false,
          'createdAt': d['createdAt'],
        };
      }).toList();
    } catch (e) {
      debugPrint('NOTIF_REPO error: $e');
      return [];
    }
  }
}
