import 'dart:async';

import 'package:flutter/material.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/friendship_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';
import 'user_profile_page.dart';

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  late final UserFirestoreService _userService;
  late final FriendshipFirestoreService _friendshipService;
  late final FriendshipRepository _friendshipRepository;

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _lastQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _userService = UserFirestoreService();
    _friendshipService = FriendshipFirestoreService();
    _friendshipRepository = FriendshipRepository();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final query = value.trim();
    _lastQuery = query;

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await _userService.searchUsersByPseudo(query);
      if (_lastQuery == query && mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _sendFriendRequest(String userId) async {
    final sent = await _friendshipRepository.sendFriendRequest(
      toUserId: userId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent ? 'Demande envoyée' : "Impossible d'envoyer la demande",
        ),
      ),
    );
  }

  Future<void> _acceptFriendRequest(String friendshipId) async {
    final accepted =
        await _friendshipRepository.acceptFriendRequest(friendshipId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted ? 'Demande acceptée' : "Impossible d'accepter la demande",
        ),
      ),
    );
  }

  Widget _buildTrailing(Map<String, dynamic> user, String userId) {
    final currentUid = AuthUser.uidOrNull;

    return StreamBuilder<Friendship?>(
      stream: _friendshipService.watchFriendshipWithUser(userId),
      builder: (context, snapshot) {
        final friendship = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (friendship == null || friendship.isRefused || friendship.isCancelled) {
          return ElevatedButton(
            onPressed: () => _sendFriendRequest(userId),
            child: const Text('Ajouter'),
          );
        }

        if (friendship.isAccepted) {
          return Chip(
            label: const Text('Ami ✓'),
            backgroundColor: Colors.green.shade100,
            labelStyle: TextStyle(color: Colors.green.shade800),
          );
        }

        if (friendship.isPending) {
          final iAmRequester = friendship.requesterId == currentUid;
          if (iAmRequester) {
            return OutlinedButton(
              onPressed: null,
              child: const Text('Demande envoyée'),
            );
          } else {
            return ElevatedButton(
              onPressed: () => _acceptFriendRequest(friendship.id),
              child: const Text('Accepter'),
            );
          }
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = (user['id'] as String? ?? '');
    final pseudo = (user['pseudo'] as String? ?? '').trim();
    final prenom = (user['prenom'] as String? ?? '').trim();
    final nom = (user['nom'] as String? ?? '').trim();

    final avatarLetter = pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?';
    final subtitle = [prenom, nom].where((s) => s.isNotEmpty).join(' ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(avatarLetter)),
        title: Text(
          pseudo.isNotEmpty ? pseudo : 'Pseudo non renseigné',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        trailing: _buildTrailing(user, userId),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfilePage(userId: userId),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasQuery = _searchController.text.trim().length >= 2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery
                  ? 'Aucun utilisateur trouvé'
                  : 'Recherchez un utilisateur par pseudo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher des utilisateurs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Rechercher par pseudo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _isLoading = false;
                            _lastQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) => _buildUserTile(_results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
