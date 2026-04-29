import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/repositories/chat_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';
import 'package:agenda_app/features/04_profile/user_profile_page.dart';
import 'package:agenda_app/features/05_chat/activity_chat_page.dart';
import 'package:agenda_app/features/03_activities/sent_invitations_page.dart';
import 'package:agenda_app/features/03_activities/edit_activity_page.dart';
import 'package:agenda_app/features/03_activities/invite_to_activity_page.dart';

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

  Color _activityTypeColor(Activity activity) {
    if (activity.isMixedGroupActivity) {
      return Colors.teal.shade100;
    }
    if (activity.isGroupActivity) {
      return Colors.indigo.shade100;
    }
    if (activity.visibility == Activity.visibilityPublic) {
      return Colors.blue.shade100;
    }
    return Colors.grey.shade300;
  }

  String _activityTypeLabel(Activity activity) {
    if (activity.isMixedGroupActivity) {
      return 'Groupe + Public';
    }
    if (activity.isGroupPrivateActivity) {
      return 'Activité de groupe';
    }
    if (activity.visibility == Activity.visibilityPublic) {
      return 'Activité publique';
    }
    return 'Privée';
  }

  String _groupInfoText(Activity activity) {
    final groupName = (activity.groupName ?? '').trim();

    if (groupName.isNotEmpty) {
      return activity.isMixedGroupActivity
          ? 'Activité liée au groupe "$groupName" et ouverte à de nouveaux participants'
          : 'Activité réservée au groupe "$groupName"';
    }

    return activity.isMixedGroupActivity
        ? 'Activité liée à un groupe et ouverte à de nouveaux participants'
        : 'Activité réservée à un groupe';
  }

  String _joinButtonLabel({
    required Activity activity,
    required bool isCancelled,
    required bool isDone,
    required bool isInviteOnly,
    required bool isFull,
  }) {
    if (isCancelled) return 'Activité annulée';
    if (isDone) return 'Activité terminée';
    if (activity.hasEnded) return 'Activité terminée';
    if (isInviteOnly) return 'Sur invitation';
    if (isFull) return 'Activité complète';
    if (activity.isMixedGroupActivity) {
      return 'Rejoindre l’activité groupe + public';
    }
    if (activity.isGroupPrivateActivity) {
      return 'Rejoindre l’activité du groupe';
    }
    return 'Rejoindre l’activité';
  }

  bool _canFullyEditActivity({
    required bool isOwner,
    required int participantCount,
  }) {
    return isOwner && participantCount <= 1;
  }

  bool _canPartiallyEditActivity({
    required bool isOwner,
    required int participantCount,
  }) {
    return isOwner && participantCount > 1;
  }

  String _editButtonLabel({
    required bool canFullyEdit,
    required bool canPartiallyEdit,
  }) {
    if (canFullyEdit) {
      return 'Modifier l’activité';
    }

    if (canPartiallyEdit) {
      return 'Modifier description et lieu';
    }

    return 'Modifier';
  }

  String _formatSchedule(Activity activity) {
    final scheduleLabel = activity.scheduleLabel.trim();

    if (scheduleLabel.isNotEmpty) {
      return scheduleLabel;
    }

    return '${activity.effectiveDay} • ${activity.effectiveStartTime} - ${activity.effectiveEndTime}';
  }

  String _chatButtonLabel({
    required bool isCancelled,
    required bool isDone,
    required bool hasEnded,
  }) {
    if (isCancelled) return 'Ouvrir le chat (lecture seule)';
    if (isDone || hasEnded) return 'Ouvrir le chat (lecture seule)';
    return 'Ouvrir le chat';
  }

  String? _chatInfoText({
    required bool isParticipant,
    required bool isOwner,
    required bool isCancelled,
    required bool isDone,
    required bool hasEnded,
  }) {
    if (isCancelled) {
      return 'Le chat reste accessible, mais aucun nouveau message ne peut être envoyé.';
    }

    if (isDone || hasEnded) {
      return 'Le chat reste accessible après l’activité, en lecture seule.';
    }

    if (isParticipant || isOwner) {
      return null;
    }

    return 'Vous pouvez consulter le chat de cette activité.';
  }

  Widget _buildOpenChatButton({
    required BuildContext context,
    required Activity activity,
    required ChatRepository chatRepository,
    required bool isCancelled,
    required bool isDone,
    required bool hasEnded,
  }) {
    return StreamBuilder<int>(
      stream: chatRepository.watchUnreadCount(activity.id),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openChat(
              context,
              activity: activity,
            ),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: Text(
              unreadCount > 0
                  ? '${_chatButtonLabel(
                      isCancelled: isCancelled,
                      isDone: isDone,
                      hasEnded: hasEnded,
                    )} ($unreadCount)'
                  : _chatButtonLabel(
                      isCancelled: isCancelled,
                      isDone: isDone,
                      hasEnded: hasEnded,
                    ),
            ),
          ),
        );
      },
    );
  }

  bool _canViewParticipants({
    required String participantVisibility,
    required bool isOwner,
    required bool isParticipant,
  }) {
    if (isOwner) return true;

    switch (participantVisibility.trim()) {
      case 'public':
        return true;
      case 'owner_only':
        return false;
      case 'friends':
        return isParticipant;
      case 'participants_only':
      default:
        return isParticipant;
    }
  }

  String _participantVisibilityInfoText({
    required String participantVisibility,
    required bool isOwner,
    required bool isParticipant,
  }) {
    if (isOwner) {
      return '';
    }

    switch (participantVisibility.trim()) {
      case 'public':
        return '';
      case 'owner_only':
        return 'La liste des participants est visible uniquement par l’organisateur.';
      case 'friends':
        return isParticipant
            ? ''
            : 'La liste des participants n’est pas visible publiquement.';
      case 'participants_only':
      default:
        return isParticipant
            ? ''
            : 'La liste des participants est réservée aux participants de cette activité.';
    }
  }

  Future<bool> _confirmAction({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _confirmLeaveActivity(
    BuildContext context,
    ActivityRepository activityRepository,
    String activityId,
    bool isOwner,
  ) async {
    final confirmed = await _confirmAction(
      context: context,
      title: isOwner ? 'Quitter en tant qu’organisateur' : 'Quitter l’activité',
      content: isOwner
          ? 'Voulez-vous vraiment quitter cette activité en tant qu’organisateur ?'
          : 'Voulez-vous vraiment quitter cette activité ?',
      confirmLabel: 'Quitter',
    );

    if (!confirmed) return;

    await activityRepository.leaveActivityWithOwnerHandling(activityId);

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
  }

  Future<void> _confirmDeleteActivity(
    BuildContext context,
    ActivityFirestoreService activityService,
    String activityId,
    int participantCount,
  ) async {
    final confirmed = await _confirmAction(
      context: context,
      title: 'Supprimer l’activité',
      content: 'Voulez-vous vraiment supprimer cette activité ?',
      confirmLabel: 'Supprimer',
    );

    if (!confirmed) return;

    if (participantCount > 1) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de supprimer : d’autres participants sont encore inscrits',
          ),
        ),
      );
      return;
    }

    try {
      await activityService.deleteActivityWithDependencies(activityId);

      if (!context.mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activité supprimée'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression : $e'),
        ),
      );
    }
  }

  Future<void> _openEditPage(
    BuildContext context, {
    required Activity activity,
    required int participantCount,
  }) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditActivityPage(
          activity: activity,
          participantCount: participantCount,
        ),
      ),
    );

    if (!context.mounted) return;

    if (updated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modifications enregistrées'),
        ),
      );
    }
  }

  void _openChat(
    BuildContext context, {
    required Activity activity,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityChatPage(
          activity: activity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activityService = ActivityFirestoreService();
    final activityRepository = ActivityRepository();
    final chatRepository = ChatRepository();
    final userService = UserFirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail activité'),
      ),
      body: StreamBuilder<Activity?>(
        stream: activityService.watchActivity(activity.id),
        builder: (context, activitySnapshot) {
          if (activitySnapshot.hasError) {
            return Center(
              child: Text('Erreur activité : ${activitySnapshot.error}'),
            );
          }

          if (activitySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final Activity? currentActivity = activitySnapshot.data;

          if (currentActivity == null) {
            return const Center(
              child: Text('Activité introuvable'),
            );
          }

          final String? currentUserId =
              FirebaseAuth.instance.currentUser?.uid.trim();

          if (currentUserId == null || currentUserId.isEmpty) {
            return const Center(
              child: Text('Utilisateur non connecté'),
            );
          }

          final String currentOwnerId = currentActivity.ownerId;
          final String currentOwnerPseudo = currentActivity.ownerPseudo;
          final bool ownerPending = currentActivity.ownerPending;

          final String title = currentActivity.title;
          final String description = currentActivity.description;
          final String location = currentActivity.location;
          final String category = currentActivity.category;
          final int maxParticipants = currentActivity.maxParticipants;
          final String status = currentActivity.status;
          final String visibility = currentActivity.visibility;
          final bool isGroupActivity = currentActivity.isGroupActivity;

          final bool isOwner = currentOwnerId == currentUserId;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<int>(
              stream: activityService.getParticipantCountStream(
                currentActivity.id,
              ),
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

                final bool canFullyEdit = _canFullyEditActivity(
                  isOwner: isOwner,
                  participantCount: participantCount,
                );

                final bool canPartiallyEdit = _canPartiallyEditActivity(
                  isOwner: isOwner,
                  participantCount: participantCount,
                );

                final bool canShowEditButton =
                    canFullyEdit || canPartiallyEdit;

                final String displayedMaxParticipants = maxParticipants > 0
                    ? maxParticipants.toString()
                    : 'Illimité';

                final int? remainingPlaces =
                    maxParticipants > 0 ? (maxParticipants - participantCount) : null;

                return StreamBuilder<List<String>>(
                  stream: activityService.getParticipants(currentActivity.id),
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
                    final bool hasEnded = currentActivity.hasEnded;

                    final bool canInvite = isOwner &&
                        !isCancelled &&
                        !isDone &&
                        !hasEnded &&
                        !ownerPending;

                    final bool canClaimOwnership =
                        ownerPending && isParticipant && !isOwner;

                    final bool canAttemptJoin =
                        !ownerPending && !isParticipant && !isOwner;

                    final String? chatInfoText = _chatInfoText(
                      isParticipant: isParticipant,
                      isOwner: isOwner,
                      isCancelled: isCancelled,
                      isDone: isDone,
                      hasEnded: hasEnded,
                    );

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection(FirestoreCollections.activities)
                          .doc(currentActivity.id)
                          .snapshots(),
                      builder: (context, privacySnapshot) {
                        final rawData = privacySnapshot.data?.data();

                        final participantVisibility =
                            (rawData?['participantVisibility'] ??
                                    'participants_only')
                                .toString()
                                .trim();

                        final canViewParticipants = _canViewParticipants(
                          participantVisibility: participantVisibility,
                          isOwner: isOwner,
                          isParticipant: isParticipant,
                        );

                        final participantInfoText =
                            _participantVisibilityInfoText(
                          participantVisibility: participantVisibility,
                          isOwner: isOwner,
                          isParticipant: isParticipant,
                        );

                        return SingleChildScrollView(
                          child: Column(
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
                                      color:
                                          _visibilityChipBackground(visibility),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _visibilityLabel(visibility),
                                      style: TextStyle(
                                        color:
                                            _visibilityChipTextColor(visibility),
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
                                      color: _activityTypeColor(currentActivity),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _activityTypeLabel(currentActivity),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (isGroupActivity)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.groups),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _groupInfoText(currentActivity),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                                  future:
                                      userService.getUserById(currentOwnerId),
                                  builder: (context, ownerSnapshot) {
                                    if (ownerSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.only(bottom: 10),
                                        child: Text(
                                          'Chargement de l’organisateur...',
                                        ),
                                      );
                                    }

                                    String ownerName =
                                        currentOwnerPseudo.trim();

                                    final owner = ownerSnapshot.data;

                                    if (ownerName.isEmpty && owner != null) {
                                      final String pseudo =
                                          (owner['pseudo'] ?? '')
                                              .toString()
                                              .trim();
                                      final String prenom =
                                          (owner['prenom'] ?? '')
                                              .toString()
                                              .trim();

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
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
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
                                            decoration:
                                                TextDecoration.underline,
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
                              Text(_formatSchedule(currentActivity)),
                              const SizedBox(height: 4),
                              Text(location),
                              const SizedBox(height: 4),
                              Text('Catégorie : $category'),
                              const SizedBox(height: 8),
                              Text(
                                currentActivity.hasUnlimitedPlaces
                                    ? 'Participants : $participantCount (illimité)'
                                    : 'Participants : $participantCount / $displayedMaxParticipants',
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
                              if (isDone || hasEnded) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Cette activité est terminée.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (isInviteOnly &&
                                  !isParticipant &&
                                  !isOwner) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Cette activité est accessible uniquement sur invitation.',
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (isGroupActivity &&
                                  !isParticipant &&
                                  !isOwner) ...[
                                const SizedBox(height: 10),
                                Text(
                                  currentActivity.isMixedGroupActivity
                                      ? 'Cette activité est liée à un groupe, mais elle accepte aussi de nouveaux participants.'
                                      : 'Cette activité est réservée aux membres du groupe.',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              const Text(
                                'Discussion',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildOpenChatButton(
                                context: context,
                                activity: currentActivity,
                                chatRepository: chatRepository,
                                isCancelled: isCancelled,
                                isDone: isDone,
                                hasEnded: hasEnded,
                              ),
                              if (chatInfoText != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  chatInfoText,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              if (canShowEditButton) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openEditPage(
                                      context,
                                      activity: currentActivity,
                                      participantCount: participantCount,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: Text(
                                      _editButtonLabel(
                                        canFullyEdit: canFullyEdit,
                                        canPartiallyEdit: canPartiallyEdit,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (canInvite) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Invitations',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => InviteToActivityPage(
                                            activity: currentActivity,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.group_add),
                                    label:
                                        const Text('Inviter (amis ou groupe)'),
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
                                    label: const Text(
                                      'Voir les invitations envoyées',
                                    ),
                                  ),
                                ),
                              ],
                              if (canClaimOwnership) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final accepted =
                                          await activityRepository
                                              .claimOwnership(
                                        currentActivity.id,
                                      );

                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            accepted
                                                ? 'Vous êtes devenu organisateur'
                                                : 'Un autre participant a déjà repris le rôle',
                                          ),
                                        ),
                                      );
                                    },
                                    child:
                                        const Text('Je deviens organisateur'),
                                  ),
                                ),
                              ],
                              if (canAttemptJoin) ...[
                                const SizedBox(height: 12),
                                FutureBuilder<bool>(
                                  future: activityRepository.canJoinActivity(
                                    currentActivity,
                                  ),
                                  builder: (context, joinSnapshot) {
                                    if (!joinSnapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    final canJoin =
                                        joinSnapshot.data ?? false;

                                    return SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: canJoin
                                            ? () async {
                                                final joined =
                                                    await activityRepository
                                                        .joinActivity(
                                                  currentActivity,
                                                );

                                                if (!context.mounted) return;

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
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
                                          _joinButtonLabel(
                                            activity: currentActivity,
                                            isCancelled: isCancelled,
                                            isDone: isDone,
                                            isInviteOnly: isInviteOnly,
                                            isFull: isFull,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
                              if (!canViewParticipants) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    participantInfoText.isNotEmpty
                                        ? participantInfoText
                                        : 'La liste des participants n’est pas visible.',
                                  ),
                                ),
                              ] else
                                SizedBox(
                                  height: 250,
                                  child:
                                      StreamBuilder<List<Map<String, dynamic>>>(
                                    stream:
                                        activityService.getParticipantUsers(
                                      currentActivity.id,
                                    ),
                                    builder:
                                        (context, participantsSnapshot) {
                                      if (participantsSnapshot.hasError) {
                                        return Text(
                                          'Erreur participants : ${participantsSnapshot.error}',
                                        );
                                      }

                                      if (!participantsSnapshot.hasData) {
                                        return const Center(
                                          child:
                                              CircularProgressIndicator(),
                                        );
                                      }

                                      final participants =
                                          participantsSnapshot.data ?? [];

                                      if (participants.isEmpty) {
                                        return const Text(
                                          'Aucun participant trouvé',
                                        );
                                      }

                                      return ListView.builder(
                                        itemCount: participants.length,
                                        itemBuilder: (context, index) {
                                          final user = participants[index];

                                          final String userId =
                                              (user['id'] ?? '').toString();
                                          final String pseudo =
                                              (user['pseudo'] ?? '')
                                                  .toString();
                                          final String prenom =
                                              (user['prenom'] ?? '')
                                                  .toString();
                                          final String lieu =
                                              (user['lieu'] ?? '').toString();

                                          String participantTitle =
                                              pseudo.trim();

                                          if (participantTitle.isEmpty) {
                                            participantTitle =
                                                prenom.trim().isNotEmpty
                                                    ? prenom
                                                    : 'Utilisateur';
                                          }

                                          final bool participantIsOwner =
                                              userId == currentOwnerId &&
                                                  !ownerPending;

                                          return ListTile(
                                            leading:
                                                const Icon(Icons.person),
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                      Text(participantTitle),
                                                ),
                                                if (participantIsOwner)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration:
                                                        BoxDecoration(
                                                      color:
                                                          Colors.blue.shade100,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(12),
                                                    ),
                                                    child: Text(
                                                      'Organisateur',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .blue.shade800,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            onTap: userId.isEmpty
                                                ? null
                                                : () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            UserProfilePage(
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
                                    onPressed: () => _confirmLeaveActivity(
                                      context,
                                      activityRepository,
                                      currentActivity.id,
                                      isOwner,
                                    ),
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
                                    onPressed: () => _confirmDeleteActivity(
                                      context,
                                      activityService,
                                      currentActivity.id,
                                      participantCount,
                                    ),
                                    child: const Text('Supprimer l’activité'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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