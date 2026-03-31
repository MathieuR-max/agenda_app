import 'package:flutter/material.dart';
import 'features/01_auth/login_page.dart';
import 'features/01_auth/signup_page.dart';
import 'features/02_calendar/calendar_page.dart';

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/calendar',
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/calendar': (context) => CalendarPage(),
      },
    );
  }
}