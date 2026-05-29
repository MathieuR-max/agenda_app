import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/chat_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/search_firestore_service.dart';
import 'activity_detail_page.dart';
import 'search_detail_page.dart';

// ─── Filtre actif ─────────────────────────────────────────────────────────────

enum _Filter {
  // Filtres principaux (type)
  all, created, joined, searches,
  // Filtres avancés (statut — alternatifs aux principaux)
  full, cancelled, done, ownerPending,
}

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
  bool _showAdvancedFilters = false;
  bool _showUpcomingOnly = true;
  bool _showPastOnly = false;

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

  List<Activity> _applyActivityFilters(List<Activity> activities) {
    final now = DateTime.now();
    var result = activities;

    if (_showUpcomingOnly) {
      result = result.where((a) {
        final start = a.resolvedStartDateTime;
        return start == null || !start.isBefore(now);
      }).toList();
    } else if (_showPastOnly) {
      result = result.where((a) {
        final start = a.resolvedStartDateTime;
        return start != null && start.isBefore(now);
      }).toList();
    }

    switch (_activeFilter) {
      case _Filter.full:
        result = result.where((a) => a.isFull).toList();
        break;
      case _Filter.cancelled:
        result = result.where((a) => a.isCancelled).toList();
        break;
      case _Filter.done:
        result = result.where((a) => a.isDone).toList();
        break;
      case _Filter.ownerPending:
        result = result.where((a) => a.ownerPending).toList();
        break;
      default:
        break;
    }

    return result;
  }

  List<Map<String, dynamic>> _applySearchFilters(
    List<Map<String, dynamic>> searches,
  ) {
    if (!_showUpcomingOnly && !_showPastOnly) return searches;

    final now = DateTime.now();
    return searches.where((s) {
      final start = s['startDateTime'] as DateTime?;
      if (_showUpcomingOnly) {
        return start == null || !start.isBefore(now);
      } else {
        return start != null && start.isBefore(now);
      }
    }).toList();
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

      if (aFuture && bFuture) return aDate.compareTo(bDate);
      if (!aFuture && !bFuture) return bDate.compareTo(aDate);
      return aFuture ? -1 : 1;
    });

    return items;
  }

  // ─── Helpers visuels ─────────────────────────────────────────────────────

  Widget _chip({required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color bg,
    required Color fg,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? fg.withValues(alpha: 0.15) : bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? fg : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }

  // ─── Barre de filtres ─────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip(
                label: 'Tout',
                bg: const Color(0xFFF1EFEB),
                fg: const Color(0xFF1E1E1E),
                isActive: _activeFilter == _Filter.all,
                onTap: () => setState(() => _activeFilter = _Filter.all),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Créées',
                bg: const Color(0xFFB8ECE6),
                fg: const Color(0xFF00B4A6),
                isActive: _activeFilter == _Filter.created,
                onTap: () => setState(() => _activeFilter = _Filter.created),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Rejointes',
                bg: const Color(0xFFFFD6D3),
                fg: const Color(0xFFF9635E),
                isActive: _activeFilter == _Filter.joined,
                onTap: () => setState(() => _activeFilter = _Filter.joined),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Recherches',
                bg: const Color(0xFFFFF4E6),
                fg: const Color(0xFFF4B266),
                isActive: _activeFilter == _Filter.searches,
                onTap: () => setState(() => _activeFilter = _Filter.searches),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 2),
          child: TextButton(
            onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00B4A6),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune, size: 18),
                const SizedBox(width: 4),
                Text(
                  _showAdvancedFilters ? 'Moins de filtres' : 'Filtres avancés',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _showAdvancedFilters ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, size: 18),
                ),
              ],
            ),
          ),
        ),
        if (_showAdvancedFilters) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  label: 'À venir',
                  bg: const Color(0xFFB8ECE6),
                  fg: const Color(0xFF00B4A6),
                  isActive: _showUpcomingOnly,
                  onTap: () => setState(() {
                    _showUpcomingOnly = true;
                    _showPastOnly = false;
                  }),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Passées',
                  bg: const Color(0xFFF1EFEB),
                  fg: const Color(0xFF6F6F6F),
                  isActive: _showPastOnly,
                  onTap: () => setState(() {
                    _showUpcomingOnly = false;
                    _showPastOnly = true;
                  }),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Toutes les dates',
                  bg: const Color(0xFFF1EFEB),
                  fg: const Color(0xFF6F6F6F),
                  isActive: !_showUpcomingOnly && !_showPastOnly,
                  onTap: () => setState(() {
                    _showUpcomingOnly = false;
                    _showPastOnly = false;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  label: 'Complètes',
                  bg: const Color(0xFFFFF4E6),
                  fg: const Color(0xFFF4B266),
                  isActive: _activeFilter == _Filter.full,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == _Filter.full ? _Filter.all : _Filter.full),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Annulées',
                  bg: const Color(0xFFFFF0EF),
                  fg: const Color(0xFFF9635E),
                  isActive: _activeFilter == _Filter.cancelled,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == _Filter.cancelled ? _Filter.all : _Filter.cancelled),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Terminées',
                  bg: const Color(0xFFF1EFEB),
                  fg: const Color(0xFF6F6F6F),
                  isActive: _activeFilter == _Filter.done,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == _Filter.done ? _Filter.all : _Filter.done),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Owner requis',
                  bg: const Color(0xFFFFF0EF),
                  fg: const Color(0xFFF9635E),
                  isActive: _activeFilter == _Filter.ownerPending,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == _Filter.ownerPending ? _Filter.all : _Filter.ownerPending),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
      ],
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: activity)),
      ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Badge(
                          label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: Color(0xFF6F6F6F),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Color(0xFF6F6F6F)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dateLabel,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(
                        label: isOwner ? 'Organisateur' : 'Rejointe',
                        bg: isOwner ? const Color(0xFFB8ECE6) : const Color(0xFFFFD6D3),
                        fg: isOwner ? const Color(0xFF00B4A6) : const Color(0xFFF9635E),
                      ),
                      _chip(
                        label: activity.activityTypeLabel,
                        bg: const Color(0xFFF1EFEB),
                        fg: const Color(0xFF6F6F6F),
                      ),
                      for (final indicator in activity.calendarIndicators)
                        _chip(
                          label: indicator,
                          bg: indicator.contains('soir')
                              ? const Color(0xFFFFF4E6)
                              : const Color(0xFFF0EEFF),
                          fg: indicator.contains('soir')
                              ? const Color(0xFFF4B266)
                              : const Color(0xFF8B80F9),
                        ),
                      if (activity.ownerPending)
                        _chip(
                          label: 'Owner requis',
                          bg: const Color(0xFFFFF0EF),
                          fg: const Color(0xFFF9635E),
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
    final displayCategory = (category.isEmpty || category == 'Toutes') ? '' : category;
    final title = displayCategory.isNotEmpty ? 'Recherche · $displayCategory' : 'Recherche';
    final startDt = search['startDateTime'] as DateTime?;
    final endDt = search['endDateTime'] as DateTime?;
    final dateLabel = _formatActivityDateTime(startDt, endDt);

    return GestureDetector(
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: Color(0xFF6F6F6F)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateLabel,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _chip(
                      label: displayCategory.isNotEmpty ? displayCategory : 'Toutes catégories',
                      bg: const Color(0xFFFFF4E6),
                      fg: const Color(0xFFF4B266),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: const Color(0xFFA8A8A8),
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
        content: const Text('Cette recherche sera retirée de votre agenda.'),
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
    final isUpcoming = _showUpcomingOnly;

    final String message;
    switch (_activeFilter) {
      case _Filter.all:
        message = isUpcoming
            ? 'Aucune activité ni recherche à venir'
            : 'Aucune activité ni recherche pour le moment';
        break;
      case _Filter.created:
        message = isUpcoming
            ? 'Aucune activité créée à venir'
            : "Vous n'avez créé aucune activité";
        break;
      case _Filter.joined:
        message = isUpcoming
            ? 'Aucune activité rejointe à venir'
            : "Vous n'avez rejoint aucune activité";
        break;
      case _Filter.searches:
        message = isUpcoming
            ? 'Aucune recherche à venir'
            : 'Aucune recherche sauvegardée';
        break;
      case _Filter.full:
        message = 'Aucune activité complète';
        break;
      case _Filter.cancelled:
        message = 'Aucune activité annulée';
        break;
      case _Filter.done:
        message = 'Aucune activité terminée';
        break;
      case _Filter.ownerPending:
        message = "Aucune activité ne requiert d'organisateur";
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 64, color: Color(0xFFA8A8A8)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
    final filteredCreated = _applyActivityFilters(created);
    final filteredJoined = _applyActivityFilters(joinedDeduplicated);
    final filteredSearches = _applySearchFilters(searches);
    final createdIds = created.map((a) => a.id).toSet();

    switch (_activeFilter) {
      case _Filter.created:
        if (filteredCreated.isEmpty) return _buildEmptyState();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: filteredCreated.length,
          itemBuilder: (_, i) => _buildActivityCard(filteredCreated[i], true),
        );

      case _Filter.joined:
        if (filteredJoined.isEmpty) return _buildEmptyState();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: filteredJoined.length,
          itemBuilder: (_, i) => _buildActivityCard(filteredJoined[i], false),
        );

      case _Filter.searches:
        if (filteredSearches.isEmpty) return _buildEmptyState();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: filteredSearches.length,
          itemBuilder: (_, i) => _buildSearchCard(filteredSearches[i]),
        );

      case _Filter.full:
      case _Filter.cancelled:
      case _Filter.done:
      case _Filter.ownerPending:
        final merged = [...filteredCreated, ...filteredJoined];
        if (merged.isEmpty) return _buildEmptyState();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: merged.length,
          itemBuilder: (_, i) {
            final a = merged[i];
            return _buildActivityCard(a, createdIds.contains(a.id));
          },
        );

      case _Filter.all:
        final items = _buildAllItemsSorted(
          filteredCreated,
          filteredJoined,
          filteredSearches,
        );
        if (items.isEmpty) return _buildEmptyState();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
        Expanded(
          child: StreamBuilder<List<Activity>>(
            stream: _activityService.getCreatedActivities(),
            builder: (context, createdSnapshot) {
              if (createdSnapshot.hasError) {
                return Center(child: Text('Erreur : ${createdSnapshot.error}'));
              }
              if (!createdSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<Activity>>(
                stream: _activityService.getJoinedActivities(),
                builder: (context, joinedSnapshot) {
                  if (joinedSnapshot.hasError) {
                    return Center(child: Text('Erreur : ${joinedSnapshot.error}'));
                  }
                  if (!joinedSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _searchService.getSearches(),
                    builder: (context, searchSnapshot) {
                      if (searchSnapshot.hasError) {
                        return Center(child: Text('Erreur : ${searchSnapshot.error}'));
                      }
                      if (!searchSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
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
