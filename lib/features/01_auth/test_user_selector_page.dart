import 'package:flutter/material.dart';
import 'package:agenda_app/features/main_navigation_page.dart';
import 'package:agenda_app/services/current_user.dart';

class TestUserSelectorPage extends StatefulWidget {
  const TestUserSelectorPage({super.key});

  @override
  State<TestUserSelectorPage> createState() => _TestUserSelectorPageState();
}

class _TestUserSelectorPageState extends State<TestUserSelectorPage> {
  final List<String> testUsers = const ['Pierre', 'Alex', 'Jack'];

  Future<void> _selectUser(BuildContext context, String userId) async {
    final String trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return;

    final String? currentUserId = CurrentUser.idOrNull?.trim();
    final bool isSameUser = currentUserId == trimmedUserId;

    if (!isSameUser) {
      CurrentUser.setUser(trimmedUserId);
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainNavigationPage(
          key: ValueKey('main_nav_${CurrentUser.id}'),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = CurrentUser.idOrNull?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un utilisateur de test'),
      ),
      body: ListView.builder(
        itemCount: testUsers.length,
        itemBuilder: (context, index) {
          final String userId = testUsers[index].trim();
          final bool isSelected = currentUserId == userId;

          return ListTile(
            leading: Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(userId),
            subtitle: isSelected
                ? const Text('Utilisateur actuellement connecté')
                : null,
            onTap: () => _selectUser(context, userId),
          );
        },
      ),
    );
  }
}