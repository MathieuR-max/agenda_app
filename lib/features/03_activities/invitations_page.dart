import 'package:flutter/material.dart';
import 'package:agenda_app/features/03_activities/activity_detail_page.dart';
import 'package:agenda_app/features/06_groups/group_detail_page.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/models/group_invitation.dart';
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
  late final ActivityFirestoreService _activityService;
  late final GroupInvitationFirestoreService _groupInvitationService;

  final Set<String> _busyActivityInvitationIds = <String>{};
  final Set<String> _busyGroupInvitationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _activityInvitationService = ActivityInvitationFirestoreService();
    _activityService = ActivityFirestoreService();
    _groupInvitationService = GroupInvitationFirestoreService();
  }

  Color _activityStatusTextColor(ActivityInvitation invitation) {
    switch (invitation.status) {
      case ActivityInvitation.statusAccepted:  return const Color(0xFF34C759);
      case ActivityInvitation.statusRefused:   return const Color(0xFFF9635E);
      case ActivityInvitation.statusCancelled: return const Color(0xFF6F6F6F);
      case ActivityInvitation.statusPending:
      default:                                 return const Color(0xFFF4B266);
    }
  }

  Color _activityStatusBackgroundColor(ActivityInvitation invitation) {
    switch (invitation.status) {
      case ActivityInvitation.statusAccepted:  return const Color(0xFFECFDF4);
      case ActivityInvitation.statusRefused:   return const Color(0xFFFFF0EF);
      case ActivityInvitation.statusCancelled: return const Color(0xFFF1EFEB);
      case ActivityInvitation.statusPending:
      default:                                 return const Color(0xFFFFF4E6);
    }
  }

  Color _groupStatusTextColor(GroupInvitation invitation) {
    switch (invitation.status) {
      case GroupInvitation.statusAccepted:  return const Color(0xFF34C759);
      case GroupInvitation.statusRefused:   return const Color(0xFFF9635E);
      case GroupInvitation.statusCancelled: return const Color(0xFF6F6F6F);
      case GroupInvitation.statusPending:
      default:                              return const Color(0xFFF4B266);
    }
  }

  Color _groupStatusBackgroundColor(GroupInvitation invitation) {
    switch (invitation.status) {
      case GroupInvitation.statusAccepted:  return const Color(0xFFECFDF4);
      case GroupInvitation.statusRefused:   return const Color(0xFFFFF0EF);
      case GroupInvitation.statusCancelled: return const Color(0xFFF1EFEB);
      case GroupInvitation.statusPending:
      default:                              return const Color(0xFFFFF4E6);
    }
  }

  String _scheduleLabel(ActivityInvitation invitation) {
    final day = invitation.activityDay.trim();
    final startTime = invitation.activityStartTime.trim();
    if (day.isNotEmpty && startTime.isNotEmpty) return '$day • $startTime';
    if (day.isNotEmpty) return day;
    return startTime;
  }

  String _activitySenderLabel(ActivityInvitation invitation) {
    final pseudo = invitation.fromUserPseudo.trim();
    return pseudo.isNotEmpty ? pseudo : 'Utilisateur';
  }

  String _groupSenderLabel(GroupInvitation invitation) {
    final pseudo = invitation.fromUserPseudo.trim();
    return pseudo.isNotEmpty ? pseudo : 'Utilisateur';
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
        const SnackBar(content: Text("Cette activité n'existe plus")),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: activity)),
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
          content: Text("Invitation acceptée, mais l'activité n'est plus disponible"),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: activity)),
    );
  }

  Future<void> _openGroupFromInvitation(
    BuildContext context,
    GroupInvitation invitation,
  ) async {
    if (_isGroupBusy(invitation.id)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: invitation.groupId)),
    );
  }

  Future<void> _openAcceptedGroup(
    BuildContext context,
    GroupInvitation invitation,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: invitation.groupId)),
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
        SnackBar(content: Text(accepted ? 'Invitation acceptée' : "Impossible d'accepter l'invitation")),
      );
      if (accepted) {
        await _openAcceptedActivityIfAvailable(context, invitation);
      }
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
        SnackBar(content: Text(refused ? 'Invitation refusée' : "Impossible de refuser l'invitation")),
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
        SnackBar(content: Text(accepted ? "Invitation de groupe acceptée" : "Impossible d'accepter l'invitation de groupe")),
      );
      if (accepted) {
        await _openAcceptedGroup(context, invitation);
      }
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
        SnackBar(content: Text(refused ? "Invitation de groupe refusée" : "Impossible de refuser l'invitation de groupe")),
      );
    } finally {
      _setGroupBusy(invitation.id, false);
    }
  }

  Widget _buildActivityStatusChip(ActivityInvitation invitation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _activityStatusBackgroundColor(invitation),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        invitation.statusLabel,
        style: TextStyle(
          color: _activityStatusTextColor(invitation),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildGroupStatusChip(GroupInvitation invitation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _groupStatusBackgroundColor(invitation),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        invitation.statusLabel,
        style: TextStyle(
          color: _groupStatusTextColor(invitation),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTabLabel(String label, int count) {
    if (count <= 0) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 8),
        Badge(label: Text(count > 99 ? '99+' : '$count')),
      ],
    );
  }

  Widget _buildActivityInvitationCard(
    BuildContext context,
    ActivityInvitation invitation,
  ) {
    final isBusy = _isActivityBusy(invitation.id);

    return GestureDetector(
      onTap: isBusy ? null : () => _openActivityFromInvitation(context, invitation),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      invitation.activityTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                  if (invitation.isPending) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9635E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              if (_scheduleLabel(invitation).isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Color(0xFF6F6F6F)),
                    const SizedBox(width: 4),
                    Text(
                      _scheduleLabel(invitation),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              if (invitation.activityLocation.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: Color(0xFF6F6F6F)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        invitation.activityLocation,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                'Invité par ${_activitySenderLabel(invitation)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildActivityStatusChip(invitation),
                  const Spacer(),
                  if (isBusy)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00B4A6),
                      ),
                    )
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
                            : () => _acceptActivityInvitation(context, invitation),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4A6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => _refuseActivityInvitation(context, invitation),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6F6F6F),
                          side: const BorderSide(color: Color(0xFFE6E2DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Refuser', style: TextStyle(fontWeight: FontWeight.w600)),
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

    return GestureDetector(
      onTap: isBusy ? null : () => _openGroupFromInvitation(context, invitation),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      invitation.groupName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                  if (invitation.isPending) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9635E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Invité par ${_groupSenderLabel(invitation)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildGroupStatusChip(invitation),
                  const Spacer(),
                  if (isBusy)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00B4A6),
                      ),
                    )
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
                            : () => _acceptGroupInvitation(context, invitation),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4A6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => _refuseGroupInvitation(context, invitation),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6F6F6F),
                          side: const BorderSide(color: Color(0xFFE6E2DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Refuser', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _buildActivityInvitationsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline, size: 64, color: Color(0xFFA8A8A8)),
            const SizedBox(height: 20),
            const Text(
              "Aucune invitation d'activité",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Quand quelqu'un vous invite à une activité, elle apparaîtra ici.",
              style: TextStyle(color: Color(0xFF6F6F6F)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupInvitationsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_outlined, size: 64, color: Color(0xFFA8A8A8)),
            const SizedBox(height: 20),
            const Text(
              'Aucune invitation de groupe',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Quand quelqu'un vous invite dans un groupe, il apparaîtra ici.",
              style: TextStyle(color: Color(0xFF6F6F6F)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesTab() {
    return StreamBuilder<List<ActivityInvitation>>(
      stream: _activityInvitationService.getReceivedInvitations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur invitations activités : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final invitations = snapshot.data ?? [];
        if (invitations.isEmpty) return _buildActivityInvitationsEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: invitations.length,
          itemBuilder: (context, index) =>
              _buildActivityInvitationCard(context, invitations[index]),
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    return StreamBuilder<List<GroupInvitation>>(
      stream: _groupInvitationService.getReceivedInvitations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur invitations groupes : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final invitations = snapshot.data ?? [];
        if (invitations.isEmpty) return _buildGroupInvitationsEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: invitations.length,
          itemBuilder: (context, index) =>
              _buildGroupInvitationCard(context, invitations[index]),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return StreamBuilder<List<ActivityInvitation>>(
      stream: _activityInvitationService.getPendingReceivedInvitations(),
      builder: (context, activitySnapshot) {
        final pendingActivityCount = activitySnapshot.data?.length ?? 0;

        return StreamBuilder<List<GroupInvitation>>(
          stream: _groupInvitationService.getPendingReceivedInvitations(),
          builder: (context, groupSnapshot) {
            final pendingGroupCount = groupSnapshot.data?.length ?? 0;

            return TabBar(
              labelColor: const Color(0xFF00B4A6),
              unselectedLabelColor: const Color(0xFF6F6F6F),
              indicatorColor: const Color(0xFF00B4A6),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(child: _buildTabLabel('Activités', pendingActivityCount)),
                Tab(child: _buildTabLabel('Groupes', pendingGroupCount)),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              children: [
                _buildActivitiesTab(),
                _buildGroupsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
