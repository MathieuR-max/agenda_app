import 'package:flutter/material.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/repositories/group_invitation_repository.dart';
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
  final GroupInvitationRepository _groupInvitationRepository =
      GroupInvitationRepository();
  final UserFirestoreService _userService = UserFirestoreService();

  late Future<List<Friendship>> _friendsFuture;
  late Future<List<String>> _groupMemberIdsFuture;
  late Future<Set<String>> _pendingInvitationIdsFuture;

  String? invitingUserId;

  @override
  void initState() {
    super.initState();
    _reloadData();
  }

  void _reloadData() {
    _friendsFuture = _loadFriends();
    _groupMemberIdsFuture = _loadGroupMemberIds();
    _pendingInvitationIdsFuture = _loadPendingInvitationIds();
  }

  Future<List<Friendship>> _loadFriends() {
    return _friendshipRepository.getAcceptedFriendships();
  }

  Future<List<String>> _loadGroupMemberIds() {
    return _groupsRepository.getGroupMemberIds(widget.groupId);
  }

  Future<Set<String>> _loadPendingInvitationIds() {
    return _groupInvitationRepository.getPendingInvitationTargetIds(
      widget.groupId,
    );
  }

  String _fallbackFriendName(Friendship friendship) {
    final pseudo = _friendshipRepository.getOtherUserPseudo(friendship).trim();
    final id = _friendshipRepository.getOtherUserId(friendship).trim();

    if (pseudo.isNotEmpty) return pseudo;
    if (id.isNotEmpty) return id;
    return 'Utilisateur';
  }

  String _buildDisplayName(
    Friendship friendship,
    Map<String, dynamic>? user,
  ) {
    final fallbackName = _fallbackFriendName(friendship);

    final String pseudo = (user?['pseudo'] ?? '').toString().trim();
    final String prenom = (user?['prenom'] ?? '').toString().trim();
    final String nom = (user?['nom'] ?? '').toString().trim();

    if (pseudo.isNotEmpty) {
      return pseudo;
    }

    if (prenom.isNotEmpty && nom.isNotEmpty) {
      return '$prenom $nom';
    }

    if (prenom.isNotEmpty) {
      return prenom;
    }

    return fallbackName;
  }

  Future<void> _sendInvitation(
    Friendship friendship,
    String displayName,
  ) async {
    final userId = _friendshipRepository.getOtherUserId(friendship).trim();

    debugPrint('GROUP INVITE target raw userId=$userId');
    debugPrint(
      'GROUP INVITE friendship requesterId=${friendship.requesterId} addresseeId=${friendship.addresseeId}',
    );

    if (userId.isEmpty || invitingUserId != null) {
      return;
    }

    setState(() {
      invitingUserId = userId;
    });

    try {
      final success = await _groupInvitationRepository.sendGroupInvitation(
        groupId: widget.groupId,
        toUserId: userId,
      );

      debugPrint(
        'GROUP INVITE sendGroupInvitation result=$success targetUserId=$userId groupId=${widget.groupId}',
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _reloadData();
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Invitation envoyée à $displayName.'
                : 'Impossible d’inviter $displayName dans le groupe.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          invitingUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inviter un ami'),
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

              return FutureBuilder<Set<String>>(
                future: _pendingInvitationIdsFuture,
                builder: (context, pendingSnapshot) {
                  if (pendingSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Erreur lors du chargement des invitations en attente : ${pendingSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (pendingSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final friendships = friendsSnapshot.data ?? [];
                  final memberIds = membersSnapshot.data ?? [];
                  final pendingInvitationIds =
                      pendingSnapshot.data ?? <String>{};

                  final availableFriendships = friendships.where((friendship) {
                    final friendId =
                        _friendshipRepository.getOtherUserId(friendship).trim();

                    return friendId.isNotEmpty &&
                        !memberIds.contains(friendId) &&
                        !pendingInvitationIds.contains(friendId);
                  }).toList();

                  if (availableFriendships.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucun ami disponible à inviter dans ce groupe.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: availableFriendships.length,
                    itemBuilder: (context, index) {
                      final friendship = availableFriendships[index];
                      final friendId =
                          _friendshipRepository.getOtherUserId(friendship)
                              .trim();

                      return FutureBuilder<Map<String, dynamic>?>(
                        future: _userService.getUserById(friendId),
                        builder: (context, userSnapshot) {
                          final user = userSnapshot.data;
                          final displayName =
                              _buildDisplayName(friendship, user);
                          final lieu = (user?['lieu'] ?? '').toString().trim();
                          final isInviting = invitingUserId == friendId;

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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    lieu.isNotEmpty
                                        ? lieu
                                        : 'Lieu non renseigné',
                                  ),
                                  if (user == null)
                                    const Text(
                                      'Utilisateur introuvable en base',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: isInviting
                                    ? null
                                    : () => _sendInvitation(
                                          friendship,
                                          displayName,
                                        ),
                                child: isInviting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Inviter'),
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
          );
        },
      ),
    );
  }
}