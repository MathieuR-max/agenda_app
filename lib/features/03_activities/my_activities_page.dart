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

  // Applique le filtre temporel puis le filtre de statut avancé.
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

  // Pour les recherches : filtre temporel uniquement (pas de statut).
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

      // Futures d'abord (ASC), passées ensuite (DESC)
      if (aFuture && bFuture) return aDate.compareTo(bDate);
      if (!aFuture && !bFuture) return bDate.compareTo(aDate);
      return aFuture ? -1 : 1;
    });

    return items;
  }

  // ─── Chip de filtre ───────────────────────────────────────────────────────

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

  // ─── Barre de filtres ─────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne 1 : chips principaux (type)
        SizedBox(
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
        ),

        // Ligne 2 : bouton "Afficher / Masquer les filtres"
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 2),
          child: TextButton(
            onPressed: () =>
                setState(() => _showAdvancedFilters = !_showAdvancedFilters),
            style: TextButton.styleFrom(
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
                  _showAdvancedFilters
                      ? 'Moins de filtres'
                      : 'Filtres avancés',
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

          // Ligne 3 : chips temporels
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFilterChip(
                  label: 'À venir',
                  backgroundColor: Colors.teal.shade100,
                  textColor: Colors.teal.shade900,
                  isActive: _showUpcomingOnly,
                  onTap: () => setState(() {
                    _showUpcomingOnly = true;
                    _showPastOnly = false;
                  }),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Passées',
                  backgroundColor: Colors.teal.shade100,
                  textColor: Colors.teal.shade900,
                  isActive: _showPastOnly,
                  onTap: () => setState(() {
                    _showUpcomingOnly = false;
                    _showPastOnly = true;
                  }),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Toutes les dates',
                  backgroundColor: Colors.teal.shade100,
                  textColor: Colors.teal.shade900,
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

          // Ligne 4 : chips statut (alternatifs aux chips principaux)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFilterChip(
                  label: 'Complètes',
                  backgroundColor: Colors.amber.shade100,
                  textColor: Colors.amber.shade900,
                  isActive: _activeFilter == _Filter.full,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == _Filter.full ? _Filter.all : _Filter.full),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Annulées',
                  backgroundColor: Colors.red.shade100,
                  textColor: Colors.red.shade900,
                  isActive: _activeFilter == _Filter.cancelled,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == _Filter.cancelled
                          ? _Filter.all
                          : _Filter.cancelled),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Terminées',
                  backgroundColor: Colors.blueGrey.shade100,
                  textColor: Colors.blueGrey.shade900,
                  isActive: _activeFilter == _Filter.done,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == _Filter.done ? _Filter.all : _Filter.done),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Owner requis',
                  backgroundColor: Colors.deepOrange.shade100,
                  textColor: Colors.deepOrange.shade900,
                  isActive: _activeFilter == _Filter.ownerPending,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == _Filter.ownerPending
                          ? _Filter.all
                          : _Filter.ownerPending),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 4),
      ],
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
    final filteredCreated = _applyActivityFilters(created);
    final filteredJoined = _applyActivityFilters(joinedDeduplicated);
    final filteredSearches = _applySearchFilters(searches);
    final createdIds = created.map((a) => a.id).toSet();

    switch (_activeFilter) {
      case _Filter.created:
        if (filteredCreated.isEmpty) return _buildEmptyState();
        return ListView.builder(
          itemCount: filteredCreated.length,
          itemBuilder: (_, i) => _buildActivityCard(filteredCreated[i], true),
        );

      case _Filter.joined:
        if (filteredJoined.isEmpty) return _buildEmptyState();
        return ListView.builder(
          itemCount: filteredJoined.length,
          itemBuilder: (_, i) =>
              _buildActivityCard(filteredJoined[i], false),
        );

      case _Filter.searches:
        if (filteredSearches.isEmpty) return _buildEmptyState();
        return ListView.builder(
          itemCount: filteredSearches.length,
          itemBuilder: (_, i) => _buildSearchCard(filteredSearches[i]),
        );

      // Filtres de statut : activités créées + rejointes fusionnées
      case _Filter.full:
      case _Filter.cancelled:
      case _Filter.done:
      case _Filter.ownerPending:
        final merged = [...filteredCreated, ...filteredJoined];
        if (merged.isEmpty) return _buildEmptyState();
        return ListView.builder(
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
