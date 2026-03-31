import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/activity_invitation.dart';
import 'package:agenda_app/repositories/activity_invitation_repository.dart';
import 'package:agenda_app/services/firestore/activity_invitation_firestore_service.dart';

class SentInvitationsPage extends StatelessWidget {
  final Activity activity;

  const SentInvitationsPage({
    super.key,
    required this.activity,
  });

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

  String _displayUserName(ActivityInvitation invitation) {
    final pseudo = invitation.toUserPseudo.trim();
    if (pseudo.isNotEmpty) return pseudo;
    if (invitation.toUserId.trim().isNotEmpty) return invitation.toUserId;
    return 'Utilisateur';
  }

  Widget _buildSummaryChip({
    required String label,
    required int count,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label : $count',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _cancelInvitation(
    BuildContext context,
    ActivityInvitationRepository invitationRepository,
    ActivityInvitation invitation,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Annuler l’invitation'),
              content: Text(
                'Voulez-vous vraiment annuler l’invitation envoyée à ${_displayUserName(invitation)} ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Retour'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Annuler l’invitation'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    final cancelled =
        await invitationRepository.cancelInvitation(invitation.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cancelled
              ? 'Invitation annulée'
              : 'Impossible d’annuler l’invitation',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invitationService = ActivityInvitationFirestoreService();
    final invitationRepository = ActivityInvitationRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations envoyées'),
      ),
      body: StreamBuilder<List<ActivityInvitation>>(
        stream: invitationService.getSentInvitationsForActivity(activity.id),
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

          final pendingCount = invitations.where((i) => i.isPending).length;
          final acceptedCount = invitations.where((i) => i.isAccepted).length;
          final refusedCount = invitations.where((i) => i.isRefused).length;
          final cancelledCount = invitations.where((i) => i.isCancelled).length;

          if (invitations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucune invitation envoyée pour cette activité.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${activity.day} • ${activity.startTime} - ${activity.endTime}',
                    ),
                    const SizedBox(height: 2),
                    Text(activity.location),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSummaryChip(
                      label: 'En attente',
                      count: pendingCount,
                      backgroundColor: Colors.orange.shade100,
                      textColor: Colors.orange.shade800,
                    ),
                    _buildSummaryChip(
                      label: 'Acceptées',
                      count: acceptedCount,
                      backgroundColor: Colors.green.shade100,
                      textColor: Colors.green.shade800,
                    ),
                    _buildSummaryChip(
                      label: 'Refusées',
                      count: refusedCount,
                      backgroundColor: Colors.red.shade100,
                      textColor: Colors.red.shade800,
                    ),
                    _buildSummaryChip(
                      label: 'Annulées',
                      count: cancelledCount,
                      backgroundColor: Colors.grey.shade300,
                      textColor: Colors.grey.shade800,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: invitations.length,
                  itemBuilder: (context, index) {
                    final invitation = invitations[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayUserName(invitation),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (invitation.toUserId.trim().isNotEmpty &&
                                invitation.toUserPseudo.trim().isNotEmpty)
                              Text(
                                'Identifiant : ${invitation.toUserId}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Container(
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
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Activité : ${invitation.activityTitle}',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${invitation.activityDay} • ${invitation.activityStartTime}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              invitation.activityLocation,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (invitation.isPending) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelInvitation(
                                    context,
                                    invitationRepository,
                                    invitation,
                                  ),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Annuler l’invitation'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}