import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_invitation_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';

class InviteUserPage extends StatefulWidget {
  final Activity activity;

  const InviteUserPage({
    super.key,
    required this.activity,
  });

  @override
  State<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends State<InviteUserPage> {
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final ActivityInvitationRepository invitationRepository =
      ActivityInvitationRepository();

  String searchText = '';

  String _displayName(Map<String, dynamic> user) {
    final pseudo = (user['pseudo'] ?? '').toString().trim();
    final prenom = (user['prenom'] ?? '').toString().trim();
    final nom = (user['nom'] ?? '').toString().trim();

    if (pseudo.isNotEmpty) return pseudo;
    if (prenom.isNotEmpty && nom.isNotEmpty) return '$prenom $nom';
    if (prenom.isNotEmpty) return prenom;
    return 'Utilisateur';
  }

  bool _matchesSearch(Map<String, dynamic> user) {
    if (searchText.trim().isEmpty) return true;

    final query = searchText.toLowerCase().trim();

    final pseudo = (user['pseudo'] ?? '').toString().toLowerCase();
    final prenom = (user['prenom'] ?? '').toString().toLowerCase();
    final nom = (user['nom'] ?? '').toString().toLowerCase();
    final lieu = (user['lieu'] ?? '').toString().toLowerCase();

    return pseudo.contains(query) ||
        prenom.contains(query) ||
        nom.contains(query) ||
        lieu.contains(query);
  }

  Future<void> _inviteUser(Map<String, dynamic> user) async {
    final userId = (user['id'] ?? '').toString();
    final userName = _displayName(user);

    if (userId.isEmpty) return;

    final sent = await invitationRepository.sendActivityInvitation(
      activity: widget.activity,
      toUserId: userId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Invitation envoyée à $userName'
              : 'Impossible d’envoyer l’invitation',
        ),
      ),
    );

    if (sent) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inviter un utilisateur'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Rechercher un utilisateur',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: activityService.getInviteableUsers(widget.activity.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur utilisateurs : ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final users = (snapshot.data ?? []).where(_matchesSearch).toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text('Aucun utilisateur à inviter'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final displayName = _displayName(user);
                    final lieu = (user['lieu'] ?? '').toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(displayName),
                        subtitle: Text(
                          lieu.trim().isNotEmpty
                              ? lieu
                              : 'Lieu non renseigné',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _inviteUser(user),
                          child: const Text('Inviter'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}