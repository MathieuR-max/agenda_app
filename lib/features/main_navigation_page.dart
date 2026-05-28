import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/activity_invitation.dart';
import '../models/friendship.dart';
import '../models/group_invitation.dart';
import '../models/user_model.dart';
import '../repositories/message_badge_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/current_user.dart';
import '../services/firestore/activity_firestore_service.dart';
import '../services/firestore/activity_invitation_firestore_service.dart';
import '../services/firestore/friendship_firestore_service.dart';
import '../services/firestore/group_invitation_firestore_service.dart';
import '02_calendar/calendar_page.dart';
import '03_activities/invitations_page.dart';
import '03_activities/my_activities_page.dart';
import '04_explore/explore_page.dart';
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
  late final NotificationRepository _notificationRepository;
  StreamSubscription<dynamic>? _foregroundMessageSub;

  @override
  void initState() {
    super.initState();
    _invitationService = ActivityInvitationFirestoreService();
    _groupInvitationService = GroupInvitationFirestoreService();
    _messageBadgeRepository = MessageBadgeRepository();
    _activityService = ActivityFirestoreService();
    _friendshipService = FriendshipFirestoreService();
    _notificationRepository = NotificationRepository();
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
      final type = (message.data['type'] ?? '').toString();
      if (type == 'private_message_created') {
        final pseudo =
            (message.data['senderPseudo'] ?? 'Quelqu\'un').toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('💬 Message de $pseudo')),
        );
      }
    });
  }

  @override
  void dispose() {
    _foregroundMessageSub?.cancel();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    if (index == 2) _notificationRepository.markActivityMatchesAsRead();
    setState(() => _currentIndex = index);
  }

  Future<void> _handleBackNavigation(bool didPop, Object? result) async {
    if (didPop) return;
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
  }

  String _currentUserKey() {
    final uid = AuthUser.uidOrNull;
    if (uid == null || uid.trim().isEmpty) return 'signed_out';
    return uid.trim();
  }

  String _currentPageTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Agenda';
      case 1:
        return 'Mes activités';
      case 2:
        return 'Explorer';
      case 3:
        return 'Invitations';
      default:
        return '';
    }
  }

  // NOTE : CalendarPage et InvitationsPage ont leur propre AppBar — double
  // AppBar temporaire jusqu'à ce que leurs AppBars internes soient retirés.
  List<Widget> _buildPages() {
    final userKey = _currentUserKey();
    return [
      CalendarPage(key: ValueKey('calendar_$userKey')),
      MyActivitiesPage(key: ValueKey('my_activities_$userKey')),
      ExplorePage(key: ValueKey('explorer_$userKey')),
      InvitationsPage(key: ValueKey('invitations_$userKey')),
    ];
  }

  Widget _buildPillNavItem(
    int index,
    IconData iconData,
    String label, {
    Widget Function(Color color)? badgeIconBuilder,
  }) {
    final isActive = _currentIndex == index;
    final color =
        isActive ? const Color(0xFF00B4A6) : const Color(0xFF6F6F6F);

    final Widget iconWidget = badgeIconBuilder != null
        ? badgeIconBuilder(color)
        : Icon(iconData, size: 24, color: color);

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FAF8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: iconWidget,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: iconWidget,
              ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: _handleBackNavigation,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFFCFBF8),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(_currentPageTitle()),
          titleTextStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF181818),
          ),
          iconTheme: const IconThemeData(
            color: Color(0xFF2A2A2A),
            size: 24,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(
              color: const Color(0xFFF0ECE6),
              height: 0.5,
            ),
          ),
          actions: [
            _ProfileAppBarIcon(
              friendshipService: _friendshipService,
              messageBadgeRepository: _messageBadgeRepository,
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFEDE9E3), width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  Expanded(
                    child: _buildPillNavItem(
                      0,
                      Icons.calendar_today_outlined,
                      'Agenda',
                    ),
                  ),
                  Expanded(
                    child: _buildPillNavItem(
                      1,
                      Icons.grid_view_outlined,
                      'Mes activités',
                      badgeIconBuilder: (color) => _MyActivitiesNavIcon(
                        isCurrentTab: _currentIndex == 1,
                        iconColor: color,
                        messageBadgeRepository: _messageBadgeRepository,
                        activityService: _activityService,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildPillNavItem(
                      2,
                      Icons.explore_outlined,
                      'Explorer',
                      badgeIconBuilder: (color) => _ExploreNavIcon(
                        isCurrentTab: _currentIndex == 2,
                        iconColor: color,
                        notificationRepository: _notificationRepository,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildPillNavItem(
                      3,
                      Icons.mail_outline,
                      'Invitations',
                      badgeIconBuilder: (color) => _InvitationsNavIcon(
                        isCurrentTab: _currentIndex == 3,
                        iconColor: color,
                        invitationService: _invitationService,
                        groupInvitationService: _groupInvitationService,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AppBar profile icon ──────────────────────────────────────────────────────

class _ProfileAppBarIcon extends StatelessWidget {
  final FriendshipFirestoreService friendshipService;
  final MessageBadgeRepository messageBadgeRepository;

  const _ProfileAppBarIcon({
    required this.friendshipService,
    required this.messageBadgeRepository,
  });

  @override
  Widget build(BuildContext context) {
    final uid = AuthUser.uidOrNull;

    return StreamBuilder<UserModel?>(
      stream: uid != null
          ? ProfileRepository().watchUser(uid)
          : Stream.value(null),
      builder: (context, userSnapshot) {
        final photoUrl = userSnapshot.data?.photoUrl?.trim();

        return StreamBuilder<int>(
          stream: messageBadgeRepository.watchPrivateUnreadCount(),
          builder: (context, privateSnapshot) {
            final privateUnread = privateSnapshot.data ?? 0;

            return StreamBuilder<List<Friendship>>(
              stream: friendshipService.getPendingReceivedFriendRequests(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data?.length ?? 0;
                final total = pendingCount + privateUnread;

                final Widget avatarWidget =
                    (photoUrl != null && photoUrl.isNotEmpty)
                        ? CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(photoUrl),
                            backgroundColor: Colors.transparent,
                          )
                        : const Icon(Icons.account_circle);

                return IconButton(
                  tooltip: 'Mon profil',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyProfilePage()),
                  ),
                  icon: Badge(
                    isLabelVisible: total > 0,
                    label: Text(total > 99 ? '99+' : '$total'),
                    child: avatarWidget,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Nav icons ───────────────────────────────────────────────────────────────

class _MyActivitiesNavIcon extends StatelessWidget {
  final bool isCurrentTab;
  final Color iconColor;
  final MessageBadgeRepository messageBadgeRepository;
  final ActivityFirestoreService activityService;

  const _MyActivitiesNavIcon({
    required this.isCurrentTab,
    required this.iconColor,
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
            final ownerPendingCount = (activitiesSnapshot.data ?? [])
                .where((a) => a.ownerPending)
                .length;

            return _NavBadgeIcon(
              icon: Icon(
                Icons.grid_view_outlined,
                size: 24,
                color: iconColor,
              ),
              count: unreadCount + ownerPendingCount,
              hideBadge: isCurrentTab,
            );
          },
        );
      },
    );
  }
}

class _ExploreNavIcon extends StatelessWidget {
  final bool isCurrentTab;
  final Color iconColor;
  final NotificationRepository notificationRepository;

  const _ExploreNavIcon({
    required this.isCurrentTab,
    required this.iconColor,
    required this.notificationRepository,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: notificationRepository.watchUnreadMatchCount(),
      builder: (context, snapshot) {
        return _NavBadgeIcon(
          icon: Icon(Icons.explore_outlined, size: 24, color: iconColor),
          count: snapshot.data ?? 0,
          hideBadge: isCurrentTab,
        );
      },
    );
  }
}

class _InvitationsNavIcon extends StatelessWidget {
  final bool isCurrentTab;
  final Color iconColor;
  final ActivityInvitationFirestoreService invitationService;
  final GroupInvitationFirestoreService groupInvitationService;

  const _InvitationsNavIcon({
    required this.isCurrentTab,
    required this.iconColor,
    required this.invitationService,
    required this.groupInvitationService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityInvitation>>(
      stream: invitationService.getPendingReceivedInvitations(),
      builder: (context, activitySnapshot) {
        final pendingActivityCount = activitySnapshot.data?.length ?? 0;

        return StreamBuilder<List<GroupInvitation>>(
          stream: groupInvitationService.getPendingReceivedInvitations(),
          builder: (context, groupSnapshot) {
            final pendingGroupCount = groupSnapshot.data?.length ?? 0;

            return _NavBadgeIcon(
              icon: Icon(Icons.mail_outline, size: 24, color: iconColor),
              count: pendingActivityCount + pendingGroupCount,
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
    if (hideBadge || count <= 0) return icon;

    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }
}
