import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/features/03_activities/activity_detail_page.dart';
import '../../models/user_model.dart';
import '../../models/friendship.dart';
import '../../repositories/friendship_repository.dart';
import '../../repositories/groups_repository.dart';
import '../../repositories/message_badge_repository.dart';
import '../../services/firestore/friendship_firestore_service.dart';
import '../../repositories/profile_repository.dart';
import '../../services/current_user.dart';
import '../06_groups/groups_page.dart';
import 'edit_profile_page.dart';
import 'friend_requests_page.dart';
import '../05_chat/private_conversations_page.dart';
import 'friends_list_page.dart';
import 'search_users_page.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({
    super.key,
    required this.userId,
  });

  static const List<String> availableCategories = [
    'Sport', 'Sortie', 'Culture', 'Jeux',
    'Études', 'Travail', 'Détente', 'Autre',
  ];

  // ─── Async actions ────────────────────────────────────────────────────────

  Future<void> _sendFriendRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    String profileUserId,
  ) async {
    final sent = await friendshipRepository.sendFriendRequest(
      toUserId: profileUserId.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sent ? "Demande d'ami envoyée" : "Impossible d'envoyer la demande")),
    );
  }

  Future<void> _acceptFriendRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
  ) async {
    final friendshipId = friendship.id.trim();
    if (friendshipId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'accepter la demande")),
      );
      return;
    }
    final accepted = await friendshipRepository.acceptFriendRequest(friendshipId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(accepted ? "Demande d'ami acceptée" : "Impossible d'accepter la demande")),
    );
  }

  Future<void> _refuseFriendRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
  ) async {
    final friendshipId = friendship.id.trim();
    if (friendshipId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de refuser la demande")),
      );
      return;
    }
    final refused = await friendshipRepository.refuseFriendRequest(friendshipId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(refused ? "Demande d'ami refusée" : "Impossible de refuser la demande")),
    );
  }

  Future<void> _removeFriend(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
    String displayName,
  ) async {
    final friendshipId = friendship.id.trim();
    if (friendshipId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer cet ami')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Supprimer cet ami"),
        content: Text("Voulez-vous vraiment supprimer $displayName de votre liste d'amis ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF9635E)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    final removed = await friendshipRepository.removeFriend(friendshipId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        removed ? "$displayName a été supprimé de vos amis." : 'Impossible de supprimer cet ami.',
      )),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _formatActivityDate(DateTime? date) {
    if (date == null) return '';
    const weekdays = ['', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    const months = ['', 'jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin',
        'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${weekdays[date.weekday]} ${date.day} ${months[date.month]} • $h:$m';
  }

  String _computeAge(String? dateNaissance) {
    if (dateNaissance == null || dateNaissance.trim().isEmpty) return '';
    try {
      final parts = dateNaissance.trim().split('/');
      if (parts.length != 3) return '';
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final birth = DateTime(year, month, day);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return '$age ans';
    } catch (_) {
      return '';
    }
  }

  // ─── Visual helpers ───────────────────────────────────────────────────────

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

  Widget _networkTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? count,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF00B4A6)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E1E1E))),
            ),
            if (count != null && count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFB8ECE6), borderRadius: BorderRadius.circular(12)),
                child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00B4A6))),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFA8A8A8)),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF1EFEB));

  Widget _buildChipWrap(List<String> values, {String emptyLabel = 'Aucun élément'}) {
    if (values.isEmpty) {
      return Text(emptyLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFF0EEFF), borderRadius: BorderRadius.circular(20)),
        child: Text(value, style: const TextStyle(color: Color(0xFF8B80F9), fontSize: 12, fontWeight: FontWeight.w600)),
      )).toList(),
    );
  }

  // ─── Section À venir ─────────────────────────────────────────────────────

  Widget _buildUpcomingSection(String profileUserId, bool isCurrentUser) {
    final activityService = ActivityFirestoreService();
    final now = DateTime.now();

    return StreamBuilder<List<Activity>>(
      stream: activityService.getCreatedActivities(),
      builder: (context, createdSnapshot) {
        return StreamBuilder<List<Activity>>(
          stream: activityService.getJoinedActivities(),
          builder: (context, joinedSnapshot) {
            final created = createdSnapshot.data ?? [];
            final joined = joinedSnapshot.data ?? [];
            final createdIds = created.map((a) => a.id).toSet();
            final joinedDeduped = joined.where((a) => !createdIds.contains(a.id)).toList();
            final all = [...created, ...joinedDeduped];

            final upcoming = all.where((a) {
              final start = a.resolvedStartDateTime;
              return start != null && start.isAfter(now) && !a.isCancelled && !a.isDone;
            }).toList();

            upcoming.sort((a, b) => a.resolvedStartDateTime!.compareTo(b.resolvedStartDateTime!));

            final display = upcoming.take(3).toList();

            if (display.isEmpty) {
              return _sectionCard(
                title: 'À venir',
                children: [
                  const Text('Aucune activité prévue.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFA8A8A8))),
                ],
              );
            }

            return _sectionCard(
              title: 'À venir',
              children: [
                ...display.asMap().entries.map((entry) {
                  final index = entry.key;
                  final activity = entry.value;
                  final isCreated = createdIds.contains(activity.id);

                  return Column(
                    children: [
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: activity)),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isCreated ? const Color(0xFFB8ECE6) : const Color(0xFFFFD6D3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.event, size: 18,
                                    color: isCreated ? const Color(0xFF00B4A6) : const Color(0xFFF9635E)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(activity.title,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E1E1E)),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(_formatActivityDate(activity.resolvedStartDateTime),
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6F6F6F))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCreated ? const Color(0xFFB8ECE6) : const Color(0xFFFFD6D3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isCreated ? 'Créée' : 'Rejointe',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: isCreated ? const Color(0xFF00B4A6) : const Color(0xFFF9635E)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 16, color: Color(0xFFA8A8A8)),
                            ],
                          ),
                        ),
                      ),
                      if (index < display.length - 1)
                        const Divider(height: 1, color: Color(0xFFF1EFEB)),
                    ],
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Section Mon réseau / amitié ──────────────────────────────────────────

  Widget _buildFriendshipSection(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    MessageBadgeRepository messageBadgeRepository,
    FriendshipFirestoreService friendshipFirestoreService,
    String profileUserId,
    String currentUserId,
    bool isCurrentUser,
  ) {
    if (isCurrentUser) {
      return StreamBuilder<List<Friendship>>(
        stream: friendshipFirestoreService.getPendingReceivedFriendRequests(),
        builder: (context, pendingSnapshot) {
          final pendingCount = pendingSnapshot.data?.length ?? 0;
          return StreamBuilder<int>(
            stream: messageBadgeRepository.watchPrivateUnreadCount(),
            builder: (context, unreadSnapshot) {
              final unreadCount = unreadSnapshot.data ?? 0;
              return _sectionCard(
                title: 'Mon réseau',
                children: [
                  _networkTile(
                    icon: Icons.person_search,
                    label: 'Rechercher des utilisateurs',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchUsersPage())),
                  ),
                  _divider(),
                  _networkTile(
                    icon: Icons.people,
                    label: 'Mes amis',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsListPage())),
                  ),
                  _divider(),
                  _networkTile(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages privés',
                    count: unreadCount > 0 ? unreadCount : null,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivateConversationsPage())),
                  ),
                  _divider(),
                  _networkTile(
                    icon: Icons.group_add,
                    label: "Demandes d'amis",
                    count: pendingCount > 0 ? pendingCount : null,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsPage())),
                  ),
                  _divider(),
                  _networkTile(
                    icon: Icons.groups,
                    label: 'Mes groupes',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsPage())),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: StreamBuilder<Friendship?>(
        stream: friendshipRepository.watchFriendshipWithUser(profileUserId.trim()),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Erreur relation d'amitié :\n${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final friendship = snapshot.data;

          if (friendship == null) {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendFriendRequest(context, friendshipRepository, profileUserId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4A6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text("Ajouter en ami"),
              ),
            );
          }

          final requestReceived = friendship.addresseeId.trim() == currentUserId;
          final displayName = requestReceived
              ? (friendship.requesterPseudo.trim().isNotEmpty ? friendship.requesterPseudo.trim() : friendship.requesterId.trim())
              : (friendship.addresseePseudo.trim().isNotEmpty ? friendship.addresseePseudo.trim() : friendship.addresseeId.trim());

          if (friendship.isAccepted) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF4), borderRadius: BorderRadius.circular(8)),
                  child: const Text("Vous êtes amis",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF34C759))),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _removeFriend(context, friendshipRepository, friendship,
                      displayName.isNotEmpty ? displayName : "cet utilisateur"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF9635E),
                    side: const BorderSide(color: Color(0xFFF9635E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.person_remove),
                  label: const Text("Supprimer cet ami"),
                ),
              ],
            );
          }

          if (friendship.isPending && requestReceived) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4E6), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    friendship.requesterPseudo.trim().isNotEmpty
                        ? "${friendship.requesterPseudo.trim()} vous a envoyé une demande d'ami"
                        : "Vous avez reçu une demande d'ami",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF4B266)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptFriendRequest(context, friendshipRepository, friendship),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4A6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text("Accepter"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _refuseFriendRequest(context, friendshipRepository, friendship),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6F6F6F),
                          side: const BorderSide(color: Color(0xFFE6E2DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text("Refuser"),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          if (friendship.isPending && !requestReceived) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA8A8A8),
                  side: const BorderSide(color: Color(0xFFE6E2DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.schedule),
                label: const Text("Demande d'ami envoyée"),
              ),
            );
          }

          if (friendship.isRefused || friendship.isCancelled) {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendFriendRequest(context, friendshipRepository, profileUserId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4A6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text("Ajouter en ami"),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final repository = ProfileRepository();
    final friendshipRepository = FriendshipRepository();
    final messageBadgeRepository = MessageBadgeRepository();
    final friendshipFirestoreService = FriendshipFirestoreService();

    final currentUserId = AuthUser.uidOrNull?.trim();
    final profileUserId = userId.trim();

    if (currentUserId == null || currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Utilisateur non connecté')),
      );
    }
    if (profileUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Profil introuvable')),
      );
    }

    final isCurrentUser = profileUserId == currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: StreamBuilder<UserModel?>(
        stream: repository.watchUser(profileUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur lors du chargement du profil : ${snapshot.error}'));
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('Utilisateur introuvable'));
          }

          final firstName = user.prenom.trim();
          final lastName = user.nom.trim();
          final pseudo = user.pseudo.trim();
          final fullName = '$firstName $lastName'.trim();
          final avatarLetter = firstName.isNotEmpty
              ? firstName[0].toUpperCase()
              : lastName.isNotEmpty
                  ? lastName[0].toUpperCase()
                  : pseudo.isNotEmpty
                      ? pseudo[0].toUpperCase()
                      : '?';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // ── Avatar ──
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8ECE6),
                    shape: BoxShape.circle,
                    image: (user.photoUrl != null && user.photoUrl!.trim().isNotEmpty)
                        ? DecorationImage(image: NetworkImage(user.photoUrl!.trim()), fit: BoxFit.cover)
                        : null,
                  ),
                  child: (user.photoUrl == null || user.photoUrl!.trim().isEmpty)
                      ? Center(
                          child: Text(avatarLetter,
                              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: Color(0xFF00B4A6))),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  fullName.isNotEmpty ? fullName : 'Nom non renseigné',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E1E1E)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pseudo.isNotEmpty)
                      Text('@$pseudo', style: const TextStyle(fontSize: 14, color: Color(0xFF6F6F6F))),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF00B4A6)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  FriendshipRepository().getAcceptedFriendships(),
                  GroupsRepository().watchMyGroups().first,
                ]),
                builder: (context, snapshot) {
                  final friendCount = snapshot.hasData ? (snapshot.data![0] as List).length : 0;
                  final groupCount = snapshot.hasData ? (snapshot.data![1] as List).length : 0;
                  return Center(
                    child: Text(
                      '$friendCount ami${friendCount > 1 ? 's' : ''} • $groupCount groupe${groupCount > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Section réseau / amitié ──
              _buildFriendshipSection(
                context,
                friendshipRepository,
                messageBadgeRepository,
                friendshipFirestoreService,
                profileUserId,
                currentUserId,
                isCurrentUser,
              ),
              const SizedBox(height: 12),

              // ── Section À venir ──
              _buildUpcomingSection(profileUserId, isCurrentUser),
              const SizedBox(height: 12),

              // ── Section À propos ──
              _sectionCard(
                title: 'À propos',
                children: [
                  if (user.lieu != null && user.lieu!.trim().isNotEmpty) ...[
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6F6F6F)),
                      const SizedBox(width: 10),
                      Text(user.lieu!.trim(), style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E1E))),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (user.genre != null && user.genre!.trim().isNotEmpty) ...[
                    Row(children: [
                      const Icon(Icons.person_outline, size: 16, color: Color(0xFF6F6F6F)),
                      const SizedBox(width: 10),
                      Text(user.genre!.trim(), style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E1E))),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (user.dateNaissance != null && user.dateNaissance!.trim().isNotEmpty) ...[
                    Row(children: [
                      const Icon(Icons.cake_outlined, size: 16, color: Color(0xFF6F6F6F)),
                      const SizedBox(width: 10),
                      Text(
                        () {
                          final age = _computeAge(user.dateNaissance);
                          return age.isNotEmpty
                              ? '$age • ${user.dateNaissance!.trim()}'
                              : user.dateNaissance!.trim();
                        }(),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E1E)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${user.bio!.trim()}"',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F), fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (user.favoriteCategories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Catégories favorites',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6F6F6F))),
                    const SizedBox(height: 8),
                    _buildChipWrap(user.favoriteCategories, emptyLabel: 'Aucune catégorie favorite'),
                  ],
                  if (user.centresInteret.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text("Centres d'intérêt",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6F6F6F))),
                    const SizedBox(height: 8),
                    _buildChipWrap(user.centresInteret, emptyLabel: "Aucun centre d'intérêt"),
                  ],
                  if (user.lieu == null &&
                      user.genre == null &&
                      user.dateNaissance == null &&
                      user.bio == null &&
                      user.centresInteret.isEmpty &&
                      user.favoriteCategories.isEmpty)
                    const Text(
                      'Aucune information renseignée.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFA8A8A8)),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
