import 'package:agenda_app/services/current_user.dart';
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
    return AuthUser.uidOrNull?.trim() ?? '';
  }

  // ─── Preserved helpers ────────────────────────────────────────────────────

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
        return Colors.indigo.shade100;
    }
  }

  Color _groupVisibilityChipTextColor(String visibility) {
    switch (visibility) {
      case GroupModel.visibilityFriends:
        return Colors.green.shade800;
      case GroupModel.visibilityPrivate:
      default:
        return Colors.indigo.shade800;
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

  // ─── Style helpers ────────────────────────────────────────────────────────

  BoxDecoration _sectionDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200, width: 0.5),
    );
  }

  Color _avatarBackgroundColor(String pseudo) {
    const backgrounds = [
      Color(0xFFE8EAF6),
      Color(0xFFE8F5E9),
      Color(0xFFFFF3E0),
      Color(0xFFE0F2F1),
      Color(0xFFF3E5F5),
      Color(0xFFFCE4EC),
    ];
    if (pseudo.isEmpty) return const Color(0xFFF5F5F5);
    return backgrounds[pseudo.codeUnitAt(0) % backgrounds.length];
  }

  Color _avatarTextColor(String pseudo) {
    const textColors = [
      Color(0xFF3949AB),
      Color(0xFF388E3C),
      Color(0xFFF57C00),
      Color(0xFF00796B),
      Color(0xFF7B1FA2),
      Color(0xFFC2185B),
    ];
    if (pseudo.isEmpty) return const Color(0xFF757575);
    return textColors[pseudo.codeUnitAt(0) % textColors.length];
  }

  Widget _buildChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
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

  // ─── Section 1 : Header ───────────────────────────────────────────────────

  Widget _buildHeader(GroupModel group, int memberCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            group.description.isNotEmpty
                ? '${group.description} • $memberCount membre${memberCount > 1 ? 's' : ''}'
                : '$memberCount membre${memberCount > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                label: _groupVisibilityLabel(group.visibility),
                backgroundColor: _groupVisibilityChipBackground(group.visibility),
                textColor: _groupVisibilityChipTextColor(group.visibility),
              ),
              _buildChip(
                label: 'Créateur : ${group.ownerPseudo}',
                backgroundColor: Colors.grey.shade100,
                textColor: Colors.grey.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section 2 : Activités à venir ────────────────────────────────────────

  Widget _buildActivitiesSection(
    BuildContext context,
    List<Activity> activities,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade600, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Activités à venir',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                if (activities.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${activities.length}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: [
                  Icon(Icons.event_outlined, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    'Aucune activité pour ce groupe',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Créez la première activité !',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...activities.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              final isLast = index == activities.length - 1;

              final scheduleText =
                  '${activity.day} • ${activity.startTime} - ${activity.endTime}';

              final participantsText = activity.hasUnlimitedPlaces
                  ? '${activity.participantCount} part.'
                  : '${activity.participantCount}/${activity.maxParticipants}';

              return Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailPage(activity: activity),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.event,
                              color: Colors.green.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.title.isNotEmpty
                                      ? activity.title
                                      : 'Activité',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activity.location.trim().isNotEmpty
                                      ? '$scheduleText • ${activity.location.trim()}'
                                      : scheduleText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              participantsText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 16,
                      color: Colors.grey.shade100,
                    ),
                ],
              );
            }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─── Section 3 : CTA créer activité (owner only) ─────────────────────────

  Widget _buildCreateActivityButton(
    BuildContext context,
    GroupModel group,
    GroupChatRepository groupChatRepository,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () =>
            _openCreateGroupActivityPage(context, group, groupChatRepository),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Créer une activité pour ce groupe',
          style: TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ─── Section 4 : Membres ─────────────────────────────────────────────────

  Widget _buildMembersSection(
    BuildContext context,
    List<Map<String, dynamic>> members,
    String ownerId,
    bool isOwner,
    GroupsRepository repository,
    GroupChatRepository groupChatRepository,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Membres',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${members.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            Text('Aucun membre', style: TextStyle(color: Colors.grey.shade500))
          else
            ...members.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final pseudo = (member['pseudo'] ?? '').toString();
              final role = (member['role'] ?? '').toString();
              final memberUserId = (member['userId'] ?? '').toString();
              final isOwnerMember = memberUserId == ownerId;
              final canRemove = isOwner &&
                  memberUserId.isNotEmpty &&
                  memberUserId != ownerId;
              final initial =
                  pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?';
              final isLast = index == members.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _avatarBackgroundColor(pseudo),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: _avatarTextColor(pseudo),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pseudo.isNotEmpty ? pseudo : 'Utilisateur',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              if (isOwnerMember)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Organisateur',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  _memberRoleLabel(role),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (canRemove)
                          IconButton(
                            tooltip: 'Retirer du groupe',
                            icon: Icon(
                              Icons.more_horiz,
                              color: Colors.grey.shade400,
                            ),
                            onPressed: () => _confirmRemoveMember(
                              context,
                              repository,
                              groupChatRepository,
                              memberUserId,
                              pseudo,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, color: Colors.grey.shade100),
                ],
              );
            }),
          if (isOwner) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddGroupMemberPage(groupId: groupId),
                  ),
                );
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Ajouter un ami au groupe'),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Section 5 : Chat groupe ──────────────────────────────────────────────

  Widget _buildChatTile(
    BuildContext context,
    GroupModel group,
    GroupChatRepository groupChatRepository,
  ) {
    return Container(
      decoration: _sectionDecoration(),
      child: StreamBuilder<int>(
        stream: groupChatRepository.watchUnreadCount(groupId),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            title: Text(
              unreadCount > 0
                  ? 'Chat du groupe ($unreadCount)'
                  : 'Chat du groupe',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              "Proposez une activité plutôt qu'une longue discussion.",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: () async {
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
          );
        },
      ),
    );
  }

  // ─── Section 6 : Quitter le groupe ───────────────────────────────────────

  Widget _buildLeaveGroupTile(
    BuildContext context,
    GroupsRepository repository,
    GroupChatRepository groupChatRepository,
    String currentUserPseudo,
  ) {
    return Container(
      decoration: _sectionDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(Icons.exit_to_app, color: Colors.red.shade600),
        title: Text(
          'Quitter le groupe',
          style: TextStyle(
            color: Colors.red.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () => _confirmLeaveGroup(
          context,
          repository,
          groupChatRepository,
          currentUserPseudo,
        ),
      ),
    );
  }

  // ─── Dialogs (preserved) ──────────────────────────────────────────────────

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
          content: const Text('Voulez-vous vraiment quitter ce groupe ?'),
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
            "Voulez-vous retirer ${pseudo.isNotEmpty ? pseudo : 'cet utilisateur'} du groupe ?",
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
              "${pseudo.isNotEmpty ? pseudo : 'Un utilisateur'} a été retiré du groupe",
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
          text: "L'activité \"$createdTitle\" a été créée pour le groupe",
        );
      } catch (_) {}
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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
            return const Center(child: CircularProgressIndicator());
          }

          final group = groupSnapshot.data;

          if (group == null) {
            return const Center(child: Text('Groupe introuvable'));
          }

          final bool isOwner = group.ownerId == currentUserId;
          final bool isMemberFromGroupDoc =
              currentUserId.isNotEmpty &&
              group.memberIds.contains(currentUserId);

          if (!isMemberFromGroupDoc) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
            return const Center(child: CircularProgressIndicator());
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
                return const Center(child: CircularProgressIndicator());
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
              final bool canLeaveGroup =
                  isMember && currentUserRole != 'owner';

              return StreamBuilder<List<Activity>>(
                stream: activityService.getGroupActivities(groupId),
                builder: (context, activitiesSnapshot) {
                  if (activitiesSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erreur activités : ${activitiesSnapshot.error}',
                      ),
                    );
                  }

                  if (!activitiesSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final groupActivities = activitiesSnapshot.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Header
                      _buildHeader(group, members.length),
                      const SizedBox(height: 12),

                      // 2. Activités à venir
                      _buildActivitiesSection(context, groupActivities),
                      const SizedBox(height: 12),

                      // 3. CTA créer activité (owner only)
                      if (isOwner) ...[
                        _buildCreateActivityButton(
                          context,
                          group,
                          groupChatRepository,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 4. Membres
                      _buildMembersSection(
                        context,
                        members,
                        group.ownerId,
                        isOwner,
                        repository,
                        groupChatRepository,
                      ),
                      const SizedBox(height: 12),

                      // 5. Chat (membre only)
                      if (isMember) ...[
                        _buildChatTile(context, group, groupChatRepository),
                        const SizedBox(height: 12),
                      ],

                      // 6. Quitter le groupe (non-owner only)
                      if (canLeaveGroup) ...[
                        _buildLeaveGroupTile(
                          context,
                          repository,
                          groupChatRepository,
                          currentUserPseudo,
                        ),
                        const SizedBox(height: 12),
                      ],
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
