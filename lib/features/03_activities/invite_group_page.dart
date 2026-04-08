import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/features/03_activities/invite_to_activity_page.dart';

class InviteGroupPage extends StatelessWidget {
  final Activity activity;

  const InviteGroupPage({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return InviteToActivityPage(activity: activity);
  }
}