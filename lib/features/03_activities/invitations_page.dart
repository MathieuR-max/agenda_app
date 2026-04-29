import 'package:flutter/material.dart';
import 'package:agenda_app/features/03_activities/activity_detail_page.dart';
import 'package:agenda_app/features/06_groups/group_detail_page.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/models/group_invitation.dart';
import 'package:agenda_app/repositories/activity_invitation_repository.dart';
import 'package:agenda_app/repositories/group_invitation_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/activity_invitation_firestore_service.dart';
import 'package:agenda_app/services/firestore/group_invitation_firestore_service.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  late final ActivityInvitationFirestoreService _activityInvitationService;
  late final ActivityInvitationRepository _activityInvitationRepository;
  late final ActivityFirestoreService _activityService;

  late final GroupInvitationFirestoreService _groupInvitationService;
  late final GroupInvitationRepository _groupInvitationRepository;

  final Set<String> _busyActivityInvitationIds = <String>{};
  final Set<String> _busyGroupInvitationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _activityInvitationService = ActivityInvitationFirestoreService();
    _activityInvitationRepository = ActivityInvitationRepository();
    _activityService = ActivityFirestoreService();

    _groupInvitationService = GroupInvitationFirestoreService();
    _groupInvitationRepository = GroupInvitationRepository();
  }

  Color _activityStatusTextColor(ActivityInvitation invitation) {
    switch (invitation.status) {
      case ActivityInvitation.statusAccepted:
        return Colors.green.shade800;
      case ActivityInvitation.statusRefused:
        return Colors.red.shade800;
      case ActivityInvitation.statusCancelled:
        return Colors.grey.shade800;
      case ActivityInvitation.statusPending:
      default:
        return Colors.orange.shade800;
    }
  }

  Color _activityStatusBackgroundColor(ActivityInvitation invitation) {
    switch (invitation.status) {
      case ActivityInvitation.statusAccepted:
        return Colors.green.shade100;
      case ActivityInvitation.statusRefused:
        return Colors.red.shade100;
      case ActivityInvitation.statusCancelled:
        return Colors.grey.shade300;
      case ActivityInvitation.statusPending:
      default:
        return Colors.orange.shade100;
    }
  }

  Color _groupStatusTextColor(GroupInvitation invitation) {
    switch (invitation.status) {
      case GroupInvitation.statusAccepted:
        return Colors.green.shade800;
      case GroupInvitation.statusRefused:
        return Colors.red.shade800;
      case GroupInvitation.statusCancelled:
        return Colors.grey.shade800;
      case GroupInvitation.statusPending:
      default:
        return Colors.orange.shade800;
    }
  }

  Color _groupStatusBackgroundColor(GroupInvitation invitation) {
    switch (invitation.status) {
      case GroupInvitation.statusAccepted:
        return Colors.green.shade100;
      case GroupInvitation.statusRefused:
        return Colors.red.shade100;
      case GroupInvitation.statusCancelled:
        return Colors.grey.shade300;
      case GroupInvitation.statusPending:
      default:
        return Colors.orange.shade100;
    }
  }

  String _activityStatusLabel(ActivityInvitation invitation) {
    return invitation.statusLabel;
  }

  String _groupStatusLabel(GroupInvitation invitation) {
    return invitation.statusLabel;
  }

  String _scheduleLabel(ActivityInvitation invitation) {
    final day = invitation.activityDay.trim();
    final startTime = invitation.activityStartTime.trim();

    if (day.isNotEmpty && startTime.isNotEmpty) {
      return '$day • $startTime';
    }

    if (day.isNotEmpty) {
      return day;
    }

    return startTime;
  }

  String _activitySenderLabel(ActivityInvitation invitation) {
    final pseudo = invitation.fromUserPseudo.trim();
    if (pseudo.isNotEmpty) {
      return pseudo;
    }
    return 'Utilisateur';
  }

  String _groupSenderLabel(GroupInvitation invitation) {
    final pseudo = invitation.fromUserPseudo.trim();
    if (pseudo.isNotEmpty) {
      return pseudo;
    }
    return 'Utilisateur';
  }

  bool _isActivityBusy(String invitationId) =>
      _busyActivityInvitationIds.contains(invitationId);

  void _setActivityBusy(String invitationId, bool value) {
    if (!mounted) return;

    setState(() {
      if (value) {
        _busyActivityInvitationIds.add(invitationId);
      } else {
        _busyActivityInvitationIds.remove(invitationId);
      }
    });
  }

  bool _isGroupBusy(String invitationId) =>
      _busyGroupInvitationIds.contains(invitationId);

  void _setGroupBusy(String invitationId, bool value) {
    if (!mounted) return;

    setState(() {
      if (value) {
        _busyGroupInvitationIds.add(invitationId);
      } else {
        _busyGroupInvitationIds.remove(invitationId);
      }
    });
  }

  Future<void> _openActivityFromInvitation(
    BuildContext context,
    ActivityInvitation invitation,
  ) async {
    if (_isActivityBusy(invitation.id)) return;

    final activity =
        await _activityService.getActivityById(invitation.activityId);

    if (!context.mounted) return;

    if (activity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette activité n’existe plus'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(activity: activity),
      ),
    );
  }

  Future<void> _openAcceptedActivityIfAvailable(
    BuildContext context,
    ActivityInvitation invitation,
  ) async {
    final activity =
        await _activityService.getActivityById(invitation.activityId);

    if (!context.mounted) return;

    if (activity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invitation acceptée, mais l’activité n’est plus disponible',
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(activity: activity),
      ),
    );
  }

  Future<void> _openGroupFromInvitation(
    BuildContext context,
    GroupInvitation invitation,
  ) async {
    if (_isGroupBusy(invitation.id)) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(groupId: invitation.groupId),
      ),
    );
  }

  Future<void> _openAcceptedGroup(
    BuildContext context,
    GroupInvitation invitation,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(groupId: invitation.groupId),
      ),
    );
  }

  Future<void> _acceptActivityInvitation(
    BuildContext context,
    ActivityInvitation invitation,
  ) async {
    if (_isActivityBusy(invitation.id)) return;

    _setActivityBusy(invitation.id, true);

    try {
      final accepted =
          await _activityInvitationService.acceptInvitation(invitation);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'Invitation acceptée'
                : 'Impossible d’accepter l’invitation',
          ),
        ),
      );

      if (!accepted) return;

      await _openAcceptedActivityIfAvailable(context, invitation);
    } finally {
      _setActivityBusy(invitation.id, false);
    }
  }

  Future<void> _refuseActivityInvitation(
    BuildContext context,
    ActivityInvitation invitation,
  ) async {
    if (_isActivityBusy(invitation.id)) return;

    _setActivityBusy(invitation.id, true);

    try {
      final refused =
          await _activityInvitationService.declineInvitation(invitation);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            refused
                ? 'Invitation refusée'
                : 'Impossible de refuser l’invitation',
          ),
        ),
      );
    } finally {
      _setActivityBusy(invitation.id, false);
    }
  }

  Future<void> _acceptGroupInvitation(
    BuildContext context,
    GroupInvitation invitation,
  ) async {
    if (_isGroupBusy(invitation.id)) return;

    _setGroupBusy(invitation.id, true);

    try {
      final accepted =
          await _groupInvitationService.acceptInvitation(invitation);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'Invitation de groupe acceptée'
                : 'Impossible d’accepter l’invitation de groupe',
          ),
        ),
      );

      if (!accepted) return;

      await _openAcceptedGroup(context, invitation);
    } finally {
      _setGroupBusy(invitation.id, false);
    }
  }

  Future<void> _refuseGroupInvitation(
    BuildContext context,
    GroupInvitation invitation,
  ) async {
    if (_isGroupBusy(invitation.id)) return;

    _setGroupBusy(invitation.id, true);

    try {
      final refused =
          await _groupInvitationService.declineInvitation(invitation);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            refused
                ? 'Invitation de groupe refusée'
                : 'Impossible de refuser l’invitation de groupe',
          ),
        ),
      );
    } finally {
      _setGroupBusy(invitation.id, false);
    }
  }

  Widget _buildActivityStatusChip(ActivityInvitation invitation) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _activityStatusBackgroundColor(invitation),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _activityStatusLabel(invitation),
        style: TextStyle(
          color: _activityStatusTextColor(invitation),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGroupStatusChip(GroupInvitation invitation) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _groupStatusBackgroundColor(invitation),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _groupStatusLabel(invitation),
        style: TextStyle(
          color: _groupStatusTextColor(invitation),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActivityInvitationCard(
    BuildContext context,
    ActivityInvitation invitation,
  ) {
    final isBusy = _isActivityBusy(invitation.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isBusy
            ? null
            : () => _openActivityFromInvitation(context, invitation),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invitation.activityTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(_scheduleLabel(invitation)),
              const SizedBox(height: 4),
              Text(invitation.activityLocation),
              const SizedBox(height: 8),
              Text('Invité par : ${_activitySenderLabel(invitation)}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildActivityStatusChip(invitation),
                  const Spacer(),
                  if (isBusy)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                    ),
                ],
              ),
              if (invitation.isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isBusy
                            ? null
                            : () => _acceptActivityInvitation(
                                  context,
                                  invitation,
                                ),
                        child: const Text('Accepter'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => _refuseActivityInvitation(
                                  context,
                                  invitation,
                                ),
                        child: const Text('Refuser'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupInvitationCard(
    BuildContext context,
    GroupInvitation invitation,
  ) {
    final isBusy = _isGroupBusy(invitation.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isBusy ? null : () => _openGroupFromInvitation(context, invitation),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invitation.groupName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Invité par : ${_groupSenderLabel(invitation)}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildGroupStatusChip(invitation),
                  const Spacer(),
                  if (isBusy)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                    ),
                ],
              ),
              if (invitation.isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isBusy
                            ? null
                            : () => _acceptGroupInvitation(
                                  context,
                                  invitation,
                                ),
                        child: const Text('Accepter'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => _refuseGroupInvitation(
                                  context,
                                  invitation,
                                ),
                        child: const Text('Refuser'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String label) {
    return Center(
      child: Text(label),
    );
  }

  Widget _buildActivitiesTab() {
    return StreamBuilder<List<ActivityInvitation>>(
      stream: _activityInvitationService.getReceivedInvitations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur invitations activités : ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final invitations = snapshot.data ?? [];

        if (invitations.isEmpty) {
          return _buildEmptyState('Aucune invitation d’activité');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            final invitation = invitations[index];
            return _buildActivityInvitationCard(context, invitation);
          },
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    return StreamBuilder<List<GroupInvitation>>(
      stream: _groupInvitationService.getReceivedInvitations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur invitations groupes : ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final invitations = snapshot.data ?? [];

        if (invitations.isEmpty) {
          return _buildEmptyState('Aucune invitation de groupe');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            final invitation = invitations[index];
            return _buildGroupInvitationCard(context, invitation);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'INVITATIONS PAGE activityCurrentUserId=${_activityInvitationService.currentUserId}',
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invitations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Activités'),
              Tab(text: 'Groupes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildActivitiesTab(),
            _buildGroupsTab(),
          ],
        ),
      ),
    );
  }
}