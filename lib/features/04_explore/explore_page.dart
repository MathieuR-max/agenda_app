import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:agenda_app/core/utils/temporal_activity_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/repositories/notification_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import '../03_activities/activity_detail_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _activityService = ActivityFirestoreService();
  final _activityRepository = ActivityRepository();
  final FriendshipRepository _friendshipRepository = FriendshipRepository();
  final NotificationRepository _notificationRepository = NotificationRepository();

  List<String> _friendIds = [];

  String _selectedCategory = 'Toutes';
  int? _selectedWeekday; // null = tous les jours
  bool _filtersExpanded = false;

  Position? _userPosition;
  bool _sortByDistance = false;
  bool _isLoadingPosition = false;
  int? _radiusKm;

  List<Activity> _matchedActivities = [];

  late final StreamSubscription<List<String>> _joinedIdsSub;
  final Set<String> _joinedIds = {};

  @override
  void initState() {
    super.initState();
    _joinedIdsSub = _activityService.watchJoinedActivityIds().listen((ids) {
      if (mounted) {
        setState(() {
          _joinedIds
            ..clear()
            ..addAll(ids);
        });
      }
    });
    _loadFriendIds();
    _loadMatchedActivities();
  }

  Future<void> _loadFriendIds() async {
    try {
      final friendships = await _friendshipRepository.getAcceptedFriendships();
      if (!mounted) return;
      setState(() {
        _friendIds = friendships
            .map((f) => _friendshipRepository.getOtherUserId(f))
            .toList();
      });
    } catch (e) {
      debugPrint('ExplorePage: erreur chargement amis: $e');
    }
  }

  Future<void> _loadMatchedActivities() async {
    try {
      final notifications = await _notificationRepository.getActivityMatchNotifications();
      final now = DateTime.now();
      final uid = AuthUser.uidOrNull;
      final seen = <String>{};
      final results = <Activity>[];

      for (final notif in notifications) {
        final activityId = (notif['activityId'] ?? '').toString();
        if (activityId.isEmpty || seen.contains(activityId)) continue;
        seen.add(activityId);

        final activity = await _activityService.getActivityById(activityId);
        if (activity == null) continue;
        if (activity.isCancelled || activity.isDone) continue;
        final start = activity.resolvedStartDateTime;
        if (start == null || start.isBefore(now)) continue;
        if (uid != null &&
            (activity.ownerId == uid || activity.createdById == uid)) {
          continue;
        }

        results.add(activity);
        if (results.length >= 5) break;
      }

      if (mounted) setState(() => _matchedActivities = results);
    } catch (e) {
      debugPrint('EXPLORE_MATCH error: $e');
    }
  }

  @override
  void dispose() {
    _joinedIdsSub.cancel();
    super.dispose();
  }

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
    if (_radiusKm != null) count++;
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

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * asin(sqrt(a));
  }

  Future<void> _requestLocationAndSort() async {
    if (_isLoadingPosition) return;
    setState(() => _isLoadingPosition = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Service de localisation désactivé')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission de localisation refusée')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Localisation bloquée — modifiez les paramètres de l'app"),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        setState(() {
          _userPosition = position;
          _sortByDistance = true;
        });
      }
    } catch (e) {
      debugPrint('EXPLORER geoloc error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'obtenir la position")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPosition = false);
    }
  }

  bool _matchesRadiusFilter(Activity activity) {
    if (_radiusKm == null) return true;
    if (_userPosition == null) return true;
    if (!activity.hasCoordinates) return true;
    final dist = _distanceKm(
      _userPosition!.latitude,
      _userPosition!.longitude,
      activity.latitude!,
      activity.longitude!,
    );
    return dist <= _radiusKm!;
  }

  Future<void> _selectRadius(int radiusKm) async {
    if (_radiusKm == radiusKm) {
      setState(() => _radiusKm = null);
      return;
    }
    setState(() => _radiusKm = radiusKm);
    if (_userPosition == null) {
      await _requestLocationAndSort();
    } else {
      setState(() => _sortByDistance = true);
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'Toutes';
      _selectedWeekday = null;
      _radiusKm = null;
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
            labelColor: const Color(0xFF00B4A6),
            unselectedLabelColor: const Color(0xFF6F6F6F),
            indicatorColor: const Color(0xFF00B4A6),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(builder: (context) {
          final visibleMatches = _matchedActivities
              .where((a) => !_joinedIds.contains(a.id))
              .toList();
          if (visibleMatches.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '✨ Correspond à vos recherches',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00B4A6),
                  ),
                ),
              ),
              SizedBox(
                height: 118,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: visibleMatches.length,
                  itemBuilder: (context, index) =>
                      _buildMatchedActivityCard(visibleMatches[index]),
                ),
              ),
            ],
          );
        }),
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
                  .where(_matchesRadiusFilter)
                  .toList();

              if (_sortByDistance && _userPosition != null) {
                filtered.sort((a, b) {
                  final aHas = a.hasCoordinates;
                  final bHas = b.hasCoordinates;
                  if (!aHas && !bHas) return 0;
                  if (!aHas) return 1;
                  if (!bHas) return -1;
                  final aDist = _distanceKm(
                    _userPosition!.latitude, _userPosition!.longitude,
                    a.latitude!, a.longitude!,
                  );
                  final bDist = _distanceKm(
                    _userPosition!.latitude, _userPosition!.longitude,
                    b.latitude!, b.longitude!,
                  );
                  return aDist.compareTo(bDist);
                });
              }

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                icon: const Icon(Icons.tune),
                label: const Text('Filtres'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _isLoadingPosition
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilterChip(
                              label: const Text('Près de moi'),
                              selected: _sortByDistance,
                              avatar: const Icon(Icons.near_me, size: 16),
                              onSelected: (_) {
                                if (_sortByDistance) {
                                  setState(() {
                                    _sortByDistance = false;
                                    _userPosition = null;
                                  });
                                } else {
                                  _requestLocationAndSort();
                                }
                              },
                              backgroundColor: const Color(0xFFF1EFEB),
                              selectedColor: const Color(0xFFB8ECE6),
                              labelStyle: TextStyle(
                                color: _sortByDistance
                                    ? const Color(0xFF00B4A6)
                                    : const Color(0xFF6F6F6F),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              side: BorderSide.none,
                              showCheckmark: false,
                            ),
                      ...([2, 5, 10, 25].map((km) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: FilterChip(
                              label: Text('$km km'),
                              selected: _radiusKm == km,
                              onSelected: (_) => _selectRadius(km),
                              backgroundColor: const Color(0xFFF1EFEB),
                              selectedColor: const Color(0xFFB8ECE6),
                              labelStyle: TextStyle(
                                color: _radiusKm == km
                                    ? const Color(0xFF00B4A6)
                                    : const Color(0xFF6F6F6F),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              side: BorderSide.none,
                              showCheckmark: false,
                            ),
                          ))),
                    ],
                  ),
                ),
              ),
              if (_activeFilterCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B4A6),
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
                  style: TextStyle(fontSize: 12, color: Color(0xFF6F6F6F)),
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
                      backgroundColor: const Color(0xFFF1EFEB),
                      selectedColor: const Color(0xFFB8ECE6),
                      labelStyle: TextStyle(
                        color: _selectedWeekday == null
                            ? const Color(0xFF00B4A6)
                            : const Color(0xFF6F6F6F),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide.none,
                      showCheckmark: false,
                    ),
                    ..._dayChips.map((d) => FilterChip(
                          label: Text(d.label),
                          selected: _selectedWeekday == d.weekday,
                          onSelected: (_) => setState(
                              () => _selectedWeekday = d.weekday),
                          backgroundColor: const Color(0xFFF1EFEB),
                          selectedColor: const Color(0xFFB8ECE6),
                          labelStyle: TextStyle(
                            color: _selectedWeekday == d.weekday
                                ? const Color(0xFF00B4A6)
                                : const Color(0xFF6F6F6F),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide.none,
                          showCheckmark: false,
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
        const Divider(height: 1, color: Color(0xFFEDE9E3)),
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
              color: const Color(0xFFA8A8A8),
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

  // ─── Carte activité matchée ───────────────────────────────────────────────

  Widget _buildMatchedActivityCard(Activity activity) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailPage(activity: activity),
        ),
      ),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFB8ECE6), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                if (activity.category.isNotEmpty && activity.category != 'Toutes') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      activity.category,
                      style: const TextStyle(
                        color: Color(0xFF8B80F9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Horaire
            Row(
              children: [
                const Icon(Icons.schedule, size: 12, color: Color(0xFF6F6F6F)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    activity.scheduleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6F6F6F)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Lieu
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 12, color: Color(0xFF6F6F6F)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    activity.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6F6F6F)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activity.hasUnlimitedPlaces
                        ? '${_pluralParticipants(activity.participantCount)} • Illimité'
                        : '${activity.participantCount} / ${activity.maxParticipants} places',
                    style: const TextStyle(
                      color: Color(0xFF34C759),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: activity.isFull
                        ? const Color(0xFFFFF0EF)
                        : const Color(0xFFECFDF4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activity.isFull ? 'Complète' : 'Ouverte',
                    style: TextStyle(
                      color: activity.isFull
                          ? const Color(0xFFF9635E)
                          : const Color(0xFF34C759),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailPage(activity: activity),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
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
              ],
            ),
            const SizedBox(height: 6),

            // Organisateur
            Text(
              activity.organizerDisplayLabel,
              style: const TextStyle(color: Color(0xFF6F6F6F), fontSize: 13),
            ),
            const SizedBox(height: 4),

            // Horaire
            if (activity.scheduleLabel.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Color(0xFF6F6F6F)),
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
                  const Icon(Icons.place_outlined, size: 14, color: Color(0xFF6F6F6F)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _userPosition != null && activity.hasCoordinates
                          ? '${activity.location} • à ${_distanceKm(
                              _userPosition!.latitude,
                              _userPosition!.longitude,
                              activity.latitude!,
                              activity.longitude!,
                            ).toStringAsFixed(1)} km'
                          : activity.location,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Chips : catégorie + participants + statut
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (activity.category.isNotEmpty && activity.category != 'Toutes')
                  _buildChip(
                    label: activity.category,
                    backgroundColor: const Color(0xFFF0EEFF),
                    textColor: const Color(0xFF8B80F9),
                  ),
                if (TemporalActivityUtils.isTonightActivity(activity.resolvedStartDateTime))
                  _buildChip(
                    label: 'Ce soir',
                    backgroundColor: const Color(0xFFFFF4E6),
                    textColor: const Color(0xFFF4B266),
                  ),
                if (TemporalActivityUtils.isWeekendActivity(activity.resolvedStartDateTime))
                  _buildChip(
                    label: 'Ce week-end',
                    backgroundColor: const Color(0xFFF0EEFF),
                    textColor: const Color(0xFF8B80F9),
                  ),
                if (_friendIds.isNotEmpty && _friendIds.contains(activity.ownerId))
                  _buildChip(
                    label: '👥 Organisé par un ami',
                    backgroundColor: const Color(0xFFB8ECE6),
                    textColor: const Color(0xFF00B4A6),
                  ),
                _buildChip(
                  label: activity.hasUnlimitedPlaces
                      ? '${_pluralParticipants(activity.participantCount)} • Illimité'
                      : '${_pluralParticipants(activity.participantCount)} • ${activity.maxParticipants} places',
                  backgroundColor: activity.isFull
                      ? const Color(0xFFFFF0EF)
                      : const Color(0xFFECFDF4),
                  textColor: activity.isFull
                      ? const Color(0xFFF9635E)
                      : const Color(0xFF34C759),
                ),
                _buildChip(
                  label: activity.isFull ? 'Complète' : 'Ouverte',
                  backgroundColor: activity.isFull
                      ? const Color(0xFFFFF0EF)
                      : const Color(0xFFECFDF4),
                  textColor: activity.isFull
                      ? const Color(0xFFF9635E)
                      : const Color(0xFF34C759),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bouton rejoindre
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canJoin ? () => _join(activity) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canJoin
                      ? const Color(0xFF00B4A6)
                      : const Color(0xFFF1EFEB),
                  foregroundColor: canJoin
                      ? Colors.white
                      : const Color(0xFFA8A8A8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _pluralParticipants(int count) {
    return count <= 1 ? '$count participant' : '$count participants';
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
