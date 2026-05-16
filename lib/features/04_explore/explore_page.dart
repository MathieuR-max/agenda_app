import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _activityService = ActivityFirestoreService();
  final _activityRepository = ActivityRepository();

  String _selectedCategory = 'Toutes';
  int? _selectedWeekday; // null = tous les jours
  bool _filtersExpanded = false;

  // IDs rejoints dans cette session — évite un rechargement complet
  final Set<String> _joinedIds = {};

  static const List<String> _categories = [
    'Toutes',
    'Sport',
    'Sortie',
    'Culture',
    'Jeux',
    'Études',
    'Travail',
    'Détente',
    'Autre',
  ];

  static const List<({String label, int weekday})> _dayChips = [
    (label: 'Lun', weekday: DateTime.monday),
    (label: 'Mar', weekday: DateTime.tuesday),
    (label: 'Mer', weekday: DateTime.wednesday),
    (label: 'Jeu', weekday: DateTime.thursday),
    (label: 'Ven', weekday: DateTime.friday),
    (label: 'Sam', weekday: DateTime.saturday),
    (label: 'Dim', weekday: DateTime.sunday),
  ];

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'Toutes') count++;
    if (_selectedWeekday != null) count++;
    return count;
  }

  bool _matchesFilters(Activity activity) {
    final uid = AuthUser.uidOrNull;
    if (uid != null && activity.ownerId == uid) return false;
    if (_joinedIds.contains(activity.id)) return false;

    if (_selectedCategory != 'Toutes' &&
        activity.category != _selectedCategory) {
      return false;
    }
    if (_selectedWeekday != null) {
      final start = activity.resolvedStartDateTime;
      if (start == null || start.weekday != _selectedWeekday) return false;
    }
    return true;
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'Toutes';
      _selectedWeekday = null;
    });
  }

  Future<void> _join(Activity activity) async {
    final joined = await _activityRepository.joinActivity(activity);
    if (!mounted) return;
    if (joined) {
      setState(() => _joinedIds.add(activity.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vous avez rejoint l'activité")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de rejoindre l'activité")),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Découverte'),
              Tab(text: 'Sponsors'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDiscoveryTab(),
                _buildSponsorsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Onglet Sponsors ──────────────────────────────────────────────────────

  Widget _buildSponsorsTab() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Bientôt disponible',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ─── Onglet Découverte ────────────────────────────────────────────────────

  Widget _buildDiscoveryTab() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: StreamBuilder<List<Activity>>(
            stream: _activityService.getPublicDiscoverActivities(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Erreur de chargement'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final filtered = snapshot.data!
                  .where(_matchesFilters)
                  .toList();

              if (filtered.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    _buildActivityCard(filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Barre de filtres collapsibles ────────────────────────────────────────

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                icon: const Icon(Icons.tune),
                label: const Text('Filtres'),
              ),
              if (_activeFilterCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_activeFilterCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filtre catégorie
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isDense: true,
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Filtre jour de la semaine
                const Text(
                  'Jour',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Tous'),
                      selected: _selectedWeekday == null,
                      onSelected: (_) =>
                          setState(() => _selectedWeekday = null),
                    ),
                    ..._dayChips.map((d) => FilterChip(
                          label: Text(d.label),
                          selected: _selectedWeekday == d.weekday,
                          onSelected: (_) => setState(
                              () => _selectedWeekday = d.weekday),
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Réinitialiser'),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _filtersExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        const Divider(height: 1),
      ],
    );
  }

  // ─── État vide ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final hasFilters = _activeFilterCount > 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.filter_list_off : Icons.explore_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'Aucune activité ne correspond à vos filtres'
                  : 'Aucune activité publique pour le moment',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh),
                label: const Text('Réinitialiser les filtres'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Carte activité ───────────────────────────────────────────────────────

  Widget _buildActivityCard(Activity activity) {
    final alreadyJoined = _joinedIds.contains(activity.id);
    final canJoin = activity.canBeJoined && !alreadyJoined;

    String buttonLabel;
    if (alreadyJoined) {
      buttonLabel = 'Rejoint';
    } else if (activity.isCancelled) {
      buttonLabel = 'Annulée';
    } else if (activity.isDone || activity.hasEnded) {
      buttonLabel = 'Terminée';
    } else if (activity.isFull) {
      buttonLabel = 'Complète';
    } else if (activity.isInviteOnly) {
      buttonLabel = 'Sur invitation';
    } else {
      buttonLabel = 'Rejoindre';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre + chip catégorie
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildChip(
                  label: activity.category,
                  backgroundColor: Colors.indigo.shade50,
                  textColor: Colors.indigo.shade700,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Organisateur
            Text(
              activity.organizerDisplayLabel,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 4),

            // Horaire
            if (activity.scheduleLabel.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      activity.scheduleLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Lieu
            if (activity.location.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      activity.location,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Chips : participants + statut
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChip(
                  label: activity.hasUnlimitedPlaces
                      ? '${activity.participantCount} participant(s) • Illimité'
                      : '${activity.participantCount} / ${activity.maxParticipants}',
                  backgroundColor: activity.isFull
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  textColor: activity.isFull
                      ? Colors.red.shade700
                      : Colors.blue.shade700,
                ),
                _buildChip(
                  label: activity.isFull ? 'Complète' : 'Ouverte',
                  backgroundColor: activity.isFull
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                  textColor: activity.isFull
                      ? Colors.orange.shade800
                      : Colors.green.shade800,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bouton rejoindre
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canJoin ? () => _join(activity) : null,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
