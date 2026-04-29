import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:agenda_app/core/utils/app_navigator.dart';
import 'package:agenda_app/features/03_activities/invitations_page.dart';
import 'package:agenda_app/features/05_chat/activity_chat_page.dart';
import 'package:agenda_app/features/06_groups/group_chat_page.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/group_model.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';

class NotificationNavigationService {
  NotificationNavigationService({
    ActivityFirestoreService? activityService,
    GroupsRepository? groupsRepository,
  })  : _activityService = activityService ?? ActivityFirestoreService(),
        _groupsRepository = groupsRepository ?? GroupsRepository();

  final ActivityFirestoreService _activityService;
  final GroupsRepository _groupsRepository;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _handleRemoteMessage(initialMessage);
    }
  }

  Future<void> _handleRemoteMessage(RemoteMessage message) async {
    final data = message.data;
    final type = (data['type'] ?? '').toString().trim();

    debugPrint('NotificationNavigationService payload: $data');

    switch (type) {
      case 'activity_invitation_created':
        _openInvitationsPage();
        break;

      case 'activity_message_created':
        final activityId = (data['activityId'] ?? '').toString().trim();
        if (activityId.isNotEmpty) {
          await _openActivityChat(activityId);
        }
        break;

      case 'group_message_created':
        final groupId = (data['groupId'] ?? '').toString().trim();
        if (groupId.isNotEmpty) {
          await _openGroupChat(groupId);
        }
        break;

      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  void _openInvitationsPage() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => const InvitationsPage(),
      ),
    );
  }

  Future<void> _openActivityChat(String activityId) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    try {
      final Activity? activity = await _activityService.getActivityById(activityId);

      if (activity == null) {
        debugPrint('Activity not found for notification: $activityId');
        return;
      }

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ActivityChatPage(activity: activity),
        ),
      );
    } catch (e) {
      debugPrint('Failed to open activity chat from notification: $e');
    }
  }

  Future<void> _openGroupChat(String groupId) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    try {
      final GroupModel? group = await _groupsRepository.getGroupById(groupId);

      if (group == null) {
        debugPrint('Group not found for notification: $groupId');
        return;
      }

      navigator.push(
        MaterialPageRoute(
          builder: (_) => GroupChatPage(
            groupId: group.id,
            groupName: group.name,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to open group chat from notification: $e');
    }
  }
}