import 'package:flutter/material.dart';
import 'package:agenda_app/features/03_activities/activity_detail_page.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/repositories/activity_invitation_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/activity_invitation_firestore_service.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  late final ActivityInvitationFirestoreService _invitationService;
  late final ActivityInvitationRepository _invitationRepository;
  late final ActivityFirestoreService _activityService;

  final Set<String> _busyInvitationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _invitationService = ActivityInvitationFirestoreService();
    _invitationRepository = ActivityInvitationRepository();
    _activityService = ActivityFirestoreService();
  }

  Color _statusTextColor(ActivityInvitation invitation) {
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

  Color _statusBackgroundColor(ActivityInvitation invitation) {
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

  String _statusLabel(ActivityInvitation invitation) {
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

  String _senderLabel(ActivityInvitation invitation) {
    final pseudo = invitation.fromUserPseudo.trim();
    if (pseudo.isNotEmpty) {
      return pseudo;
    }
    return 'Utilisateur';
  }

  bool _isBusy(String invitationId) => _busyInvitationIds.contains(invitationId);

  void _setBusy(String invitationId, bool value) {
    if (!mounted) return;

    setState(() {
      if (value) {
        _busyInvitationIds.add(invitationId);
      } else {
        _busyInvitationIds.remove(invitationId);
      }
    });
  }

  Future<void> _openActivityFromInvitation(
    BuildContext context,
    ActivityInvitation invitation,
  ) async {
    if (_isBusy(invitation.id)) return;

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

  Future<void> _acceptInvitation(
    BuildContext context,
    ActivityInvitation invitation,
  ) async {
    if (_isBusy(invitation.id)) return;

    _setBusy(invitation.id, true);

    try {
      final accepted =
          await _invitationRepository.acceptInvitation(invitation);

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
      _setBusy(invitation.id, false);
    }
  }

  Future<void> _refuseInvitation(
    BuildContext context,
    ActivityInvitation invitation,
  ) async {
    if (_isBusy(invitation.id)) return;

    _setBusy(invitation.id, true);

    try {
      final refused =
          await _invitationRepository.refuseInvitation(invitation.id);

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
      _setBusy(invitation.id, false);
    }
  }

  Widget _buildStatusChip(ActivityInvitation invitation) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _statusBackgroundColor(invitation),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(invitation),
        style: TextStyle(
          color: _statusTextColor(invitation),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInvitationCard(
    BuildContext context,
    ActivityInvitation invitation,
  ) {
    final isBusy = _isBusy(invitation.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isBusy
            ? null
            : () => _openActivityFromInvitation(
                  context,
                  invitation,
                ),
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
              Text('Invité par : ${_senderLabel(invitation)}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatusChip(invitation),
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
                            : () => _acceptInvitation(
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
                            : () => _refuseInvitation(
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

  Widget _buildEmptyState() {
    return const Center(
      child: Text('Aucune invitation'),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'INVITATIONS PAGE currentUserId=${_invitationService.currentUserId}',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
      ),
      body: StreamBuilder<List<ActivityInvitation>>(
        stream: _invitationService.getReceivedInvitations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur invitations : ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final invitations = snapshot.data ?? [];

          if (invitations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              return _buildInvitationCard(context, invitation);
            },
          );
        },
      ),
    );
  }
}