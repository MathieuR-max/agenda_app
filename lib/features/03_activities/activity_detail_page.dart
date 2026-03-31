import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';
import 'package:agenda_app/features/04_profile/user_profile_page.dart';
import 'package:agenda_app/features/05_chat/activity_chat_page.dart';
import 'package:agenda_app/features/03_activities/invite_user_page.dart';
import 'package:agenda_app/features/03_activities/sent_invitations_page.dart';

class ActivityDetailPage extends StatelessWidget {
  final Activity activity;

  const ActivityDetailPage({
    super.key,
    required this.activity,
  });

  Color _statusChipBackground(String status) {
    switch (status) {
      case Activity.statusCancelled:
        return Colors.red.shade100;
      case Activity.statusDone:
        return Colors.grey.shade300;
      case Activity.statusFull:
        return Colors.orange.shade100;
      case Activity.statusOpen:
      default:
        return Colors.green.shade100;
    }
  }

  Color _statusChipTextColor(String status) {
    switch (status) {
      case Activity.statusCancelled:
        return Colors.red.shade800;
      case Activity.statusDone:
        return Colors.grey.shade800;
      case Activity.statusFull:
        return Colors.orange.shade800;
      case Activity.statusOpen:
      default:
        return Colors.green.shade800;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case Activity.statusCancelled:
        return 'Annulée';
      case Activity.statusDone:
        return 'Terminée';
      case Activity.statusFull:
        return 'Complète';
      case Activity.statusOpen:
      default:
        return 'Ouverte';
    }
  }

  Color _visibilityChipBackground(String visibility) {
    switch (visibility) {
      case Activity.visibilityInviteOnly:
        return Colors.purple.shade100;
      case Activity.visibilityPrivate:
        return Colors.blueGrey.shade100;
      case Activity.visibilityPublic:
      default:
        return Colors.blue.shade100;
    }
  }

  Color _visibilityChipTextColor(String visibility) {
    switch (visibility) {
      case Activity.visibilityInviteOnly:
        return Colors.purple.shade800;
      case Activity.visibilityPrivate:
        return Colors.blueGrey.shade800;
      case Activity.visibilityPublic:
      default:
        return Colors.blue.shade800;
    }
  }

  String _visibilityLabel(String visibility) {
    switch (visibility) {
      case Activity.visibilityInviteOnly:
        return 'Sur invitation';
      case Activity.visibilityPrivate:
        return 'Privée';
      case Activity.visibilityPublic:
      default:
        return 'Publique';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityService = ActivityFirestoreService();
    final activityRepository = ActivityRepository();
    final userService = UserFirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail activité'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: activityService.watchActivity(activity.id),
        builder: (context, activitySnapshot) {
          if (activitySnapshot.hasError) {
            return Center(
              child: Text('Erreur activité : ${activitySnapshot.error}'),
            );
          }

          if (!activitySnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final activityData = activitySnapshot.data;

          if (activityData == null) {
            return const Center(
              child: Text('Activité introuvable'),
            );
          }

          final Activity currentActivity = Activity.fromMap(
            activity.id,
            activityData,
          );

          final String currentOwnerId = currentActivity.ownerId;
          final String currentOwnerPseudo = currentActivity.ownerPseudo;
          final bool ownerPending = currentActivity.ownerPending;

          final String title = currentActivity.title;
          final String description = currentActivity.description;
          final String day = currentActivity.day;
          final String startTime = currentActivity.startTime;
          final String endTime = currentActivity.endTime;
          final String location = currentActivity.location;
          final String category = currentActivity.category;
          final int maxParticipants = currentActivity.maxParticipants;
          final String status = currentActivity.status;
          final String visibility = currentActivity.visibility;

          final String currentUserId = CurrentUser.id;
          final bool isOwner = currentOwnerId == currentUserId;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<int>(
              stream: activityService.getParticipantCountStream(activity.id),
              builder: (context, countSnapshot) {
                if (countSnapshot.hasError) {
                  return Center(
                    child: Text('Erreur compteur : ${countSnapshot.error}'),
                  );
                }

                if (!countSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final int participantCount = countSnapshot.data ?? 0;

                final String displayedMaxParticipants = maxParticipants > 0
                    ? maxParticipants.toString()
                    : 'Non défini';

                final int? remainingPlaces = maxParticipants > 0
                    ? (maxParticipants - participantCount)
                    : null;

                return StreamBuilder<List<String>>(
                  stream: activityService.getParticipants(activity.id),
                  builder: (context, participantIdsSnapshot) {
                    if (participantIdsSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Erreur participants : ${participantIdsSnapshot.error}',
                        ),
                      );
                    }

                    if (!participantIdsSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final participantIds = participantIdsSnapshot.data ?? [];
                    final bool isParticipant =
                        participantIds.contains(currentUserId);

                    final bool isFull = currentActivity.isFull ||
                        (maxParticipants > 0 &&
                            participantCount >= maxParticipants);

                    final bool isCancelled = currentActivity.isCancelled;
                    final bool isDone = currentActivity.isDone;
                    final bool isInviteOnly = currentActivity.isInviteOnly;

                    final bool canJoin = !ownerPending &&
                        !isParticipant &&
                        !isOwner &&
                        !isFull &&
                        !isCancelled &&
                        !isDone &&
                        !isInviteOnly;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusChipBackground(status),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: _statusChipTextColor(status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _visibilityChipBackground(visibility),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _visibilityLabel(visibility),
                                style: TextStyle(
                                  color: _visibilityChipTextColor(visibility),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (ownerPending)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.shade300,
                              ),
                            ),
                            child: const Text(
                              'Cette activité n’a plus d’organisateur.\nUn participant peut reprendre le rôle.',
                            ),
                          )
                        else if (currentOwnerId.isNotEmpty)
                          FutureBuilder<Map<String, dynamic>?>(
                            future: userService.getUserById(currentOwnerId),
                            builder: (context, ownerSnapshot) {
                              if (ownerSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Text('Chargement de l’organisateur...'),
                                );
                              }

                              String ownerName = currentOwnerPseudo.trim();

                              final owner = ownerSnapshot.data;
                              if (ownerName.isEmpty && owner != null) {
                                final String pseudo =
                                    (owner['pseudo'] ?? '').toString().trim();
                                final String prenom =
                                    (owner['prenom'] ?? '').toString().trim();

                                ownerName = pseudo.isNotEmpty
                                    ? pseudo
                                    : (prenom.isNotEmpty
                                        ? prenom
                                        : 'Utilisateur inconnu');
                              }

                              if (ownerName.isEmpty) {
                                ownerName = 'Utilisateur inconnu';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UserProfilePage(
                                          userId: currentOwnerId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Organisé par : $ownerName',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        if (description.trim().isNotEmpty) ...[
                          Text(description),
                          const SizedBox(height: 10),
                        ],
                        Text('$day • $startTime - $endTime'),
                        const SizedBox(height: 4),
                        Text(location),
                        const SizedBox(height: 4),
                        Text('Catégorie : $category'),
                        const SizedBox(height: 8),
                        Text(
                          maxParticipants > 0
                              ? 'Participants : $participantCount / $displayedMaxParticipants'
                              : 'Participants : $participantCount',
                        ),
                        if (remainingPlaces != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              remainingPlaces > 0
                                  ? 'Places restantes : $remainingPlaces'
                                  : 'Activité complète',
                              style: TextStyle(
                                color: remainingPlaces > 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (isCancelled) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Cette activité est annulée.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (isDone) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Cette activité est terminée.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (isInviteOnly && !isParticipant && !isOwner) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Cette activité est accessible uniquement sur invitation.',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ActivityChatPage(
                                    activity: currentActivity,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Ouvrir le chat'),
                          ),
                        ),
                        if (isOwner && !isCancelled && !isDone) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InviteUserPage(
                                      activity: currentActivity,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Inviter un utilisateur'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SentInvitationsPage(
                                      activity: currentActivity,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.outgoing_mail),
                              label: const Text('Voir les invitations envoyées'),
                            ),
                          ),
                        ],
                        if (ownerPending && isParticipant && !isOwner) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final accepted = await activityRepository
                                    .claimOwnership(activity.id);

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      accepted
                                          ? 'Vous êtes devenu organisateur'
                                          : 'Un autre participant a déjà repris le rôle',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Je deviens organisateur'),
                            ),
                          ),
                        ],
                        if (!ownerPending && !isParticipant && !isOwner) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: canJoin
                                  ? () async {
                                      final joined = await activityRepository
                                          .joinActivity(currentActivity);

                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            joined
                                                ? 'Vous avez rejoint l’activité'
                                                : 'Impossible de rejoindre l’activité',
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Text(
                                isCancelled
                                    ? 'Activité annulée'
                                    : isDone
                                        ? 'Activité terminée'
                                        : isInviteOnly
                                            ? 'Sur invitation'
                                            : isFull
                                                ? 'Activité complète'
                                                : 'Rejoindre l’activité',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'Participants',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: activityService.getParticipantUsers(
                              activity.id,
                            ),
                            builder: (context, participantsSnapshot) {
                              if (participantsSnapshot.hasError) {
                                return Text(
                                  'Erreur participants : ${participantsSnapshot.error}',
                                );
                              }

                              if (!participantsSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final participants =
                                  participantsSnapshot.data ?? [];

                              if (participants.isEmpty) {
                                return const Text('Aucun participant trouvé');
                              }

                              return ListView.builder(
                                itemCount: participants.length,
                                itemBuilder: (context, index) {
                                  final user = participants[index];

                                  final String userId =
                                      (user['id'] ?? '').toString();
                                  final String pseudo =
                                      (user['pseudo'] ?? '').toString();
                                  final String prenom =
                                      (user['prenom'] ?? '').toString();
                                  final String lieu =
                                      (user['lieu'] ?? '').toString();

                                  String participantTitle = pseudo.trim();
                                  if (participantTitle.isEmpty) {
                                    participantTitle = prenom.trim().isNotEmpty
                                        ? prenom
                                        : 'Utilisateur';
                                  }

                                  final bool participantIsOwner =
                                      userId == currentOwnerId && !ownerPending;

                                  return ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(participantTitle),
                                        ),
                                        if (participantIsOwner)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Organisateur',
                                              style: TextStyle(
                                                color: Colors.blue.shade800,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      lieu.trim().isNotEmpty
                                          ? lieu
                                          : 'Lieu non renseigné',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: userId.isEmpty
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => UserProfilePage(
                                                  userId: userId,
                                                ),
                                              ),
                                            );
                                          },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isParticipant)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                await activityRepository
                                    .leaveActivityWithOwnerHandling(activity.id);

                                if (!context.mounted) return;

                                Navigator.pop(context);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isOwner
                                          ? 'Vous avez quitté l’activité en tant qu’organisateur'
                                          : 'Vous avez quitté l’activité',
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                isOwner
                                    ? 'Quitter en tant qu’organisateur'
                                    : 'Quitter l’activité',
                              ),
                            ),
                          ),
                        if (isOwner) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final deleted = await activityService
                                    .deleteActivityIfNoParticipants(activity.id);

                                if (!context.mounted) return;

                                if (deleted) {
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Activité supprimée'),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Impossible de supprimer : d’autres participants sont encore inscrits',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Supprimer l’activité'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}