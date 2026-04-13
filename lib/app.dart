import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/features/01_auth/test_user_selector_page.dart';
import 'package:agenda_app/features/main_navigation_page.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/notification_token_service.dart';

class AgendaApp extends StatefulWidget {
  const AgendaApp({super.key});

  @override
  State<AgendaApp> createState() => _AgendaAppState();
}

class _AgendaAppState extends State<AgendaApp> {
  final NotificationTokenService _tokenService = NotificationTokenService();

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

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened app: ${message.data}');
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state: ${initialMessage.data}');
    }

    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: CurrentUser.isSet
    ? MainNavigationPage(key: ValueKey('main_nav_${CurrentUser.id}'))
    : const TestUserSelectorPage(),
    );
  }
}