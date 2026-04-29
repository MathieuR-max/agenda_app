import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/features/04_profile/user_profile_page.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  String? _resolveCurrentUserId() {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  @override
  Widget build(BuildContext context) {
    final userId = _resolveCurrentUserId();

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: const Center(
          child: Text('Utilisateur introuvable'),
        ),
      );
    }

    return UserProfilePage(userId: userId);
  }
}