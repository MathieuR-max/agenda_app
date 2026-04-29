import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/core/utils/app_navigator.dart';
import 'package:agenda_app/features/01_auth/test_user_selector_page.dart';
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

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _tokenService.init();

    final token = await messaging.getToken();
    debugPrint('FCM token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;

      if (!mounted || notification == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notification.body?.trim().isNotEmpty == true
                ? notification.body!
                : (notification.title ?? 'Nouvelle notification'),
          ),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _notificationNavigationService.init();
    });

    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
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
    _userBootstrapFuture = _ensureUserDocument(firebaseUser);

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
            return const TestUserSelectorPage();
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