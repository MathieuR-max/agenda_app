import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/group_model.dart';
import 'package:agenda_app/repositories/group_chat_repository.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import '../03_activities/activity_detail_page.dart';
import 'add_group_member_page.dart';
import 'create_group_activity_page.dart';
import 'group_chat_page.dart';

class GroupDetailPage extends StatelessWidget {
  final String groupId;

  const GroupDetailPage({
    super.key,
    required this.groupId,
  });

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  String _groupVisibilityLabel(String visibility) {
    switch (visibility) {
      case GroupModel.visibilityFriends:
        return 'Entre amis';
      case GroupModel.visibilityPrivate:
      default:
        return 'Privé';
    }
  }

  Color _groupVisibilityChipBackground(String visibility) {
    switch (visibility) {
      case GroupModel.visibilityFriends:
        return Colors.green.shade100;
      case GroupModel.visibilityPrivate:
      default:
        return Colors.blueGrey.shade100;
    }
  }

  Color _groupVisibilityChipTextColor(String visibility) {
    switch (visibility) {
      case GroupModel.visibilityFriends:
        return Colors.green.shade800;
      case GroupModel.visibilityPrivate:
      default:
        return Colors.blueGrey.shade800;
    }
  }

  String _memberRoleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Organisateur';
      case 'member':
      default:
        return 'Membre';
    }
  }

  String _groupActivityTypeLabel(Activity activity) {
    if (activity.isMixedGroupActivity) {
      return 'Groupe + Public';
    }

    if (activity.isGroupPrivateActivity) {
      return 'Activité de groupe';
    }

    return 'Activité';
  }

  Color _activityTypeChipBackground(Activity activity) {
    if (activity.isMixedGroupActivity) {
      return Colors.teal.shade100;
    }

    if (activity.isGroupPrivateActivity) {
      return Colors.indigo.shade100;
    }

    return Colors.grey.shade200;
  }

  Color _activityTypeChipTextColor(Activity activity) {
    if (activity.isMixedGroupActivity) {
      return Colors.teal.shade800;
    }

    if (activity.isGroupPrivateActivity) {
      return Colors.indigo.shade800;
    }

    return Colors.grey.shade800;
  }

  String _groupActivityParticipantsLabel(Activity activity) {
    if (activity.hasUnlimitedPlaces) {
      return '${activity.participantCount} participant(s) • illimité';
    }

    return '${activity.participantCount} / ${activity.maxParticipants} participants';
  }

  Widget _buildChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOpenGroupChatButton({
    required BuildContext context,
    required GroupModel group,
    required GroupChatRepository groupChatRepository,
  }) {
    return StreamBuilder<int>(
      stream: groupChatRepository.watchUnreadCount(groupId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupChatPage(
                    groupId: groupId,
                    groupName: group.name,
                  ),
                ),
              );
            },
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: Text(
              unreadCount > 0
                  ? 'Ouvrir le chat du groupe ($unreadCount)'
                  : 'Ouvrir le chat du groupe',
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    GroupsRepository repository,
    GroupChatRepository groupChatRepository,
    String currentUserPseudo,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Quitter le groupe'),
          content: const Text(
            'Voulez-vous vraiment quitter ce groupe ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Quitter'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await repository.leaveGroup(groupId: groupId);

    if (success) {
      try {
        await groupChatRepository.sendSystemMessage(
          groupId: groupId,
          text: '$currentUserPseudo a quitté le groupe',
        );
      } catch (_) {}
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Vous avez quitté le groupe.'
              : 'Impossible de quitter le groupe.',
        ),
      ),
    );

    if (success && context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    GroupsRepository repository,
    GroupChatRepository groupChatRepository,
    String memberUserId,
    String pseudo,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Retirer ce membre'),
          content: Text(
            'Voulez-vous retirer ${pseudo.isNotEmpty ? pseudo : 'cet utilisateur'} du groupe ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Retirer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await repository.removeMember(
      groupId: groupId,
      userId: memberUserId,
    );

    if (success) {
      try {
        await groupChatRepository.sendSystemMessage(
          groupId: groupId,
          text:
              '${pseudo.isNotEmpty ? pseudo : 'Un utilisateur'} a été retiré du groupe',
        );
      } catch (_) {}
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Membre retiré du groupe'
              : 'Impossible de retirer ce membre',
        ),
      ),
    );
  }

  Future<void> _openCreateGroupActivityPage(
    BuildContext context,
    GroupModel group,
    GroupChatRepository groupChatRepository,
  ) async {
    final createdTitle = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupActivityPage(
          groupId: groupId,
          groupName: group.name,
        ),
      ),
    );

    if (createdTitle != null && createdTitle.trim().isNotEmpty) {
      try {
        await groupChatRepository.sendSystemMessage(
          groupId: groupId,
          text: 'L’activité "$createdTitle" a été créée pour le groupe',
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = GroupsRepository();
    final groupChatRepository = GroupChatRepository();
    final activityService = ActivityFirestoreService();
    final currentUserId = _currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du groupe'),
      ),
      body: StreamBuilder<GroupModel?>(
        stream: repository.watchGroup(groupId),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.hasError) {
            return Center(
              child: Text('Erreur groupe : ${groupSnapshot.error}'),
            );
          }

          if (!groupSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final group = groupSnapshot.data;

          if (group == null) {
            return const Center(
              child: Text('Groupe introuvable'),
            );
          }

          final bool isOwner = group.ownerId == currentUserId;
          final bool isMemberFromGroupDoc =
              currentUserId.isNotEmpty && group.memberIds.contains(currentUserId);

          if (!isMemberFromGroupDoc) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });

            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: repository.watchGroupMembers(groupId),
            builder: (context, membersSnapshot) {
              if (membersSnapshot.hasError) {
                return Center(
                  child: Text('Erreur membres : ${membersSnapshot.error}'),
                );
              }

              if (!membersSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final members = membersSnapshot.data ?? [];

              Map<String, dynamic>? currentUserMember;
              for (final member in members) {
                if ((member['userId'] ?? '').toString().trim() ==
                    currentUserId) {
                  currentUserMember = member;
                  break;
                }
              }

              final String currentUserRole =
                  (currentUserMember?['role'] ?? '').toString();
              final String currentUserPseudo =
                  (currentUserMember?['pseudo'] ?? 'Utilisateur').toString();

              final bool isMember = currentUserMember != null;
              final bool canLeaveGroup = isMember && currentUserRole != 'owner';

              return StreamBuilder<List<Activity>>(
                stream: activityService.getGroupActivities(groupId),
                builder: (context, activitiesSnapshot) {
                  if (activitiesSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erreur activités du groupe : ${activitiesSnapshot.error}',
                      ),
                    );
                  }

                  if (!activitiesSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final groupActivities = activitiesSnapshot.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              if (group.description.isNotEmpty)
                                Text(group.description)
                              else
                                const Text('Aucune description'),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildChip(
                                    label:
                                        _groupVisibilityLabel(group.visibility),
                                    backgroundColor:
                                        _groupVisibilityChipBackground(
                                      group.visibility,
                                    ),
                                    textColor: _groupVisibilityChipTextColor(
                                      group.visibility,
                                    ),
                                  ),
                                  _buildChip(
                                    label: 'Créateur : ${group.ownerPseudo}',
                                    backgroundColor: Colors.grey.shade200,
                                    textColor: Colors.grey.shade800,
                                  ),
                                ],
                              ),
                              if (isMember) ...[
                                const SizedBox(height: 16),
                                _buildOpenGroupChatButton(
                                  context: context,
                                  group: group,
                                  groupChatRepository: groupChatRepository,
                                ),
                              ],
                              if (isOwner) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddGroupMemberPage(
                                            groupId: groupId,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.person_add),
                                    label:
                                        const Text('Ajouter un ami au groupe'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openCreateGroupActivityPage(
                                      context,
                                      group,
                                      groupChatRepository,
                                    ),
                                    icon: const Icon(Icons.event),
                                    label: const Text(
                                      'Créer une activité pour ce groupe',
                                    ),
                                  ),
                                ),
                              ],
                              if (canLeaveGroup) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _confirmLeaveGroup(
                                      context,
                                      repository,
                                      groupChatRepository,
                                      currentUserPseudo,
                                    ),
                                    icon: const Icon(Icons.exit_to_app),
                                    label: const Text('Quitter le groupe'),
                                  ),
                                ),
                              ],
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
                                'Activités du groupe',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              if (groupActivities.isEmpty)
                                const Text('Aucune activité liée à ce groupe')
                              else
                                ...groupActivities.map((activity) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.event),
                                    title: Text(
                                      activity.title.isNotEmpty
                                          ? activity.title
                                          : 'Activité',
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${activity.day} • ${activity.startTime} - ${activity.endTime}',
                                        ),
                                        if (activity.location.trim().isNotEmpty)
                                          Text(activity.location.trim()),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildChip(
                                              label: _groupActivityTypeLabel(
                                                activity,
                                              ),
                                              backgroundColor:
                                                  _activityTypeChipBackground(
                                                activity,
                                              ),
                                              textColor:
                                                  _activityTypeChipTextColor(
                                                activity,
                                              ),
                                            ),
                                            _buildChip(
                                              label:
                                                  _groupActivityParticipantsLabel(
                                                activity,
                                              ),
                                              backgroundColor:
                                                  Colors.blue.shade100,
                                              textColor: Colors.blue.shade800,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ActivityDetailPage(
                                            activity: activity,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }),
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
                                'Membres',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              if (members.isEmpty)
                                const Text('Aucun membre')
                              else
                                ...members.map((member) {
                                  final pseudo =
                                      (member['pseudo'] ?? '').toString();
                                  final role =
                                      (member['role'] ?? '').toString();
                                  final memberUserId =
                                      (member['userId'] ?? '').toString();

                                  final bool canRemove = isOwner &&
                                      memberUserId.isNotEmpty &&
                                      memberUserId != group.ownerId;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.person),
                                    title: Text(
                                      pseudo.isNotEmpty
                                          ? pseudo
                                          : 'Utilisateur',
                                    ),
                                    subtitle: Text(_memberRoleLabel(role)),
                                    trailing: canRemove
                                        ? IconButton(
                                            tooltip: 'Retirer du groupe',
                                            icon: const Icon(Icons.close),
                                            onPressed: () =>
                                                _confirmRemoveMember(
                                              context,
                                              repository,
                                              groupChatRepository,
                                              memberUserId,
                                              pseudo,
                                            ),
                                          )
                                        : null,
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ],
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