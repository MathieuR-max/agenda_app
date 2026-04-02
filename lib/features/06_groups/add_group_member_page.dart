import 'package:flutter/material.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/repositories/group_chat_repository.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class AddGroupMemberPage extends StatefulWidget {
  final String groupId;

  const AddGroupMemberPage({
    super.key,
    required this.groupId,
  });

  @override
  State<AddGroupMemberPage> createState() => _AddGroupMemberPageState();
}

class _AddGroupMemberPageState extends State<AddGroupMemberPage> {
  final FriendshipRepository _friendshipRepository = FriendshipRepository();
  final GroupsRepository _groupsRepository = GroupsRepository();
  final GroupChatRepository _groupChatRepository = GroupChatRepository();
  final UserFirestoreService _userService = UserFirestoreService();

  late Future<List<Friendship>> _friendsFuture;
  late Future<List<String>> _groupMemberIdsFuture;

  String? addingUserId;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriends();
    _groupMemberIdsFuture = _loadGroupMemberIds();
  }

  Future<List<Friendship>> _loadFriends() {
    return _friendshipRepository.getAcceptedFriendships();
  }

  Future<List<String>> _loadGroupMemberIds() {
    return _groupsRepository.getGroupMemberIds(widget.groupId);
  }

  String _fallbackFriendName(Friendship friendship) {
    final pseudo = _friendshipRepository.getOtherUserPseudo(friendship).trim();
    final id = _friendshipRepository.getOtherUserId(friendship).trim();

    if (pseudo.isNotEmpty) return pseudo;
    if (id.isNotEmpty) return id;
    return 'Utilisateur';
  }

  Future<void> _addMember(Friendship friendship, String displayName) async {
    final userId = _friendshipRepository.getOtherUserId(friendship).trim();

    if (userId.isEmpty || addingUserId != null) {
      return;
    }

    setState(() {
      addingUserId = userId;
    });

    try {
      final success = await _groupsRepository.addMember(
        groupId: widget.groupId,
        userId: userId,
      );

      if (success) {
        await _groupChatRepository.sendSystemMessage(
          groupId: widget.groupId,
          text: '$displayName a rejoint le groupe',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '$displayName a été ajouté au groupe.'
                : 'Impossible d’ajouter $displayName au groupe.',
          ),
        ),
      );

      if (success) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          addingUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un ami'),
      ),
      body: FutureBuilder<List<Friendship>>(
        future: _friendsFuture,
        builder: (context, friendsSnapshot) {
          if (friendsSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur lors du chargement des amis : ${friendsSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (friendsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return FutureBuilder<List<String>>(
            future: _groupMemberIdsFuture,
            builder: (context, membersSnapshot) {
              if (membersSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erreur lors du chargement des membres du groupe : ${membersSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (membersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final friendships = friendsSnapshot.data ?? [];
              final memberIds = membersSnapshot.data ?? [];

              final availableFriendships = friendships.where((friendship) {
                final friendId =
                    _friendshipRepository.getOtherUserId(friendship).trim();
                return friendId.isNotEmpty && !memberIds.contains(friendId);
              }).toList();

              if (availableFriendships.isEmpty) {
                return const Center(
                  child: Text(
                    'Aucun ami disponible à ajouter dans ce groupe.',
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: availableFriendships.length,
                itemBuilder: (context, index) {
                  final friendship = availableFriendships[index];
                  final friendId =
                      _friendshipRepository.getOtherUserId(friendship).trim();
                  final fallbackName = _fallbackFriendName(friendship);

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _userService.getUserById(friendId),
                    builder: (context, userSnapshot) {
                      final user = userSnapshot.data;

                      final String pseudo =
                          (user?['pseudo'] ?? '').toString().trim();
                      final String prenom =
                          (user?['prenom'] ?? '').toString().trim();
                      final String nom =
                          (user?['nom'] ?? '').toString().trim();
                      final String lieu =
                          (user?['lieu'] ?? '').toString().trim();

                      String displayName = fallbackName;

                      if (pseudo.isNotEmpty) {
                        displayName = pseudo;
                      } else if (prenom.isNotEmpty && nom.isNotEmpty) {
                        displayName = '$prenom $nom';
                      } else if (prenom.isNotEmpty) {
                        displayName = prenom;
                      }

                      final isAdding = addingUserId == friendId;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(displayName),
                          subtitle: Text(
                            lieu.isNotEmpty ? lieu : 'Lieu non renseigné',
                          ),
                          trailing: ElevatedButton(
                            onPressed: isAdding
                                ? null
                                : () => _addMember(friendship, displayName),
                            child: isAdding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Ajouter'),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}