import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'PlusJakartaSans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4A6),
          primary: const Color(0xFF00B4A6),
          secondary: const Color(0xFFF9635E),
          surface: const Color(0xFFF8F7F4),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7F4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E1E1E),
          ),
          iconTheme: IconThemeData(color: Color(0xFF6F6F6F)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          margin: EdgeInsets.zero,
          shadowColor: Color(0x0A000000),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B4A6),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            textStyle: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF00B4A6),
          unselectedItemColor: Color(0xFFA8A8A8),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF1EFEB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          labelStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE6E2DB),
          thickness: 0.5,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1EFEB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE6E2DB), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE6E2DB), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF00B4A6), width: 1.5),
          ),
        ),
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