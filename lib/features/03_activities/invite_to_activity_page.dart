import 'package:flutter/material.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/models/group_model.dart';
import 'package:agenda_app/repositories/activity_invitation_repository.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class InviteToActivityPage extends StatefulWidget {
  final Activity activity;

  const InviteToActivityPage({
    super.key,
    required this.activity,
  });

  @override
  State<InviteToActivityPage> createState() => _InviteToActivityPageState();
}

class _InviteToActivityPageState extends State<InviteToActivityPage>
    with SingleTickerProviderStateMixin {
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final ActivityInvitationRepository invitationRepository =
      ActivityInvitationRepository();
  final GroupsRepository groupsRepository = GroupsRepository();
  final UserFirestoreService userService = UserFirestoreService();
  final FriendshipRepository friendshipRepository = FriendshipRepository();

  final TextEditingController searchController = TextEditingController();

  late final TabController _tabController;
  late Future<List<Map<String, dynamic>>> _friendsFuture;

  String searchText = '';
  String? selectedGroupId;
  String? selectedGroupName;
  String groupActivityAccess = 'group_only';

  bool isSendingGroup = false;
  String? sendingFriendUserId;

  final Set<String> locallyInvitedUserIds = <String>{};

  final List<Map<String, String>> groupActivityAccessOptions = const [
    {
      'value': 'group_only',
      'label': 'Réservée au groupe',
    },
    {
      'value': 'group_and_public',
      'label': 'Groupe + nouveaux participants',
    },
  ];

  bool get hasSelectedGroup =>
      selectedGroupId != null && selectedGroupId!.trim().isNotEmpty;

  bool get isSelectedGroupAlreadyLinkedToActivity {
    final currentGroupId = widget.activity.groupId?.trim() ?? '';
    final pickedGroupId = selectedGroupId?.trim() ?? '';

    return currentGroupId.isNotEmpty &&
        pickedGroupId.isNotEmpty &&
        currentGroupId == pickedGroupId;
  }

  String _displayUserName(Map<String, dynamic> user) {
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

  String _groupInfoText() {
    final hasGroupName =
        selectedGroupName != null && selectedGroupName!.trim().isNotEmpty;
    final displayedGroupName = hasGroupName ? selectedGroupName!.trim() : '';

    if (groupActivityAccess == 'group_and_public') {
      return hasGroupName
          ? 'Activité liée au groupe "$displayedGroupName" et ouverte à de nouveaux participants.'
          : 'Activité liée à un groupe et ouverte à de nouveaux participants.';
    }

    return hasGroupName
        ? 'Activité réservée aux membres du groupe "$displayedGroupName".'
        : 'Activité réservée aux membres du groupe.';
  }

  Future<List<Friendship>> _loadAcceptedFriendships() async {
    final friendships = await friendshipRepository.getAcceptedFriendships();

    friendships.sort((a, b) {
      final aDate = a.respondedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.respondedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return friendships;
  }

  Future<List<Map<String, dynamic>>> _loadFriendsFromFriendships() async {
    final friendships = await _loadAcceptedFriendships();
    final List<Map<String, dynamic>> users = [];

    for (final friendship in friendships) {
      final friendId = friendshipRepository.getOtherUserId(friendship).trim();
      if (friendId.isEmpty) continue;

      final data = await userService.getUserById(friendId);
      if (data == null) continue;

      users.add({
        'id': friendId,
        ...data,
      });
    }

    users.sort((a, b) {
      final aName = _displayUserName(a).toLowerCase();
      final bName = _displayUserName(b).toLowerCase();
      return aName.compareTo(bName);
    });

    return users;
  }

  void _refreshFriends() {
    setState(() {
      _friendsFuture = _loadFriendsFromFriendships();
    });
  }

  String _friendStatusLabel({
    required String userId,
    required Set<String> participantIds,
    required Set<String> pendingInvitationIds,
  }) {
    if (userId == CurrentUser.id) {
      return 'Vous';
    }

    if (participantIds.contains(userId)) {
      return 'Déjà participant';
    }

    if (pendingInvitationIds.contains(userId) ||
        locallyInvitedUserIds.contains(userId)) {
      return 'Déjà invité';
    }

    return '';
  }

  Future<void> _inviteFriend(
    Activity currentActivity,
    Map<String, dynamic> user,
    Set<String> participantIds,
    Set<String> pendingInvitationIds,
  ) async {
    if (currentActivity.isCancelled ||
        currentActivity.isDone ||
        currentActivity.hasEnded) {
      return;
    }

    final userId = (user['id'] ?? '').toString().trim();
    final userName = _displayUserName(user);

    if (userId.isEmpty) return;
    if (userId == CurrentUser.id) return;
    if (participantIds.contains(userId)) return;
    if (pendingInvitationIds.contains(userId)) return;
    if (locallyInvitedUserIds.contains(userId)) return;
    if (sendingFriendUserId != null) return;

    setState(() {
      sendingFriendUserId = userId;
    });

    try {
      final sent = await invitationRepository.sendActivityInvitation(
        activity: currentActivity,
        toUserId: userId,
      );

      if (sent && mounted) {
        setState(() {
          locallyInvitedUserIds.add(userId);
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Invitation envoyée à $userName'
                : 'Impossible d’envoyer l’invitation à $userName',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l’invitation de $userName : $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          sendingFriendUserId = null;
        });
      }
    }
  }

  Future<void> _sendGroupInvitations(Activity currentActivity) async {
    if (isSendingGroup || !hasSelectedGroup) {
      return;
    }

    if (isSelectedGroupAlreadyLinkedToActivity) {
      return;
    }

    setState(() {
      isSendingGroup = true;
    });

    try {
      final memberIds =
          await groupsRepository.getGroupMemberIds(selectedGroupId!);

      final participantIdsList =
          await activityService.getParticipants(currentActivity.id).first;
      final participantIds = participantIdsList
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();

      final pendingInvitationIds = await invitationRepository
          .getPendingInvitationTargetIds(currentActivity.id);

      final effectiveVisibility = groupActivityAccess == 'group_and_public'
          ? ActivityVisibilityValues.public
          : ActivityVisibilityValues.private;

      await activityService.updateActivityFields(
        activityId: currentActivity.id,
        fields: {
          'groupId': selectedGroupId,
          'groupName': selectedGroupName,
          'groupType': 'Privé',
          'visibility': effectiveVisibility,
        },
      );

      final updatedActivity =
          await activityService.getActivityById(currentActivity.id);

      if (updatedActivity == null) {
        throw Exception('Activité introuvable après mise à jour.');
      }

      int sentCount = 0;
      final Set<String> newlyInvitedIds = <String>{};

      for (final memberId in memberIds) {
        final trimmedId = memberId.trim();

        if (trimmedId.isEmpty) continue;
        if (trimmedId == CurrentUser.id) continue;
        if (participantIds.contains(trimmedId)) continue;
        if (pendingInvitationIds.contains(trimmedId)) continue;
        if (locallyInvitedUserIds.contains(trimmedId)) continue;

        final sent = await invitationRepository.sendActivityInvitation(
          activity: updatedActivity,
          toUserId: trimmedId,
        );

        if (sent) {
          sentCount++;
          newlyInvitedIds.add(trimmedId);
        }
      }

      if (mounted && newlyInvitedIds.isNotEmpty) {
        setState(() {
          locallyInvitedUserIds.addAll(newlyInvitedIds);
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sentCount > 0
                ? '$sentCount invitation(s) envoyée(s) au groupe'
                : 'Aucune nouvelle invitation envoyée',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l’envoi au groupe : $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingGroup = false;
        });
      }
    }
  }

  Widget _buildHeader(Activity currentActivity) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentActivity.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${currentActivity.effectiveDay} • ${currentActivity.effectiveStartTime} - ${currentActivity.effectiveEndTime}',
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab(
    Activity currentActivity,
    bool readOnly,
    AsyncSnapshot<List<GroupModel>> groupsSnapshot,
  ) {
    final groups = groupsSnapshot.data ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (groupsSnapshot.connectionState == ConnectionState.waiting)
          const LinearProgressIndicator(),
        if (groupsSnapshot.hasError)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erreur chargement groupes : ${groupsSnapshot.error}'),
            ),
          ),
        if (groupsSnapshot.connectionState != ConnectionState.waiting &&
            !groupsSnapshot.hasError &&
            groups.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun groupe disponible.'),
            ),
          ),
        if (groups.isNotEmpty)
          ...groups.map((group) {
            final selected = selectedGroupId == group.id;
            final alreadyLinkedToActivity =
                (widget.activity.groupId?.trim() ?? '') == group.id.trim();

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.groups),
                title: Text(group.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.description.trim().isNotEmpty
                          ? group.description
                          : 'Aucune description',
                    ),
                    if (alreadyLinkedToActivity)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Déjà associé à cette activité',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: selected
                    ? Icon(
                        alreadyLinkedToActivity
                            ? Icons.check_circle
                            : Icons.radio_button_checked,
                        color: alreadyLinkedToActivity ? Colors.green : null,
                      )
                    : null,
                onTap: readOnly || isSendingGroup
                    ? null
                    : () {
                        setState(() {
                          selectedGroupId = group.id;
                          selectedGroupName = group.name;
                        });
                      },
              ),
            );
          }),
        if (hasSelectedGroup) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Groupe sélectionné : ${selectedGroupName ?? 'Groupe'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isSelectedGroupAlreadyLinkedToActivity) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.shade200,
                        ),
                      ),
                      child: const Text(
                        'Ce groupe est déjà associé à cette activité.',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: groupActivityAccess,
                    items: groupActivityAccessOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option['value']!,
                            child: Text(option['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: readOnly || isSendingGroup
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              groupActivityAccess = value;
                            });
                          },
                    decoration: const InputDecoration(
                      labelText: 'Accès à l’activité',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.shade200,
                      ),
                    ),
                    child: Text(_groupInfoText()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: readOnly ||
                              isSendingGroup ||
                              !hasSelectedGroup ||
                              isSelectedGroupAlreadyLinkedToActivity
                          ? null
                          : () => _sendGroupInvitations(currentActivity),
                      icon: isSendingGroup
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.groups),
                      label: const Text('Inviter ce groupe'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFriendsTab(
    Activity currentActivity,
    bool readOnly,
    AsyncSnapshot<List<Map<String, dynamic>>> friendsSnapshot,
    Set<String> participantIds,
    Set<String> pendingInvitationIds,
  ) {
    final allFriends = friendsSnapshot.data ?? [];
    final friends = allFriends.where(_matchesSearch).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: searchController,
          enabled: !readOnly,
          decoration: const InputDecoration(
            labelText: 'Rechercher un ami',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              searchText = value;
            });
          },
        ),
        const SizedBox(height: 14),
        if (friendsSnapshot.connectionState == ConnectionState.waiting)
          const LinearProgressIndicator(),
        if (friendsSnapshot.hasError)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erreur chargement amis : ${friendsSnapshot.error}',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _refreshFriends,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        if (friendsSnapshot.connectionState != ConnectionState.waiting &&
            !friendsSnapshot.hasError &&
            allFriends.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun ami disponible.'),
            ),
          ),
        if (allFriends.isNotEmpty && friends.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun ami ne correspond à la recherche.'),
            ),
          ),
        if (friends.isNotEmpty)
          ...friends.map((friend) {
            final userId = (friend['id'] ?? '').toString().trim();
            final lieu = (friend['lieu'] ?? '').toString().trim();
            final isCurrentUser = userId == CurrentUser.id;
            final isParticipant = participantIds.contains(userId);
            final isAlreadyInvited = pendingInvitationIds.contains(userId) ||
                locallyInvitedUserIds.contains(userId);
            final isSendingThisFriend = sendingFriendUserId == userId;

            final friendStatus = _friendStatusLabel(
              userId: userId,
              participantIds: participantIds,
              pendingInvitationIds: pendingInvitationIds,
            );

            final canInvite = !readOnly &&
                userId.isNotEmpty &&
                !isCurrentUser &&
                !isParticipant &&
                !isAlreadyInvited &&
                sendingFriendUserId == null;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(_displayUserName(friend)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lieu.isNotEmpty ? lieu : 'Lieu non renseigné',
                    ),
                    if (friendStatus.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          friendStatus,
                          style: TextStyle(
                            color: isParticipant || isAlreadyInvited
                                ? Colors.orange.shade800
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: canInvite
                      ? () => _inviteFriend(
                            currentActivity,
                            friend,
                            participantIds,
                            pendingInvitationIds,
                          )
                      : null,
                  child: isSendingThisFriend
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isParticipant
                              ? 'Participant'
                              : isAlreadyInvited
                                  ? 'Invité'
                                  : isCurrentUser
                                      ? 'Vous'
                                      : 'Inviter',
                        ),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    selectedGroupId = widget.activity.groupId?.trim().isEmpty ?? true
        ? null
        : widget.activity.groupId!.trim();

    selectedGroupName = widget.activity.groupName?.trim().isEmpty ?? true
        ? null
        : widget.activity.groupName!.trim();

    groupActivityAccess = widget.activity.isMixedGroupActivity
        ? 'group_and_public'
        : 'group_only';

    _friendsFuture = _loadFriendsFromFriendships();
  }

  @override
  void dispose() {
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Activity?>(
      stream: activityService.watchActivity(widget.activity.id),
      builder: (context, activitySnapshot) {
        if (activitySnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Inviter'),
            ),
            body: Center(
              child: Text('Erreur activité : ${activitySnapshot.error}'),
            ),
          );
        }

        if (activitySnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Inviter'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final currentActivity = activitySnapshot.data;

        if (currentActivity == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Inviter'),
            ),
            body: const Center(
              child: Text('Cette activité n’existe plus'),
            ),
          );
        }

        final bool readOnly = currentActivity.isCancelled ||
            currentActivity.isDone ||
            currentActivity.hasEnded;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Inviter'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.groups),
                  text: 'Groupes',
                ),
                Tab(
                  icon: Icon(Icons.person_add_alt_1),
                  text: 'Amis',
                ),
              ],
            ),
          ),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _friendsFuture,
            builder: (context, friendsSnapshot) {
              return StreamBuilder<List<GroupModel>>(
                stream: groupsRepository.watchMyGroups(),
                builder: (context, groupsSnapshot) {
                  return StreamBuilder<List<String>>(
                    stream: activityService.getParticipants(
                      currentActivity.id,
                    ),
                    builder: (context, participantsSnapshot) {
                      final participantIds = (participantsSnapshot.data ??
                              <String>[])
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toSet();

                      return StreamBuilder<Set<String>>(
                        stream:
                            invitationRepository.watchPendingInvitationTargetIds(
                          currentActivity.id,
                        ),
                        builder: (context, pendingInvitationsSnapshot) {
                          final pendingInvitationIds =
                              pendingInvitationsSnapshot.data ?? <String>{};

                          return Column(
                            children: [
                              if (readOnly)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  color: Colors.grey.shade300,
                                  child: Text(
                                    currentActivity.isCancelled
                                        ? 'Cette activité est annulée. Les invitations sont désactivées.'
                                        : 'Cette activité est terminée ou déjà passée. Les invitations sont désactivées.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              if (participantsSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  pendingInvitationsSnapshot.connectionState ==
                                      ConnectionState.waiting)
                                const LinearProgressIndicator(minHeight: 2),
                              _buildHeader(currentActivity),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildGroupsTab(
                                      currentActivity,
                                      readOnly,
                                      groupsSnapshot,
                                    ),
                                    _buildFriendsTab(
                                      currentActivity,
                                      readOnly,
                                      friendsSnapshot,
                                      participantIds,
                                      pendingInvitationIds,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      },
    );
  }
}