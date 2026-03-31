import 'package:flutter/material.dart';
import '../../services/current_user.dart';
import 'user_profile_page.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return UserProfilePage(userId: CurrentUser.id);
  }
}