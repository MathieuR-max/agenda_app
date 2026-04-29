import 'package:flutter/material.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';
import 'package:agenda_app/features/04_profile/user_profile_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  final FriendshipRepository _friendshipRepository = FriendshipRepository();
  final UserFirestoreService _userService = UserFirestoreService();

  late Future<List<Friendship>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriends();
  }

  Future<List<Friendship>> _loadFriends() async {
    final friendships = await _friendshipRepository.getAcceptedFriendships();

    friendships.sort((a, b) {
      final aDate = a.respondedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.respondedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return friendships;
  }

  Future<void> _refresh() async {
    setState(() {
      _friendsFuture = _loadFriends();
    });
    await _friendsFuture;
  }

  String _fallbackFriendName(Friendship friendship) {
    final pseudo = _friendshipRepository.getOtherUserPseudo(friendship).trim();
    final id = _friendshipRepository.getOtherUserId(friendship).trim();

    if (pseudo.isNotEmpty) return pseudo;
    if (id.isNotEmpty) return id;
    return 'Utilisateur';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _openFriendProfile(String friendId) async {
    final trimmedFriendId = friendId.trim();
    if (trimmedFriendId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(userId: trimmedFriendId),
      ),
    );

    if (!mounted) return;
    await _refresh();
  }

  Future<void> _confirmRemoveFriend(
    Friendship friendship,
    String displayName,
  ) async {
    if (friendship.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer cet ami'),
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer cet ami'),
          content: Text(
            'Voulez-vous vraiment supprimer $displayName de votre liste d’amis ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await _friendshipRepository.removeFriend(friendship.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '$displayName a été supprimé de vos amis.'
              : 'Erreur lors de la suppression de l’ami.',
        ),
      ),
    );

    if (success) {
      await _refresh();
    }
  }

  Widget _buildUnavailableFriendTile(Friendship friendship) {
    final fallbackName = _fallbackFriendName(friendship);
    final friendshipDate = friendship.respondedAt ?? friendship.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          child: Text('?'),
        ),
        title: Text(fallbackName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Utilisateur indisponible'),
            if (friendshipDate != null)
              Text(
                'Ami depuis ${_formatDate(friendshipDate)}',
              ),
          ],
        ),
        isThreeLine: friendshipDate != null,
      ),
    );
  }

  Widget _buildFriendTile(Friendship friendship) {
    final friendId = _friendshipRepository.getOtherUserId(friendship).trim();

    if (friendId.isEmpty) {
      return _buildUnavailableFriendTile(friendship);
    }

    final fallbackName = _fallbackFriendName(friendship);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userService.getUserById(friendId),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              leading: CircleAvatar(),
              title: Text('Chargement...'),
            ),
          );
        }

        final user = userSnapshot.data;
        final friendshipDate = friendship.respondedAt ?? friendship.createdAt;

        if (user == null) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  fallbackName.isNotEmpty
                      ? fallbackName[0].toUpperCase()
                      : '?',
                ),
              ),
              title: Text(fallbackName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Utilisateur introuvable en base'),
                  if (friendshipDate != null)
                    Text(
                      'Ami depuis ${_formatDate(friendshipDate)}',
                    ),
                ],
              ),
              isThreeLine: friendshipDate != null,
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'remove') {
                    await _confirmRemoveFriend(
                      friendship,
                      fallbackName,
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Text('Supprimer cet ami'),
                  ),
                ],
              ),
            ),
          );
        }

        final String pseudo = (user['pseudo'] ?? '').toString().trim();
        final String prenom = (user['prenom'] ?? '').toString().trim();
        final String nom = (user['nom'] ?? '').toString().trim();
        final String lieu = (user['lieu'] ?? '').toString().trim();

        String displayName = fallbackName;

        if (pseudo.isNotEmpty) {
          displayName = pseudo;
        } else if (prenom.isNotEmpty && nom.isNotEmpty) {
          displayName = '$prenom $nom';
        } else if (prenom.isNotEmpty) {
          displayName = prenom;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              ),
            ),
            title: Text(displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lieu.isNotEmpty ? lieu : 'Lieu non renseigné',
                ),
                if (friendshipDate != null)
                  Text(
                    'Ami depuis ${_formatDate(friendshipDate)}',
                  ),
              ],
            ),
            isThreeLine: friendshipDate != null,
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'open') {
                  await _openFriendProfile(friendId);
                }

                if (value == 'remove') {
                  await _confirmRemoveFriend(
                    friendship,
                    displayName,
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'open',
                  child: Text('Voir le profil'),
                ),
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('Supprimer cet ami'),
                ),
              ],
            ),
            onTap: () async {
              await _openFriendProfile(friendId);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes amis'),
      ),
      body: FutureBuilder<List<Friendship>>(
        future: _friendsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur lors du chargement des amis : ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final friendships = snapshot.data ?? [];

          if (friendships.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Vous n’avez pas encore d’amis.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: friendships.length,
              itemBuilder: (context, index) {
                return _buildFriendTile(friendships[index]);
              },
            ),
          );
        },
      ),
    );
  }
}