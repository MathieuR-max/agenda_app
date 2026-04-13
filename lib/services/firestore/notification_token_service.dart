import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/services/current_user.dart';

class NotificationTokenService {
  final FirebaseFirestore _db;

  NotificationTokenService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id.trim();

  Future<void> init() async {
    if (currentUserId.isEmpty) return;

    final messaging = FirebaseMessaging.instance;

    final token = await messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _saveToken(token);
    }

    messaging.onTokenRefresh.listen((newToken) async {
      if (newToken.trim().isEmpty) return;
      await _saveToken(newToken);
    });
  }

  Future<void> _saveToken(String token) async {
    final trimmedUserId = currentUserId;
    final trimmedToken = token.trim();

    if (trimmedUserId.isEmpty || trimmedToken.isEmpty) {
      return;
    }

    final deviceId = _buildDeviceId(trimmedToken);

    await _removeTokenFromOtherUsers(
      token: trimmedToken,
      currentUserId: trimmedUserId,
    );

    await _db
        .collection(FirestoreCollections.users)
        .doc(trimmedUserId)
        .collection('devices')
        .doc(deviceId)
        .set({
      'token': trimmedToken,
      'platform': _platformLabel(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeTokenFromOtherUsers({
    required String token,
    required String currentUserId,
  }) async {
    final snapshot = await _db
        .collectionGroup('devices')
        .where('token', isEqualTo: token)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      final ownerUserId = doc.reference.parent.parent?.id?.trim() ?? '';

      if (ownerUserId.isEmpty) {
        continue;
      }

      if (ownerUserId == currentUserId) {
        continue;
      }

      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  String _buildDeviceId(String token) {
    if (token.length <= 20) {
      return token;
    }
    return token.substring(0, 20);
  }

  String _platformLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}