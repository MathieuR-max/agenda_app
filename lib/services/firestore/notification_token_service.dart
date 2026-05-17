import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/services/current_user.dart';

class NotificationTokenService {
  final FirebaseFirestore _db;

  NotificationTokenService({
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  String? get currentUserIdOrNull {
    final uid = AuthUser.uidOrNull?.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  Future<void> init() async {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return;
    }

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
    final trimmedUserId = currentUserIdOrNull;
    final trimmedToken = token.trim();

    if (trimmedUserId == null || trimmedToken.isEmpty) {
      return;
    }

    final deviceId = _buildDeviceId(trimmedToken);

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