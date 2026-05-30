import 'package:flutter/material.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/repositories/private_chat_repository.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';
import 'package:agenda_app/features/04_profile/user_profile_page.dart';
import 'package:agenda_app/features/05_chat/private_chat_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  final FriendshipRepository _friendshipRepository = FriendshipRepository();
  final UserFirestoreService _userService = UserFirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Future<List<Friendship>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriends();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    const months = ['', 'janvier', 'février', 'mars', 'avril', 'mai',
        'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return 'le ${date.day} ${months[date.month]} ${date.year}';
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
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF9635E),
              ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF1EFEB),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('?',
                  style: TextStyle(fontSize: 18, color: Color(0xFFA8A8A8))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fallbackName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Utilisateur indisponible',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                  ),
                  if (friendshipDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ami depuis ${_formatDate(friendshipDate)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFA8A8A8)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(Friendship friendship) {
    final friendId = _friendshipRepository.getOtherUserId(friendship).trim();

    // Filtre recherche
    if (_searchQuery.isNotEmpty) {
      final name = _fallbackFriendName(friendship).toLowerCase();
      if (!name.contains(_searchQuery)) return const SizedBox.shrink();
    }

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

        return GestureDetector(
          onTap: () async => await _openFriendProfile(friendId),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB8ECE6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00B4A6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (lieu.isNotEmpty)
                          Text(
                            lieu,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                          ),
                        if (friendshipDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Ami depuis ${_formatDate(friendshipDate)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFA8A8A8)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final chatId = await PrivateChatRepository()
                          .getOrCreateChatWithUser(friendId);
                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivateChatPage(
                            chatId: chatId,
                            otherUserPseudo: displayName,
                            otherUserId: friendId,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F7F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF00B4A6),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'open') await _openFriendProfile(friendId);
                      if (value == 'remove') await _confirmRemoveFriend(friendship, displayName);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(value: 'open', child: Text('Voir le profil')),
                      PopupMenuItem<String>(value: 'remove', child: Text('Supprimer cet ami')),
                    ],
                  ),
                ],
              ),
            ),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E)),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF000000).withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un ami...',
                        hintStyle: const TextStyle(color: Color(0xFFA8A8A8), fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF6F6F6F), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFF00B4A6), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Color(0xFF6F6F6F)),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: friendships.length,
                    itemBuilder: (context, index) {
                      return _buildFriendTile(friendships[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}