import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/friendship.dart';
import '../../services/current_user.dart';
import '../../repositories/friendship_repository.dart';
import '../../repositories/profile_repository.dart';
import '../06_groups/groups_page.dart';
import 'friend_requests_page.dart';
import 'friends_list_page.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({
    super.key,
    required this.userId,
  });

  static const List<String> availableCategories = [
    'Sport',
    'Sortie',
    'Culture',
    'Jeux',
    'Études',
    'Travail',
    'Détente',
    'Autre',
  ];

  Future<void> _editFavoriteCategories(
    BuildContext context,
    UserModel user,
    ProfileRepository repository,
  ) async {
    final List<String> selected = List<String>.from(user.favoriteCategories);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Catégories favorites'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: availableCategories.map((category) {
                    final isChecked = selected.contains(category);

                    return CheckboxListTile(
                      value: isChecked,
                      title: Text(category),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (!selected.contains(category)) {
                              selected.add(category);
                            }
                          } else {
                            selected.remove(category);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, selected);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    await repository.updateFavoriteCategories(userId, result);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catégories favorites mises à jour'),
      ),
    );
  }

  Future<void> _sendFriendRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    String profileUserId,
  ) async {
    final sent = await friendshipRepository.sendFriendRequest(
      toUserId: profileUserId,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Demande d’ami envoyée'
              : 'Impossible d’envoyer la demande',
        ),
      ),
    );
  }

  Future<void> _acceptFriendRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
  ) async {
    if (friendship.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’accepter la demande'),
        ),
      );
      return;
    }

    final accepted = await friendshipRepository.acceptFriendRequest(
      friendship.id,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? 'Demande d’ami acceptée'
              : 'Impossible d’accepter la demande',
        ),
      ),
    );
  }

  Future<void> _refuseFriendRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
  ) async {
    if (friendship.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de refuser la demande'),
        ),
      );
      return;
    }

    final refused = await friendshipRepository.refuseFriendRequest(
      friendship.id,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          refused
              ? 'Demande d’ami refusée'
              : 'Impossible de refuser la demande',
        ),
      ),
    );
  }

  Future<void> _removeFriend(
    BuildContext context,
    FriendshipRepository friendshipRepository,
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

    final confirmed = await showDialog<bool>(
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
        ) ??
        false;

    if (!confirmed) return;

    final removed = await friendshipRepository.removeFriend(friendship.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? '$displayName a été supprimé de vos amis.'
              : 'Impossible de supprimer cet ami.',
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String text,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipWrap(List<String> values, {String emptyLabel = 'Aucun élément'}) {
    if (values.isEmpty) {
      return Text(emptyLabel);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return Chip(
          label: Text(value),
        );
      }).toList(),
    );
  }

  Widget _buildFriendshipSection(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    String profileUserId,
    bool isCurrentUser,
  ) {
    if (isCurrentUser) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FriendsListPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.people),
                label: const Text('Voir mes amis'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FriendRequestsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Voir mes demandes d’amis'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GroupsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.groups),
                label: const Text('Voir mes groupes'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<Friendship?>(
          stream: friendshipRepository.watchFriendshipWithUser(profileUserId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Erreur relation d’amitié');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final friendship = snapshot.data;

            if (friendship == null) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _sendFriendRequest(
                    context,
                    friendshipRepository,
                    profileUserId,
                  ),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter en ami'),
                ),
              );
            }

            final bool requestReceived =
                friendship.addresseeId == CurrentUser.id;

            final displayName = requestReceived
                ? (friendship.requesterPseudo.trim().isNotEmpty
                    ? friendship.requesterPseudo.trim()
                    : friendship.requesterId)
                : (friendship.addresseePseudo.trim().isNotEmpty
                    ? friendship.addresseePseudo.trim()
                    : friendship.addresseeId);

            if (friendship.isAccepted) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Vous êtes amis',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _removeFriend(
                      context,
                      friendshipRepository,
                      friendship,
                      displayName,
                    ),
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Supprimer cet ami'),
                  ),
                ],
              );
            }

            if (friendship.isPending && requestReceived) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      friendship.requesterPseudo.isNotEmpty
                          ? '${friendship.requesterPseudo} vous a envoyé une demande d’ami'
                          : 'Vous avez reçu une demande d’ami',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptFriendRequest(
                            context,
                            friendshipRepository,
                            friendship,
                          ),
                          child: const Text('Accepter'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _refuseFriendRequest(
                            context,
                            friendshipRepository,
                            friendship,
                          ),
                          child: const Text('Refuser'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            if (friendship.isPending && !requestReceived) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Demande envoyée',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }

            if (friendship.isRefused || friendship.isCancelled) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _sendFriendRequest(
                    context,
                    friendshipRepository,
                    profileUserId,
                  ),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter en ami'),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ProfileRepository();
    final friendshipRepository = FriendshipRepository();
    final bool isCurrentUser = userId == CurrentUser.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: StreamBuilder<UserModel?>(
        stream: repository.watchUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Erreur lors du chargement du profil'),
            );
          }

          final user = snapshot.data;

          if (user == null) {
            return const Center(
              child: Text('Utilisateur introuvable'),
            );
          }

          final fullName = '${user.prenom} ${user.nom}'.trim();
          final avatarLetter = user.prenom.isNotEmpty
              ? user.prenom[0].toUpperCase()
              : user.nom.isNotEmpty
                  ? user.nom[0].toUpperCase()
                  : '?';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  fullName.isNotEmpty ? fullName : 'Nom non renseigné',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  user.pseudo.isNotEmpty
                      ? '@${user.pseudo}'
                      : 'Pseudo non renseigné',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              _buildFriendshipSection(
                context,
                friendshipRepository,
                userId,
                isCurrentUser,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.location_city,
                text: (user.lieu != null && user.lieu!.isNotEmpty)
                    ? user.lieu!
                    : 'Lieu non renseigné',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.person,
                text: (user.genre != null && user.genre!.isNotEmpty)
                    ? user.genre!
                    : 'Genre non renseigné',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.cake,
                text: (user.dateNaissance != null &&
                        user.dateNaissance!.isNotEmpty)
                    ? user.dateNaissance!
                    : 'Date de naissance non renseignée',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Centres d’intérêt',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildChipWrap(
                        user.centresInteret,
                        emptyLabel: 'Aucun centre d’intérêt',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Catégories favorites',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isCurrentUser)
                            TextButton(
                              onPressed: () => _editFavoriteCategories(
                                context,
                                user,
                                repository,
                              ),
                              child: const Text('Modifier'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildChipWrap(
                        user.favoriteCategories,
                        emptyLabel: 'Aucune catégorie favorite',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}