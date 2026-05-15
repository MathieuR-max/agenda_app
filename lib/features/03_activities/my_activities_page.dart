import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/chat_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/search_firestore_service.dart';
import 'activity_detail_page.dart';
import 'search_detail_page.dart';

// ─── Filtre actif ─────────────────────────────────────────────────────────────

enum _Filter { all, created, joined, searches }

// ─── Élément unifié pour le filtre "Tout" ────────────────────────────────────

class _ListItem {
  final Activity? activity;
  final bool isCreated;
  final Map<String, dynamic>? search;
  final DateTime? sortDate;

  _ListItem.forActivity(this.activity, this.isCreated, this.sortDate)
      : search = null;

  _ListItem.forSearch(this.search, this.sortDate)
      : activity = null,
        isCreated = false;

  bool get isActivity => activity != null;
}

// ─── Page ────────────────────────────────────────────────────────────────────

class MyActivitiesPage extends StatefulWidget {
  const MyActivitiesPage({super.key});

  @override
  State<MyActivitiesPage> createState() => _MyActivitiesPageState();
}

class _MyActivitiesPageState extends State<MyActivitiesPage> {
  late final ActivityFirestoreService _activityService;
  late final SearchFirestoreService _searchService;
  late final ChatRepository _chatRepository;

  _Filter _activeFilter = _Filter.all;

  static const List<String> _weekdays = [
    'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'
  ];

  static const List<String> _months = [
    '', 'janv.', 'févr.', 'mars', 'avr.', 'mai',
    'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ];

  @override
  void initState() {
    super.initState();
    _activityService = ActivityFirestoreService();
    _searchService = SearchFirestoreService();
    _chatRepository = ChatRepository();
  }

  // ─── Formatage de date ────────────────────────────────────────────────────

  String _formatActivityDateTime(DateTime? start, DateTime? end) {
    if (start == null) return 'Date à définir';

    final dayLabel = _weekdays[start.weekday - 1];
    final monthLabel = _months[start.month];
    final sh = start.hour.toString().padLeft(2, '0');
    final sm = start.minute.toString().padLeft(2, '0');

    var result = '$dayLabel ${start.day} $monthLabel · $sh:$sm';

    if (end != null && DateUtils.isSameDay(start, end)) {
      final eh = end.hour.toString().padLeft(2, '0');
      final em = end.minute.toString().padLeft(2, '0');
      result += ' → $eh:$em';
    }

    return result;
  }

  // ─── Logique liste ────────────────────────────────────────────────────────

  List<Activity> _deduplicateJoined(
    List<Activity> created,
    List<Activity> joined,
  ) {
    final createdIds = created.map((a) => a.id).toSet();
    return joined.where((a) => !createdIds.contains(a.id)).toList();
  }

  List<_ListItem> _buildAllItemsSorted(
    List<Activity> created,
    List<Activity> joinedDeduplicated,
    List<Map<String, dynamic>> searches,
  ) {
    final now = DateTime.now();

    final items = <_ListItem>[
      for (final a in created)
        _ListItem.forActivity(a, true, a.resolvedStartDateTime),
      for (final a in joinedDeduplicated)
        _ListItem.forActivity(a, false, a.resolvedStartDateTime),
      for (final s in searches)
        _ListItem.forSearch(
          s,
          s['startDateTime'] as DateTime? ?? s['createdAt'] as DateTime?,
        ),
    ];

    items.sort((a, b) {
      final aDate = a.sortDate;
      final bDate = b.sortDate;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      final aFuture = !aDate.isBefore(now);
      final bFuture = !bDate.isBefore(now);

      // Futures d'abord (ASC), passées ensuite (DESC)
      if (aFuture && bFuture) return aDate.compareTo(bDate);
      if (!aFuture && !bFuture) return bDate.compareTo(aDate);
      return aFuture ? -1 : 1;
    });

    return items;
  }

  // ─── Chips de filtre ──────────────────────────────────────────────────────

  Widget _buildFilterChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? textColor.withValues(alpha: 0.16) : backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? textColor : backgroundColor,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildFilterChip(
            label: 'Tout',
            backgroundColor: Colors.grey.shade200,
            textColor: Colors.grey.shade900,
            isActive: _activeFilter == _Filter.all,
            onTap: () => setState(() => _activeFilter = _Filter.all),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Créées',
            backgroundColor: Colors.blue.shade100,
            textColor: Colors.blue.shade900,
            isActive: _activeFilter == _Filter.created,
            onTap: () => setState(() => _activeFilter = _Filter.created),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Rejointes',
            backgroundColor: Colors.purple.shade100,
            textColor: Colors.purple.shade900,
            isActive: _activeFilter == _Filter.joined,
            onTap: () => setState(() => _activeFilter = _Filter.joined),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Recherches',
            backgroundColor: Colors.orange.shade100,
            textColor: Colors.orange.shade900,
            isActive: _activeFilter == _Filter.searches,
            onTap: () => setState(() => _activeFilter = _Filter.searches),
          ),
        ],
      ),
    );
  }

  // ─── Mini badge texte ─────────────────────────────────────────────────────

  Widget _buildBadge(
    String label, {
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ─── Carte activité ───────────────────────────────────────────────────────

  Widget _buildActivityCard(Activity activity, bool isCreated) {
    final currentUid = AuthUser.uidOrNull;
    final isOwner = currentUid != null && activity.ownerId == currentUid;
    final dateLabel = _formatActivityDateTime(
      activity.resolvedStartDateTime,
      activity.resolvedEndDateTime,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityDetailPage(activity: activity),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: StreamBuilder<int>(
            stream: _chatRepository.watchUnreadCountForActivity(activity.id),
            builder: (context, unreadSnapshot) {
              final unreadCount = unreadSnapshot.data ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Badge(
                          label: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildBadge(
                        isOwner ? 'Organisateur' : 'Rejointe',
                        backgroundColor: isOwner
                            ? Colors.blue.shade700
                            : Colors.purple.shade700,
                        textColor: Colors.white,
                      ),
                      _buildBadge(
                        activity.activityTypeLabel,
                        backgroundColor: Colors.grey.shade200,
                        textColor: Colors.grey.shade800,
                      ),
                      for (final indicator in activity.calendarIndicators)
                        _buildBadge(
                          indicator,
                          backgroundColor: Colors.grey.shade100,
                          textColor: Colors.black87,
                        ),
                      if (activity.ownerPending)
                        _buildBadge(
                          'Owner requis',
                          backgroundColor: Colors.deepOrange.shade100,
                          textColor: Colors.deepOrange.shade900,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Carte recherche ──────────────────────────────────────────────────────

  Widget _buildSearchCard(Map<String, dynamic> search) {
    final category = (search['category'] as String? ?? '').trim();
    final title =
        category.isNotEmpty ? 'Recherche · $category' : 'Recherche';
    final startDt = search['startDateTime'] as DateTime?;
    final endDt = search['endDateTime'] as DateTime?;
    final dateLabel = _formatActivityDateTime(startDt, endDt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchDetailPage(
              searchId: (search['id'] as String? ?? ''),
              day: (search['day'] as String? ?? ''),
              startTime: (search['startTime'] as String? ?? ''),
              endTime: (search['endTime'] as String? ?? ''),
              category: category,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBadge(
                      'Recherche',
                      backgroundColor: Colors.orange.shade700,
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.grey.shade600,
                tooltip: 'Supprimer cette recherche',
                onPressed: () => _confirmDeleteSearch(search),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSearch(Map<String, dynamic> search) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la recherche ?'),
        content:
            const Text('Cette recherche sera retirée de votre agenda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final id = (search['id'] as String? ?? '').trim();
    if (id.isEmpty) return;
    await _searchService.deleteSearch(id);
  }

  // ─── État vide ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final String message;
    switch (_activeFilter) {
      case _Filter.all:
        message = 'Aucune activité ni recherche pour le moment';
        break;
      case _Filter.created:
        message = "Vous n'avez créé aucune activité";
        break;
      case _Filter.joined:
        message = "Vous n'avez rejoint aucune activité";
        break;
      case _Filter.searches:
        message = 'Aucune recherche sauvegardée';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Contenu filtré ───────────────────────────────────────────────────────

  Widget _buildContent(
    List<Activity> created,
    List<Activity> joinedDeduplicated,
    List<Map<String, dynamic>> searches,
  ) {
    switch (_activeFilter) {
      case _Filter.created:
        if (created.isEmpty) return _buildEmptyState();
        return ListView.builder(
          itemCount: created.length,
          itemBuilder: (_, i) => _buildActivityCard(created[i], true),
        );

      case _Filter.joined:
        if (joinedDeduplicated.isEmpty) return _buildEmptyState();
        return ListView.builder(
          itemCount: joinedDeduplicated.length,
          itemBuilder: (_, i) =>
              _buildActivityCard(joinedDeduplicated[i], false),
        );

      case _Filter.searches:
        if (searches.isEmpty) return _buildEmptyState();
        return ListView.builder(
          itemCount: searches.length,
          itemBuilder: (_, i) => _buildSearchCard(searches[i]),
        );

      case _Filter.all:
        final items =
            _buildAllItemsSorted(created, joinedDeduplicated, searches);
        if (items.isEmpty) return _buildEmptyState();
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return item.isActivity
                ? _buildActivityCard(item.activity!, item.isCreated)
                : _buildSearchCard(item.search!);
          },
        );
    }
  }

  // ─── Build principal ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        _buildFilterBar(),
        const SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<List<Activity>>(
            stream: _activityService.getCreatedActivities(),
            builder: (context, createdSnapshot) {
              if (createdSnapshot.hasError) {
                return Center(
                  child: Text('Erreur : ${createdSnapshot.error}'),
                );
              }
              if (!createdSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<Activity>>(
                stream: _activityService.getJoinedActivities(),
                builder: (context, joinedSnapshot) {
                  if (joinedSnapshot.hasError) {
                    return Center(
                      child: Text('Erreur : ${joinedSnapshot.error}'),
                    );
                  }
                  if (!joinedSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _searchService.getSearches(),
                    builder: (context, searchSnapshot) {
                      if (searchSnapshot.hasError) {
                        return Center(
                          child: Text('Erreur : ${searchSnapshot.error}'),
                        );
                      }
                      if (!searchSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final created = createdSnapshot.data!;
                      final joined = joinedSnapshot.data!;
                      final searches = searchSnapshot.data!;
                      final deduped = _deduplicateJoined(created, joined);

                      return _buildContent(created, deduped, searches);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
