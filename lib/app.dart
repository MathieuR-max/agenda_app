import 'package:flutter/material.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/features/01_auth/test_user_selector_page.dart';
import 'package:agenda_app/features/02_calendar/calendar_page.dart';

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda App',
      debugShowCheckedModeBanner: false,
      home: CurrentUser.isSet
          ? const CalendarPage()
          : const TestUserSelectorPage(),
    );
  }
}