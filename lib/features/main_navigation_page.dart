import 'package:flutter/material.dart';
import '../models/activity_invitation.dart';
import '../repositories/message_badge_repository.dart';
import '../services/current_user.dart';
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
  int _currentIndex = 0;

  late final ActivityInvitationFirestoreService _invitationService;
  late final MessageBadgeRepository _messageBadgeRepository;

  @override
  void initState() {
    super.initState();
    _invitationService = ActivityInvitationFirestoreService();
    _messageBadgeRepository = MessageBadgeRepository();
  }

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

  List<Widget> _buildPages() {
    final userKey = ValueKey('pages_${CurrentUser.id}');

    return [
      CalendarPage(key: ValueKey('calendar_${userKey.value}')),
      AllActivitiesPage(key: ValueKey('explorer_${userKey.value}')),
      InvitationsPage(key: ValueKey('invitations_${userKey.value}')),
      MyProfilePage(key: ValueKey('profile_${userKey.value}')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: _handleBackNavigation,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
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
            NavigationDestination(
              icon: _MessagesNavIcon(
                selected: false,
                isCurrentTab: _currentIndex == 1,
                messageBadgeRepository: _messageBadgeRepository,
              ),
              selectedIcon: _MessagesNavIcon(
                selected: true,
                isCurrentTab: _currentIndex == 1,
                messageBadgeRepository: _messageBadgeRepository,
              ),
              label: 'Explorer',
            ),
            NavigationDestination(
              icon: _InvitationsNavIcon(
                selected: false,
                isCurrentTab: _currentIndex == 2,
                invitationService: _invitationService,
              ),
              selectedIcon: _InvitationsNavIcon(
                selected: true,
                isCurrentTab: _currentIndex == 2,
                invitationService: _invitationService,
              ),
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

class _MessagesNavIcon extends StatelessWidget {
  final bool selected;
  final bool isCurrentTab;
  final MessageBadgeRepository messageBadgeRepository;

  const _MessagesNavIcon({
    required this.selected,
    required this.isCurrentTab,
    required this.messageBadgeRepository,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: messageBadgeRepository.watchTotalUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return _NavBadgeIcon(
          icon: Icon(
            selected ? Icons.explore : Icons.explore_outlined,
          ),
          count: unreadCount,
          hideBadge: isCurrentTab,
        );
      },
    );
  }
}

class _InvitationsNavIcon extends StatelessWidget {
  final bool selected;
  final bool isCurrentTab;
  final ActivityInvitationFirestoreService invitationService;

  const _InvitationsNavIcon({
    required this.selected,
    required this.isCurrentTab,
    required this.invitationService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityInvitation>>(
      stream: invitationService.getPendingReceivedInvitations(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.length ?? 0;

        return _NavBadgeIcon(
          icon: Icon(
            selected ? Icons.mail : Icons.mail_outline,
          ),
          count: pendingCount,
          hideBadge: isCurrentTab,
        );
      },
    );
  }
}

class _NavBadgeIcon extends StatelessWidget {
  final Widget icon;
  final int count;
  final bool hideBadge;

  const _NavBadgeIcon({
    required this.icon,
    required this.count,
    this.hideBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (hideBadge || count <= 0) {
      return icon;
    }

    return Badge(
      label: Text(
        count > 99 ? '99+' : '$count',
      ),
      child: icon,
    );
  }
}