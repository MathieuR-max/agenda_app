import 'package:flutter/material.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/features/01_auth/test_user_selector_page.dart';
import 'features/main_navigation_page.dart';

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: CurrentUser.isSet
          ? const MainNavigationPage()
          : const TestUserSelectorPage(),
    );
  }
}