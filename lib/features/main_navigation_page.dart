import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/activity_invitation.dart';
import '../models/friendship.dart';
import '../models/group_invitation.dart';
import '../repositories/message_badge_repository.dart';
import '../services/current_user.dart';
import '../services/firestore/activity_firestore_service.dart';
import '../services/firestore/activity_invitation_firestore_service.dart';
import '../services/firestore/friendship_firestore_service.dart';
import '../services/firestore/group_invitation_firestore_service.dart';
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
  late final GroupInvitationFirestoreService _groupInvitationService;
  late final MessageBadgeRepository _messageBadgeRepository;
  late final ActivityFirestoreService _activityService;
  late final FriendshipFirestoreService _friendshipService;

  @override
  void initState() {
    super.initState();
    _invitationService = ActivityInvitationFirestoreService();
    _groupInvitationService = GroupInvitationFirestoreService();
    _messageBadgeRepository = MessageBadgeRepository();
    _activityService = ActivityFirestoreService();
    _friendshipService = FriendshipFirestoreService();
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

  String _currentUserKey() {
    final uid = AuthUser.uidOrNull;

    if (uid == null || uid.trim().isEmpty) {
      return 'signed_out';
    }

    return uid.trim();
  }

  List<Widget> _buildPages() {
    final userKey = _currentUserKey();

    return [
      CalendarPage(key: ValueKey('calendar_$userKey')),
      AllActivitiesPage(key: ValueKey('explorer_$userKey')),
      InvitationsPage(key: ValueKey('invitations_$userKey')),
      MyProfilePage(key: ValueKey('profile_$userKey')),
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
              icon: _ExplorerNavIcon(
                selected: false,
                isCurrentTab: _currentIndex == 1,
                messageBadgeRepository: _messageBadgeRepository,
                activityService: _activityService,
              ),
              selectedIcon: _ExplorerNavIcon(
                selected: true,
                isCurrentTab: _currentIndex == 1,
                messageBadgeRepository: _messageBadgeRepository,
                activityService: _activityService,
              ),
              label: 'Explorer',
            ),
            NavigationDestination(
              icon: _InvitationsNavIcon(
                selected: false,
                isCurrentTab: _currentIndex == 2,
                invitationService: _invitationService,
                groupInvitationService: _groupInvitationService,
              ),
              selectedIcon: _InvitationsNavIcon(
                selected: true,
                isCurrentTab: _currentIndex == 2,
                invitationService: _invitationService,
                groupInvitationService: _groupInvitationService,
              ),
              label: 'Invitations',
            ),
            NavigationDestination(
              icon: _ProfileNavIcon(
                selected: false,
                isCurrentTab: _currentIndex == 3,
                messageBadgeRepository: _messageBadgeRepository,
                friendshipService: _friendshipService,
              ),
              selectedIcon: _ProfileNavIcon(
                selected: true,
                isCurrentTab: _currentIndex == 3,
                messageBadgeRepository: _messageBadgeRepository,
                friendshipService: _friendshipService,
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorerNavIcon extends StatelessWidget {
  final bool selected;
  final bool isCurrentTab;
  final MessageBadgeRepository messageBadgeRepository;
  final ActivityFirestoreService activityService;

  const _ExplorerNavIcon({
    required this.selected,
    required this.isCurrentTab,
    required this.messageBadgeRepository,
    required this.activityService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: messageBadgeRepository.watchActivityUnreadCount(),
      builder: (context, unreadSnapshot) {
        final unreadCount = unreadSnapshot.data ?? 0;

        return StreamBuilder<List<Activity>>(
          stream: activityService.getJoinedActivities(),
          builder: (context, activitiesSnapshot) {
            final activities = activitiesSnapshot.data ?? [];

            final ownerPendingCount = activities
                .where((activity) => activity.ownerPending)
                .length;

            final totalBadgeCount = unreadCount + ownerPendingCount;

            return _NavBadgeIcon(
              icon: Icon(selected ? Icons.explore : Icons.explore_outlined),
              count: totalBadgeCount,
              hideBadge: isCurrentTab,
            );
          },
        );
      },
    );
  }
}

class _InvitationsNavIcon extends StatelessWidget {
  final bool selected;
  final bool isCurrentTab;
  final ActivityInvitationFirestoreService invitationService;
  final GroupInvitationFirestoreService groupInvitationService;

  const _InvitationsNavIcon({
    required this.selected,
    required this.isCurrentTab,
    required this.invitationService,
    required this.groupInvitationService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityInvitation>>(
      stream: invitationService.getPendingReceivedInvitations(),
      builder: (context, activitySnapshot) {
        final pendingActivityInvitationCount =
            activitySnapshot.data?.length ?? 0;

        return StreamBuilder<List<GroupInvitation>>(
          stream: groupInvitationService.getPendingReceivedInvitations(),
          builder: (context, groupSnapshot) {
            final pendingGroupInvitationCount =
                groupSnapshot.data?.length ?? 0;

            final totalPendingInvitationCount =
                pendingActivityInvitationCount + pendingGroupInvitationCount;

            return _NavBadgeIcon(
              icon: Icon(selected ? Icons.mail : Icons.mail_outline),
              count: totalPendingInvitationCount,
              hideBadge: isCurrentTab,
            );
          },
        );
      },
    );
  }
}

class _ProfileNavIcon extends StatelessWidget {
  final bool selected;
  final bool isCurrentTab;
  final MessageBadgeRepository messageBadgeRepository;
  final FriendshipFirestoreService friendshipService;

  const _ProfileNavIcon({
    required this.selected,
    required this.isCurrentTab,
    required this.messageBadgeRepository,
    required this.friendshipService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: messageBadgeRepository.watchGroupUnreadCount(),
      builder: (context, unreadSnapshot) {
        final unreadCount = unreadSnapshot.data ?? 0;

        return StreamBuilder<List<Friendship>>(
          stream: friendshipService.getPendingReceivedFriendRequests(),
          builder: (context, friendSnapshot) {
            final pendingFriendCount = friendSnapshot.data?.length ?? 0;

            return _NavBadgeIcon(
              icon: Icon(selected ? Icons.person : Icons.person_outline),
              count: unreadCount + pendingFriendCount,
              hideBadge: isCurrentTab,
            );
          },
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
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }
}