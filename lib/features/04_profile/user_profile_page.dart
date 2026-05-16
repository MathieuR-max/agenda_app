import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/friendship.dart';
import '../../repositories/friendship_repository.dart';
import '../../repositories/message_badge_repository.dart';
import '../../services/firestore/friendship_firestore_service.dart';
import '../../repositories/profile_repository.dart';
import '../../services/current_user.dart';
import '../06_groups/groups_page.dart';
import 'edit_profile_page.dart';
import 'friend_requests_page.dart';
import 'friends_list_page.dart';
import 'search_users_page.dart';

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

  Future<void> _sendFriendRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    String profileUserId,
  ) async {
    final sent = await friendshipRepository.sendFriendRequest(
      toUserId: profileUserId.trim(),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent ? 'Demande d’ami envoyée' : 'Impossible d’envoyer la demande',
        ),
      ),
    );
  }

  Future<void> _acceptFriendRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
  ) async {
    final friendshipId = friendship.id.trim();

    if (friendshipId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’accepter la demande'),
        ),
      );
      return;
    }

    final accepted = await friendshipRepository.acceptFriendRequest(
      friendshipId,
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
    final friendshipId = friendship.id.trim();

    if (friendshipId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de refuser la demande'),
        ),
      );
      return;
    }

    final refused = await friendshipRepository.refuseFriendRequest(
      friendshipId,
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
    final friendshipId = friendship.id.trim();

    if (friendshipId.isEmpty) {
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

    final removed = await friendshipRepository.removeFriend(friendshipId);

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

  Widget _buildChipWrap(
    List<String> values, {
    String emptyLabel = 'Aucun élément',
  }) {
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

  Widget _buildFriendRequestsButton(
    BuildContext context,
    FriendshipFirestoreService friendshipFirestoreService,
  ) {
    return StreamBuilder<List<Friendship>>(
      stream: friendshipFirestoreService.getPendingReceivedFriendRequests(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.length ?? 0;

        return OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FriendRequestsPage()),
            );
          },
          icon: Badge(
            isLabelVisible: pendingCount > 0,
            label: Text(pendingCount > 99 ? '99+' : '$pendingCount'),
            child: const Icon(Icons.group_add),
          ),
          label: Text(
            pendingCount > 0
                ? 'Voir mes demandes d’amis ($pendingCount)'
                : 'Voir mes demandes d’amis',
          ),
        );
      },
    );
  }

  Widget _buildGroupsButton(
    BuildContext context,
    MessageBadgeRepository messageBadgeRepository,
  ) {
    return StreamBuilder<int>(
      stream: messageBadgeRepository.watchGroupUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GroupsPage(),
              ),
            );
          },
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.groups),
          ),
          label: Text(
            unreadCount > 0
                ? 'Voir mes groupes ($unreadCount)'
                : 'Voir mes groupes',
          ),
        );
      },
    );
  }

  Widget _buildFriendshipSection(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    MessageBadgeRepository messageBadgeRepository,
    FriendshipFirestoreService friendshipFirestoreService,
    String profileUserId,
    String currentUserId,
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchUsersPage(),
                  ),
                ),
                icon: const Icon(Icons.person_search),
                label: const Text('Rechercher des utilisateurs'),
              ),
              const SizedBox(height: 12),
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
              _buildFriendRequestsButton(
                context,
                friendshipFirestoreService,
              ),
              const SizedBox(height: 12),
              _buildGroupsButton(
                context,
                messageBadgeRepository,
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
          stream: friendshipRepository.watchFriendshipWithUser(
            profileUserId.trim(),
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erreur relation d’amitié :\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
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

            final requestReceived =
                friendship.addresseeId.trim() == currentUserId;

            final displayName = requestReceived
                ? (friendship.requesterPseudo.trim().isNotEmpty
                    ? friendship.requesterPseudo.trim()
                    : friendship.requesterId.trim())
                : (friendship.addresseePseudo.trim().isNotEmpty
                    ? friendship.addresseePseudo.trim()
                    : friendship.addresseeId.trim());

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
                      displayName.isNotEmpty ? displayName : 'cet utilisateur',
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
                      friendship.requesterPseudo.trim().isNotEmpty
                          ? '${friendship.requesterPseudo.trim()} vous a envoyé une demande d’ami'
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
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Demande d’ami envoyée'),
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
    final messageBadgeRepository = MessageBadgeRepository();
    final friendshipFirestoreService = FriendshipFirestoreService();

    final currentUserId = AuthUser.uidOrNull?.trim();
    final profileUserId = userId.trim();

    if (currentUserId == null || currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: const Center(
          child: Text('Utilisateur non connecté'),
        ),
      );
    }

    if (profileUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: const Center(
          child: Text('Profil introuvable'),
        ),
      );
    }

    final isCurrentUser = profileUserId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: StreamBuilder<UserModel?>(
        stream: repository.watchUser(profileUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur lors du chargement du profil : ${snapshot.error}',
              ),
            );
          }

          final user = snapshot.data;

          if (user == null) {
            return const Center(
              child: Text('Utilisateur introuvable'),
            );
          }

          final firstName = user.prenom.trim();
          final lastName = user.nom.trim();
          final pseudo = user.pseudo.trim();

          final fullName = '$firstName $lastName'.trim();
          final avatarLetter = firstName.isNotEmpty
              ? firstName[0].toUpperCase()
              : lastName.isNotEmpty
                  ? lastName[0].toUpperCase()
                  : pseudo.isNotEmpty
                      ? pseudo[0].toUpperCase()
                      : '?';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: (user.photoUrl != null &&
                          user.photoUrl!.trim().isNotEmpty)
                      ? NetworkImage(user.photoUrl!.trim())
                      : null,
                  child: (user.photoUrl == null ||
                          user.photoUrl!.trim().isEmpty)
                      ? Text(
                          avatarLetter,
                          style: const TextStyle(fontSize: 28),
                        )
                      : null,
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
                  pseudo.isNotEmpty ? '@$pseudo' : 'Pseudo non renseigné',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfilePage(user: user),
                      ),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier mon profil'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildFriendshipSection(
                context,
                friendshipRepository,
                messageBadgeRepository,
                friendshipFirestoreService,
                profileUserId,
                currentUserId,
                isCurrentUser,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.location_city,
                text: (user.lieu != null && user.lieu!.trim().isNotEmpty)
                    ? user.lieu!.trim()
                    : 'Lieu non renseigné',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.person,
                text: (user.genre != null && user.genre!.trim().isNotEmpty)
                    ? user.genre!.trim()
                    : 'Genre non renseigné',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.cake,
                text: (user.dateNaissance != null &&
                        user.dateNaissance!.trim().isNotEmpty)
                    ? user.dateNaissance!.trim()
                    : 'Date de naissance non renseignée',
              ),
              if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.info_outline,
                  text: user.bio!.trim(),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Centres d’intérêt",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildChipWrap(
                        user.centresInteret,
                        emptyLabel: "Aucun centre d’intérêt",
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
                      const Text(
                        "Catégories favorites",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildChipWrap(
                        user.favoriteCategories,
                        emptyLabel: "Aucune catégorie favorite",
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