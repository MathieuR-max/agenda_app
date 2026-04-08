import 'package:flutter/material.dart';
import '../models/activity_invitation.dart';
import '../services/firestore/activity_invitation_firestore_service.dart';
import '02_calendar/calendar_page.dart';
import '03_activities/all_activities_page.dart';
import '03_activities/invitations_page.dart';
import '04_profile/my_profile_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  final ActivityInvitationFirestoreService invitationService =
      ActivityInvitationFirestoreService();

  int _currentIndex = 0;

  final List<Widget> _pages = const [
    CalendarPage(),
    AllActivitiesPage(),
    InvitationsPage(),
    MyProfilePage(),
  ];

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _handleBackNavigation(bool didPop) async {
    if (didPop) return;

    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  Widget _buildInvitationsIcon({
    required bool selected,
  }) {
    return StreamBuilder<List<ActivityInvitation>>(
      stream: invitationService.getPendingReceivedInvitations(),
      builder: (context, snapshot) {
        final pendingCount = (snapshot.data ?? []).length;
        final baseIcon = Icon(
          selected ? Icons.mail : Icons.mail_outline,
        );

        if (pendingCount <= 0) {
          return baseIcon;
        }

        return Badge(
          label: Text(
            pendingCount > 99 ? '99+' : '$pendingCount',
          ),
          child: baseIcon,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: _handleBackNavigation,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Agenda',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explorer',
            ),
            NavigationDestination(
              icon: _buildInvitationsIcon(selected: false),
              selectedIcon: _buildInvitationsIcon(selected: true),
              label: 'Invitations',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}