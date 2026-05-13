import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/core/utils/app_navigator.dart';
import 'package:agenda_app/features/01_auth/login_page.dart';
import 'package:agenda_app/features/main_navigation_page.dart';
import 'package:agenda_app/services/firestore/notification_token_service.dart';
import 'package:agenda_app/services/notification_navigation_service.dart';

class AgendaApp extends StatefulWidget {
  const AgendaApp({super.key});

  @override
  State<AgendaApp> createState() => _AgendaAppState();
}

class _AgendaAppState extends State<AgendaApp> {
  final NotificationTokenService _tokenService = NotificationTokenService();
  final NotificationNavigationService _notificationNavigationService =
      NotificationNavigationService();

  Future<void>? _userBootstrapFuture;
  String? _bootstrappedUid;

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool _notificationsInitialized = false;
  bool _notificationNavigationInitialized = false;

  @override
  void initState() {
    super.initState();
    _initNotificationsOnce();
  }

  @override
  void dispose() {
    _foregroundMessageSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initNotificationsOnce() async {
    if (_notificationsInitialized) return;
    _notificationsInitialized = true;

    // ✅ FIX : désactive FCM sur le web
    if (kIsWeb) {
      debugPrint('FCM désactivé sur Flutter Web.');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    debugPrint('FCM token: $token');

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      (message) {
        final notification = message.notification;

        if (!mounted || notification == null) return;

        final body = notification.body?.trim();
        final title = notification.title?.trim();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body?.isNotEmpty == true
                  ? body!
                  : title?.isNotEmpty == true
                      ? title!
                      : 'Nouvelle notification',
            ),
          ),
        );
      },
    );

    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_notificationNavigationInitialized) return;
      _notificationNavigationInitialized = true;

      await _notificationNavigationService.init();
    });
  }

  String _pseudoFromEmail(String? email) {
    final normalized = (email ?? '').trim().toLowerCase();

    if (normalized.startsWith('pierre@')) return 'Pierre';
    if (normalized.startsWith('alex@')) return 'Alex';
    if (normalized.startsWith('jack@')) return 'Jack';

    final localPart = normalized.split('@').first.trim();

    if (localPart.isEmpty) {
      return 'Utilisateur';
    }

    return localPart[0].toUpperCase() + localPart.substring(1);
  }

  Future<void> _ensureUserDocument(User firebaseUser) async {
    final uid = firebaseUser.uid.trim();

    if (uid.isEmpty) {
      return;
    }

    final userRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid);

    final snapshot = await userRef.get();
    final pseudo = _pseudoFromEmail(firebaseUser.email);

    if (!snapshot.exists || snapshot.data() == null) {
      await userRef.set({
        'pseudo': pseudo,
        'prenom': '',
        'nom': '',
        'lieu': '',
        'genre': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    final data = snapshot.data()!;
    final updates = <String, dynamic>{};

    final existingPseudo = (data['pseudo'] ?? '').toString().trim();

    if (existingPseudo.isEmpty) {
      updates['pseudo'] = pseudo;
    }

    if (!data.containsKey('prenom')) {
      updates['prenom'] = '';
    }

    if (!data.containsKey('nom')) {
      updates['nom'] = '';
    }

    if (!data.containsKey('lieu') && !data.containsKey('Lieu')) {
      updates['lieu'] = '';
    }

    if (!data.containsKey('genre')) {
      updates['genre'] = '';
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await userRef.set(updates, SetOptions(merge: true));
    }
  }

  Future<void> _bootstrapUserIfNeeded(User firebaseUser) {
    final uid = firebaseUser.uid.trim();

    if (_bootstrappedUid == uid && _userBootstrapFuture != null) {
      return _userBootstrapFuture!;
    }

    _bootstrappedUid = uid;

    _userBootstrapFuture = Future(() async {
      await _ensureUserDocument(firebaseUser);

      // ✅ FIX : pas de token sur le web
      if (!kIsWeb) {
        await _tokenService.init();
      }
    });

    return _userBootstrapFuture!;
  }

  void _resetBootstrap() {
    _userBootstrapFuture = null;
    _bootstrappedUid = null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Agenda App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final firebaseUser = snapshot.data;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (firebaseUser == null) {
            _resetBootstrap();
            return const LoginPage();
          }

          return FutureBuilder<void>(
            future: _bootstrapUserIfNeeded(firebaseUser),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (userSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erreur initialisation utilisateur : ${userSnapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }

              return MainNavigationPage(
                key: ValueKey('main_nav_${firebaseUser.uid}'),
              );
            },
          );
        },
      ),
    );
  }
}