import 'package:flutter/material.dart';
import 'package:agenda_app/services/current_user.dart';

class TestUserSelectorPage extends StatefulWidget {
  const TestUserSelectorPage({super.key});

  @override
  State<TestUserSelectorPage> createState() => _TestUserSelectorPageState();
}

class _TestUserSelectorPageState extends State<TestUserSelectorPage> {
  final List<String> testUsers = ['Pierre', 'Alex', 'Jack'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un utilisateur de test'),
      ),
      body: ListView.builder(
        itemCount: testUsers.length,
        itemBuilder: (context, index) {
          final String userId = testUsers[index];
          final bool isSelected = CurrentUser.id == userId;

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
            onTap: () {
              if (CurrentUser.id == userId) {
                Navigator.pop(context, false);
                return;
              }

              CurrentUser.setUser(userId);
              Navigator.pop(context, true);
            },
          );
        },
      ),
    );
  }
}