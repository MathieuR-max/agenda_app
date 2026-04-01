import 'package:flutter/material.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/features/04_profile/user_profile_page.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return UserProfilePage(userId: CurrentUser.id);
  }
}