import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/repositories/activity_invitation_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/activity_invitation_firestore_service.dart';
import 'package:agenda_app/features/03_activities/activity_detail_page.dart';

class InvitationsPage extends StatelessWidget {
  const InvitationsPage({super.key});

  Color _statusColor(ActivityInvitation invitation) {
    switch (invitation.status) {
      case ActivityInvitation.statusAccepted:
        return Colors.green;
      case ActivityInvitation.statusRefused:
        return Colors.red;
      case ActivityInvitation.statusCancelled:
        return Colors.grey;
      case ActivityInvitation.statusPending:
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(ActivityInvitation invitation) {
    switch (invitation.status) {
      case ActivityInvitation.statusAccepted:
        return 'Acceptée';
      case ActivityInvitation.statusRefused:
        return 'Refusée';
      case ActivityInvitation.statusCancelled:
        return 'Annulée';
      case ActivityInvitation.statusPending:
      default:
        return 'En attente';
    }
  }

  Future<void> _openActivityFromInvitation(
    BuildContext context,
    ActivityFirestoreService activityService,
    ActivityInvitation invitation,
  ) async {
    final activity = await activityService.getActivityById(invitation.activityId);

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

  Future<void> _acceptInvitation(
    BuildContext context,
    ActivityInvitationRepository invitationRepository,
    ActivityFirestoreService activityService,
    ActivityInvitation invitation,
  ) async {
    final accepted = await invitationRepository.acceptInvitation(invitation);

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

    final activity = await activityService.getActivityById(invitation.activityId);

    if (!context.mounted || activity == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(activity: activity),
      ),
    );
  }

  Future<void> _refuseInvitation(
    BuildContext context,
    ActivityInvitationRepository invitationRepository,
    ActivityInvitation invitation,
  ) async {
    final refused = await invitationRepository.refuseInvitation(invitation.id);

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
  }

  @override
  Widget build(BuildContext context) {
    final invitationService = ActivityInvitationFirestoreService();
    final invitationRepository = ActivityInvitationRepository();
    final activityService = ActivityFirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
      ),
      body: StreamBuilder<List<ActivityInvitation>>(
        stream: invitationService.getReceivedInvitations(),
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
            return const Center(
              child: Text('Aucune invitation'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              final statusColor = _statusColor(invitation);
              final statusLabel = _statusLabel(invitation);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openActivityFromInvitation(
                    context,
                    activityService,
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
                        Text(
                          '${invitation.activityDay} • ${invitation.activityStartTime}',
                        ),
                        const SizedBox(height: 4),
                        Text(invitation.activityLocation),
                        const SizedBox(height: 8),
                        Text('Invité par : ${invitation.fromUserPseudo}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
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
                                  onPressed: () => _acceptInvitation(
                                    context,
                                    invitationRepository,
                                    activityService,
                                    invitation,
                                  ),
                                  child: const Text('Accepter'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _refuseInvitation(
                                    context,
                                    invitationRepository,
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
            },
          );
        },
      ),
    );
  }
}