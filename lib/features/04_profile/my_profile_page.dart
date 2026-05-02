import 'package:flutter/material.dart';
import 'package:agenda_app/features/04_profile/user_profile_page.dart';
import 'package:agenda_app/services/current_user.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthUser.uidOrNull?.trim();

    if (userId == null || userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: const Center(
          child: Text('Utilisateur non connecté'),
        ),
      );
    }

    return UserProfilePage(userId: userId);
  }
}