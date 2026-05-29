import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/repositories/chat_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';
import 'package:agenda_app/services/activity_clipboard_service.dart';
import 'package:agenda_app/features/04_profile/user_profile_page.dart';
import 'package:agenda_app/features/05_chat/activity_chat_page.dart';
import 'package:agenda_app/features/03_activities/sent_invitations_page.dart';
import 'package:agenda_app/features/03_activities/edit_activity_page.dart';
import 'package:agenda_app/features/03_activities/invite_to_activity_page.dart';

class _StickyData {
  final Activity activity;
  final ActivityRepository activityRepository;
  final bool isParticipant;
  final bool isOwner;
  final bool canAttemptJoin;
  final bool canClaimOwnership;
  final bool isCancelled;
  final bool isDone;
  final bool isFull;
  final bool isInviteOnly;
  final bool hasEnded;
  final int participantCount;

  const _StickyData({
    required this.activity,
    required this.activityRepository,
    required this.isParticipant,
    required this.isOwner,
    required this.canAttemptJoin,
    required this.canClaimOwnership,
    required this.isCancelled,
    required this.isDone,
    required this.isFull,
    required this.isInviteOnly,
    required this.hasEnded,
    required this.participantCount,
  });
}

class ActivityDetailPage extends StatefulWidget {
  final Activity activity;

  const ActivityDetailPage({
    super.key,
    required this.activity,
  });

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  final _stickyData = ValueNotifier<_StickyData?>(null);

  @override
  void dispose() {
    _stickyData.dispose();
    super.dispose();
  }

  bool _isPermissionDenied(Object? error) {
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('missing or insufficient permissions');
  }

  Widget _buildAccessLostView(
    BuildContext context, {
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Color(0xFFF4B266)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusChipBackground(String status) {
    switch (status) {
      case Activity.statusCancelled: return const Color(0xFFFFF0EF);
      case Activity.statusDone:      return const Color(0xFFF1EFEB);
      case Activity.statusFull:      return const Color(0xFFFFF0EF);
      case Activity.statusOpen:
      default:                       return const Color(0xFFECFDF4);
    }
  }

  Color _statusChipTextColor(String status) {
    switch (status) {
      case Activity.statusCancelled: return const Color(0xFFF9635E);
      case Activity.statusDone:      return const Color(0xFF6F6F6F);
      case Activity.statusFull:      return const Color(0xFFF9635E);
      case Activity.statusOpen:
      default:                       return const Color(0xFF34C759);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case Activity.statusCancelled: return 'Annulée';
      case Activity.statusDone:      return 'Terminée';
      case Activity.statusFull:      return 'Complète';
      case Activity.statusOpen:
      default:                       return 'Ouverte';
    }
  }

  Color _visibilityChipBackground(String visibility) {
    switch (visibility) {
      case Activity.visibilityInviteOnly: return const Color(0xFFF0EEFF);
      case Activity.visibilityPrivate:    return const Color(0xFFF1EFEB);
      case Activity.visibilityPublic:
      default:                            return const Color(0xFFECFDF4);
    }
  }

  Color _visibilityChipTextColor(String visibility) {
    switch (visibility) {
      case Activity.visibilityInviteOnly: return const Color(0xFF8B80F9);
      case Activity.visibilityPrivate:    return const Color(0xFF6F6F6F);
      case Activity.visibilityPublic:
      default:                            return const Color(0xFF00B4A6);
    }
  }

  String _visibilityLabel(String visibility) {
    switch (visibility) {
      case Activity.visibilityInviteOnly: return 'Sur invitation';
      case Activity.visibilityPrivate:    return 'Privée';
      case Activity.visibilityPublic:
      default:                            return 'Publique';
    }
  }

  Color _activityTypeColor(Activity activity) {
    if (activity.isMixedGroupActivity) return const Color(0xFFB8ECE6);
    if (activity.isGroupActivity) return const Color(0xFFF0EEFF);
    if (activity.visibility == Activity.visibilityPublic) return const Color(0xFFECFDF4);
    return const Color(0xFFF1EFEB);
  }

  String? _activityTypeLabel(Activity activity) {
    if (activity.isMixedGroupActivity) return 'Groupe + Public';
    if (activity.isGroupPrivateActivity) return 'Activité de groupe';
    return null;
  }

  String _joinButtonLabel({
    required Activity activity,
    required bool isCancelled,
    required bool isDone,
    required bool isInviteOnly,
    required bool isFull,
  }) {
    if (isCancelled) return 'Activité annulée';
    if (isDone || activity.hasEnded) return 'Activité terminée';
    if (isInviteOnly) return 'Sur invitation';
    if (isFull) return 'Activité complète';
    if (activity.isMixedGroupActivity) return "Rejoindre l'activité groupe + public";
    if (activity.isGroupPrivateActivity) return "Rejoindre l'activité du groupe";
    return "Rejoindre l'activité";
  }

  bool _canFullyEditActivity({required bool isOwner, required int participantCount}) {
    return isOwner && participantCount <= 1;
  }

  bool _canPartiallyEditActivity({required bool isOwner, required int participantCount}) {
    return isOwner && participantCount > 1;
  }

  String _editButtonLabel({required bool canFullyEdit, required bool canPartiallyEdit}) {
    if (canFullyEdit) return "Modifier l'activité";
    if (canPartiallyEdit) return 'Modifier description et lieu';
    return 'Modifier';
  }

  String _formatSchedule(Activity activity) {
    final scheduleLabel = activity.scheduleLabel.trim();
    if (scheduleLabel.isNotEmpty) return scheduleLabel;
    return '${activity.effectiveDay} • ${activity.effectiveStartTime} - ${activity.effectiveEndTime}';
  }

  String _chatButtonLabel({required bool isCancelled, required bool isDone, required bool hasEnded}) {
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
    if (isCancelled) return 'Le chat reste accessible, mais aucun nouveau message ne peut être envoyé.';
    if (isDone || hasEnded) return "Le chat reste accessible après l'activité, en lecture seule.";
    if (isParticipant || isOwner) return null;
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
          child: OutlinedButton.icon(
            onPressed: () => _openChat(context, activity: activity),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00B4A6),
              side: const BorderSide(color: Color(0xFF00B4A6), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: Text(
              unreadCount > 0
                  ? '${_chatButtonLabel(isCancelled: isCancelled, isDone: isDone, hasEnded: hasEnded)} ($unreadCount)'
                  : _chatButtonLabel(isCancelled: isCancelled, isDone: isDone, hasEnded: hasEnded),
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
      case 'public':              return true;
      case 'owner_only':         return false;
      case 'friends':            return isParticipant;
      case 'participants_only':
      default:                   return isParticipant;
    }
  }

  String _participantVisibilityInfoText({
    required String participantVisibility,
    required bool isOwner,
    required bool isParticipant,
  }) {
    if (isOwner) return '';
    switch (participantVisibility.trim()) {
      case 'public':
        return '';
      case 'owner_only':
        return "La liste des participants est visible uniquement par l'organisateur.";
      case 'friends':
        return isParticipant ? '' : "La liste des participants n'est pas visible publiquement.";
      case 'participants_only':
      default:
        return isParticipant ? '' : "La liste des participants est réservée aux participants de cette activité.";
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
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(confirmLabel)),
        ],
      ),
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
      title: isOwner ? "Quitter en tant qu'organisateur" : "Quitter l'activité",
      content: isOwner
          ? "Voulez-vous vraiment quitter cette activité en tant qu'organisateur ? Les autres participants pourront reprendre le rôle d'organisateur."
          : "Voulez-vous vraiment quitter cette activité ?",
      confirmLabel: 'Quitter',
    );
    if (!confirmed) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await activityRepository.leaveActivityWithOwnerHandling(activityId);
      messenger.showSnackBar(SnackBar(content: Text(
        isOwner
            ? "Vous avez quitté l'activité. Un autre participant pourra devenir organisateur."
            : "Vous avez quitté l'activité.",
      )));
      navigator.pop();
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text("Erreur lors de la sortie de l'activité : $e")));
    }
  }

  Future<void> _confirmDeleteActivity(
    BuildContext context,
    ActivityFirestoreService activityService,
    String activityId,
    int participantCount,
  ) async {
    if (participantCount > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Suppression impossible : des participants ont rejoint l'activité")),
      );
      return;
    }
    final confirmed = await _confirmAction(
      context: context,
      title: "Supprimer l'activité",
      content: "Voulez-vous vraiment supprimer cette activité ?",
      confirmLabel: 'Supprimer',
    );
    if (!confirmed) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await activityService.deleteActivityWithDependencies(activityId);
      messenger.showSnackBar(const SnackBar(content: Text('Activité supprimée')));
      navigator.pop();
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Erreur lors de la suppression : $e')));
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
        builder: (_) => EditActivityPage(activity: activity, participantCount: participantCount),
      ),
    );
    if (!context.mounted) return;
    if (updated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modifications enregistrées')),
      );
    }
  }

  void _copyActivity(BuildContext context, {required Activity activity}) {
    ActivityClipboardService.copy(activity);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Activité copiée. Choisis un créneau dans l'agenda pour la coller.")),
    );
  }

  void _openChat(BuildContext context, {required Activity activity}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityChatPage(activity: activity)));
  }

  Widget _infoRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6F6F6F)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E1E)))),
      ],
    );
  }

  Widget _chip({required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _pluralParticipants(int count) {
    return count <= 1 ? '$count participant' : '$count participants';
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E1E1E))),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStickyBottom(BuildContext context, _StickyData data) {
    if (!data.canAttemptJoin && !data.isParticipant && !data.canClaimOwnership) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Color(0xFFFCFBF8),
        border: Border(top: BorderSide(color: Color(0xFFEDE9E3), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.canAttemptJoin)
            FutureBuilder<bool>(
              future: data.activityRepository.canJoinActivity(data.activity),
              builder: (context, joinSnapshot) {
                final canJoin = joinSnapshot.data ?? false;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canJoin ? () async {
                      final joined = await data.activityRepository.joinActivity(data.activity);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                        joined ? "Vous avez rejoint l'activité" : "Impossible de rejoindre l'activité",
                      )));
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4A6),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFF1EFEB),
                      disabledForegroundColor: const Color(0xFFA8A8A8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      _joinButtonLabel(
                        activity: data.activity,
                        isCancelled: data.isCancelled,
                        isDone: data.isDone,
                        isInviteOnly: data.isInviteOnly,
                        isFull: data.isFull,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          if (data.canClaimOwnership)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reprise du rôle en cours...'), duration: Duration(seconds: 1)),
                    );
                    final accepted = await data.activityRepository.claimOwnership(data.activity.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                      accepted
                          ? 'Vous êtes devenu organisateur'
                          : "Impossible. Un autre participant a peut-être déjà repris le rôle.",
                    )));
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4A6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Je deviens organisateur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          if (data.isParticipant) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmLeaveActivity(
                  context, data.activityRepository, data.activity.id, data.isOwner,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF0EF),
                  foregroundColor: const Color(0xFFF9635E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  data.isOwner ? "Quitter en tant qu'organisateur" : "Quitter l'activité",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            if (data.isOwner && data.participantCount <= 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _confirmDeleteActivity(
                    context, ActivityFirestoreService(), data.activity.id, data.participantCount,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF9635E),
                    side: const BorderSide(color: Color(0xFFF9635E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text("Supprimer l'activité", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ],
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
      appBar: AppBar(title: const Text('Détail activité')),
      bottomNavigationBar: ValueListenableBuilder<_StickyData?>(
        valueListenable: _stickyData,
        builder: (context, data, _) {
          if (data == null) return const SizedBox.shrink();
          return _buildStickyBottom(context, data);
        },
      ),
      body: StreamBuilder<Activity?>(
        stream: activityService.watchActivity(widget.activity.id),
        builder: (context, activitySnapshot) {
          if (activitySnapshot.hasError) {
            if (_isPermissionDenied(activitySnapshot.error)) {
              return _buildAccessLostView(context,
                  message: "Vous n'avez plus accès à cette activité. Elle a peut-être été supprimée, rendue privée, ou vous l'avez quittée.");
            }
            return Center(child: Text('Erreur activité : ${activitySnapshot.error}'));
          }
          if (activitySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentActivity = activitySnapshot.data;
          if (currentActivity == null) {
            return _buildAccessLostView(context,
                message: "Cette activité est introuvable. Elle a peut-être été supprimée.");
          }

          final currentUserId = AuthUser.uidOrNull?.trim();
          if (currentUserId == null || currentUserId.isEmpty) {
            return const Center(child: Text('Utilisateur non connecté'));
          }

          final currentOwnerId = currentActivity.ownerId.trim();
          final ownerPending = currentActivity.ownerPending;
          final title = currentActivity.title;
          final description = currentActivity.description;
          final location = currentActivity.location;
          final category = currentActivity.category;
          final maxParticipants = currentActivity.maxParticipants;
          final status = currentActivity.status;
          final visibility = currentActivity.visibility;
          final isGroupActivity = currentActivity.isGroupActivity;
          final isOwner = currentOwnerId == currentUserId;

          return StreamBuilder<int>(
            stream: activityService.getParticipantCountStream(currentActivity.id),
            builder: (context, countSnapshot) {
              if (countSnapshot.hasError) {
                if (_isPermissionDenied(countSnapshot.error)) {
                  return _buildAccessLostView(context,
                      message: "Vous n'avez plus accès à cette activité. Elle a peut-être été supprimée, rendue privée, ou vous l'avez quittée.");
                }
                return Center(child: Text('Erreur compteur : ${countSnapshot.error}'));
              }
              if (!countSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              final participantCount = countSnapshot.data ?? 0;
              final canFullyEdit = _canFullyEditActivity(isOwner: isOwner, participantCount: participantCount);
              final canPartiallyEdit = _canPartiallyEditActivity(isOwner: isOwner, participantCount: participantCount);
              final canShowEditButton = canFullyEdit || canPartiallyEdit;
              final displayedMaxParticipants = maxParticipants > 0 ? maxParticipants.toString() : 'Illimité';
              final int? remainingPlaces = maxParticipants > 0 ? maxParticipants - participantCount : null;

              return StreamBuilder<List<String>>(
                stream: activityService.getParticipants(currentActivity.id),
                builder: (context, participantIdsSnapshot) {
                  if (participantIdsSnapshot.hasError) {
                    if (_isPermissionDenied(participantIdsSnapshot.error) && currentActivity.isPublic && !isOwner) {
                      // Permission denied expected for non-participants on public activities.
                    } else if (_isPermissionDenied(participantIdsSnapshot.error)) {
                      return _buildAccessLostView(context,
                          message: "Vous n'avez plus accès aux participants de cette activité. Si vous venez de quitter l'activité, vous pouvez revenir à l'écran précédent.");
                    } else {
                      return Center(child: Text('Erreur participants : ${participantIdsSnapshot.error}'));
                    }
                  }
                  if (!participantIdsSnapshot.hasData && !participantIdsSnapshot.hasError) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final participantIds = participantIdsSnapshot.hasError ? <String>[] : (participantIdsSnapshot.data ?? []);
                  final normalizedParticipantIds = participantIds.map((id) => id.trim()).toSet();
                  final isParticipant = normalizedParticipantIds.contains(currentUserId);
                  final isFull = currentActivity.isFull || (maxParticipants > 0 && participantCount >= maxParticipants);
                  final isCancelled = currentActivity.isCancelled;
                  final isDone = currentActivity.isDone;
                  final isInviteOnly = currentActivity.isInviteOnly;
                  final hasEnded = currentActivity.hasEnded;
                  final canInvite = isOwner && !isCancelled && !isDone && !hasEnded && !ownerPending;
                  final canClaimOwnership = ownerPending && isParticipant && !isOwner;
                  final canAttemptJoin = !ownerPending && !isParticipant && !isOwner;
                  final chatInfoText = _chatInfoText(
                    isParticipant: isParticipant, isOwner: isOwner,
                    isCancelled: isCancelled, isDone: isDone, hasEnded: hasEnded,
                  );

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(FirestoreCollections.activities)
                        .doc(currentActivity.id)
                        .snapshots(),
                    builder: (context, privacySnapshot) {
                      if (privacySnapshot.hasError &&
                          _isPermissionDenied(privacySnapshot.error) &&
                          (!currentActivity.isPublic || isOwner)) {
                        return _buildAccessLostView(context,
                            message: "Vous n'avez plus accès à cette activité. Elle a peut-être été supprimée, rendue privée, ou vous l'avez quittée.");
                      }

                      final rawData = privacySnapshot.hasError ? null : privacySnapshot.data?.data();
                      final participantVisibility = (rawData?['participantVisibility'] ?? 'participants_only').toString().trim();
                      final canViewParticipants = _canViewParticipants(
                        participantVisibility: participantVisibility, isOwner: isOwner, isParticipant: isParticipant,
                      );
                      final participantInfoText = _participantVisibilityInfoText(
                        participantVisibility: participantVisibility, isOwner: isOwner, isParticipant: isParticipant,
                      );

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _stickyData.value = _StickyData(
                          activity: currentActivity,
                          activityRepository: activityRepository,
                          isParticipant: isParticipant,
                          isOwner: isOwner,
                          canAttemptJoin: canAttemptJoin,
                          canClaimOwnership: canClaimOwnership,
                          isCancelled: isCancelled,
                          isDone: isDone,
                          isFull: isFull,
                          isInviteOnly: isInviteOnly,
                          hasEnded: hasEnded,
                          participantCount: participantCount,
                        );
                      });

                      return SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Header ──────────────────────────────
                              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E1E1E))),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _chip(label: _statusLabel(status), bg: _statusChipBackground(status), fg: _statusChipTextColor(status)),
                                  _chip(label: _visibilityLabel(visibility), bg: _visibilityChipBackground(visibility), fg: _visibilityChipTextColor(visibility)),
                                  if (_activityTypeLabel(currentActivity) != null)
                                    _chip(label: _activityTypeLabel(currentActivity)!, bg: _activityTypeColor(currentActivity), fg: const Color(0xFF00B4A6)),
                                  _chip(label: category, bg: const Color(0xFFF0EEFF), fg: const Color(0xFF8B80F9)),
                                  _chip(
                                    label: currentActivity.hasUnlimitedPlaces
                                        ? '${_pluralParticipants(participantCount)} • Illimité'
                                        : '${_pluralParticipants(participantCount)} • $displayedMaxParticipants places',
                                    bg: const Color(0xFFECFDF4),
                                    fg: const Color(0xFF34C759),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _infoRow(Icons.schedule_outlined, _formatSchedule(currentActivity)),
                              const SizedBox(height: 6),
                              if (location.isNotEmpty) ...[
                                _infoRow(Icons.place_outlined, location),
                                const SizedBox(height: 6),
                              ],
                              if (ownerPending)
                                _infoRow(Icons.person_outline, 'Organisateur non défini')
                              else if (currentOwnerId.isNotEmpty)
                                FutureBuilder<Map<String, dynamic>?>(
                                  future: userService.getUserById(currentOwnerId),
                                  builder: (context, ownerSnapshot) {
                                    String ownerName = currentActivity.ownerPseudo.trim();
                                    final owner = ownerSnapshot.data;
                                    if (ownerName.isEmpty && owner != null) {
                                      final pseudo = (owner['pseudo'] ?? '').toString().trim();
                                      final prenom = (owner['prenom'] ?? '').toString().trim();
                                      ownerName = pseudo.isNotEmpty ? pseudo : prenom.isNotEmpty ? prenom : 'Utilisateur inconnu';
                                    }
                                    if (ownerName.isEmpty) ownerName = 'Utilisateur inconnu';
                                    final showHistory = currentActivity.organizerDisplayLabel.isNotEmpty
                                        && !currentActivity.organizerDisplayLabel.startsWith('Créée par');
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                          onTap: () => Navigator.push(context,
                                            MaterialPageRoute(builder: (_) => UserProfilePage(userId: currentOwnerId))),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.person_outline, size: 15, color: Color(0xFF6F6F6F)),
                                              const SizedBox(width: 6),
                                              Text('Organisateur : $ownerName',
                                                  style: const TextStyle(fontSize: 14, color: Color(0xFF00B4A6), fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        if (showHistory) ...[
                                          const SizedBox(height: 2),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 21),
                                            child: Text(currentActivity.organizerDisplayLabel,
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF6F6F6F))),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              if (description.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(description, style: const TextStyle(fontSize: 14, color: Color(0xFF6F6F6F))),
                              ],
                              // ── Messages état ───────────────────────
                              if (remainingPlaces != null && remainingPlaces <= 0)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text('Activité complète', style: TextStyle(color: Color(0xFFF9635E), fontWeight: FontWeight.w600)),
                                ),
                              if (isCancelled) ...[
                                const SizedBox(height: 8),
                                const Text('Cette activité est annulée.', style: TextStyle(color: Color(0xFFF9635E), fontWeight: FontWeight.w600)),
                              ],
                              if (isDone || hasEnded) ...[
                                const SizedBox(height: 8),
                                const Text('Cette activité est terminée.', style: TextStyle(color: Color(0xFF6F6F6F), fontWeight: FontWeight.w600)),
                              ],
                              if (isInviteOnly && !isParticipant && !isOwner) ...[
                                const SizedBox(height: 8),
                                const Text('Cette activité est accessible uniquement sur invitation.',
                                    style: TextStyle(color: Color(0xFF8B80F9), fontWeight: FontWeight.w600)),
                              ],
                              if (isGroupActivity && !isParticipant && !isOwner) ...[
                                const SizedBox(height: 8),
                                Text(
                                  currentActivity.isMixedGroupActivity
                                      ? "Cette activité est liée à un groupe, mais elle accepte aussi de nouveaux participants."
                                      : "Cette activité est réservée aux membres du groupe.",
                                  style: const TextStyle(color: Color(0xFF00B4A6), fontWeight: FontWeight.w600),
                                ),
                              ],
                              if (ownerPending) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4E6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFF4B266).withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    "Cette activité n'a plus d'organisateur.\nUn participant peut reprendre le rôle.",
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                              // ── Discussion ──────────────────────────
                              const SizedBox(height: 20),
                              _sectionCard(
                                title: 'Discussion',
                                children: [
                                  _buildOpenChatButton(
                                    context: context, activity: currentActivity,
                                    chatRepository: chatRepository,
                                    isCancelled: isCancelled, isDone: isDone, hasEnded: hasEnded,
                                  ),
                                  if (chatInfoText != null) ...[
                                    const SizedBox(height: 8),
                                    Text(chatInfoText, style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F))),
                                  ],
                                ],
                              ),
                              // ── Actions / Outils ─────────────────────
                              const SizedBox(height: 12),
                              _sectionCard(
                                title: canShowEditButton ? 'Actions' : 'Outils',
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _copyActivity(context, activity: currentActivity),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF1E1E1E),
                                        side: const BorderSide(color: Color(0xFFE6E2DB)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      icon: const Icon(Icons.copy_outlined),
                                      label: const Text("Copier l'activité"),
                                    ),
                                  ),
                                  if (canShowEditButton) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _openEditPage(context, activity: currentActivity, participantCount: participantCount),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF1E1E1E),
                                          side: const BorderSide(color: Color(0xFFE6E2DB)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: Text(_editButtonLabel(canFullyEdit: canFullyEdit, canPartiallyEdit: canPartiallyEdit)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              // ── Invitations ─────────────────────────
                              if (canInvite) ...[
                                const SizedBox(height: 12),
                                _sectionCard(
                                  title: 'Invitations',
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          await Navigator.push(context,
                                            MaterialPageRoute(builder: (_) => InviteToActivityPage(activity: currentActivity)));
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF1E1E1E),
                                          side: const BorderSide(color: Color(0xFFE6E2DB)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        icon: const Icon(Icons.group_add),
                                        label: const Text('Inviter (amis ou groupe)'),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(context,
                                            MaterialPageRoute(builder: (_) => SentInvitationsPage(activity: currentActivity)));
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF1E1E1E),
                                          side: const BorderSide(color: Color(0xFFE6E2DB)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        icon: const Icon(Icons.outgoing_mail),
                                        label: const Text('Voir les invitations envoyées'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // ── Participants ─────────────────────────
                              const SizedBox(height: 12),
                              _sectionCard(
                                title: 'Participants',
                                children: [
                                  if (!canViewParticipants)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1EFEB),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        participantInfoText.isNotEmpty
                                            ? participantInfoText
                                            : "La liste des participants n'est pas visible.",
                                        style: const TextStyle(color: Color(0xFF6F6F6F), fontSize: 13),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      height: 250,
                                      child: StreamBuilder<List<Map<String, dynamic>>>(
                                        stream: activityService.getParticipantUsers(currentActivity.id),
                                        builder: (context, participantsSnapshot) {
                                          if (participantsSnapshot.hasError) {
                                            if (_isPermissionDenied(participantsSnapshot.error)) {
                                              return const Text("La liste des participants n'est plus accessible.");
                                            }
                                            return Text('Erreur participants : ${participantsSnapshot.error}');
                                          }
                                          if (!participantsSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                                          final participants = participantsSnapshot.data ?? [];
                                          if (participants.isEmpty) return const Text('Aucun participant trouvé');
                                          return ListView.builder(
                                            itemCount: participants.length,
                                            itemBuilder: (context, index) {
                                              final user = participants[index];
                                              final userId = (user['id'] ?? '').toString().trim();
                                              final pseudo = (user['pseudo'] ?? '').toString().trim();
                                              final prenom = (user['prenom'] ?? '').toString().trim();
                                              final lieu = (user['lieu'] ?? '').toString().trim();
                                              final participantTitle = pseudo.isNotEmpty ? pseudo : prenom.isNotEmpty ? prenom : 'Utilisateur';
                                              final participantIsOwner = userId == currentOwnerId && !ownerPending;
                                              return ListTile(
                                                leading: const Icon(Icons.person_outline, color: Color(0xFF6F6F6F)),
                                                title: Row(
                                                  children: [
                                                    Expanded(child: Text(participantTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                                                    if (participantIsOwner)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(color: const Color(0xFFB8ECE6), borderRadius: BorderRadius.circular(12)),
                                                        child: const Text('Organisateur', style: TextStyle(color: Color(0xFF00B4A6), fontSize: 11, fontWeight: FontWeight.w600)),
                                                      ),
                                                  ],
                                                ),
                                                subtitle: Text(lieu.isNotEmpty ? lieu : 'Lieu non renseigné',
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6F6F6F))),
                                                trailing: const Icon(Icons.chevron_right, color: Color(0xFF6F6F6F)),
                                                onTap: userId.isEmpty ? null : () {
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)));
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
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
  }
}
