import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/search_firestore_service.dart';
import 'activity_detail_page.dart';

class SearchActivityPage extends StatefulWidget {
  final String day;
  final String hour;

  const SearchActivityPage({
    super.key,
    required this.day,
    required this.hour,
  });

  @override
  State<SearchActivityPage> createState() => _SearchActivityPageState();
}

class _SearchActivityPageState extends State<SearchActivityPage> {
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final ActivityRepository activityRepository = ActivityRepository();
  final SearchFirestoreService searchService = SearchFirestoreService();

  String category = 'Toutes';

  final List<String> categories = const [
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

  late String startTime;
  late String endTime;
  bool _searchSaved = false;

  List<String> generateTimeSlots() {
    final List<String> slots = [];

    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final String hourStr = hour.toString().padLeft(2, '0');
        final String minuteStr = minute.toString().padLeft(2, '0');
        slots.add('$hourStr:$minuteStr');
      }
    }

    return slots;
  }

  String getNextSlot(String currentHour) {
    final slots = generateTimeSlots();
    final index = slots.indexOf(currentHour);

    if (index != -1 && index < slots.length - 1) {
      return slots[index + 1];
    }

    return currentHour;
  }

  int timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _weekdayFromFrenchDay(String day) {
    switch (day.trim().toLowerCase()) {
      case 'lundi':
        return DateTime.monday;
      case 'mardi':
        return DateTime.tuesday;
      case 'mercredi':
        return DateTime.wednesday;
      case 'jeudi':
        return DateTime.thursday;
      case 'vendredi':
        return DateTime.friday;
      case 'samedi':
        return DateTime.saturday;
      case 'dimanche':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  DateTime _resolveSelectedDate() {
    final today = _normalizeDate(DateTime.now());
    final targetWeekday = _weekdayFromFrenchDay(widget.day);
    final currentWeekday = today.weekday;
    final diff = targetWeekday - currentWeekday;

    return today.add(Duration(days: diff));
  }

  DateTime _combineDateAndTime(DateTime date, String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool overlaps(Activity activity) {
    final selectedStart = timeToMinutes(startTime);
    final selectedEnd = timeToMinutes(endTime);

    final activityStartDateTime = activity.resolvedStartDateTime;
    final activityEndDateTime = activity.resolvedEndDateTime;

    if (activityStartDateTime == null || activityEndDateTime == null) {
      return false;
    }

    final activityStart =
        activityStartDateTime.hour * 60 + activityStartDateTime.minute;
    final activityEnd =
        activityEndDateTime.hour * 60 + activityEndDateTime.minute;

    return activityStart < selectedEnd && activityEnd > selectedStart;
  }

  bool _matchesSelectedDay(Activity activity) {
    final selectedDate = _resolveSelectedDate();
    final activityStartDateTime = activity.resolvedStartDateTime;

    if (activityStartDateTime == null) {
      return false;
    }

    final activityDate = _normalizeDate(activityStartDateTime);
    return activityDate == selectedDate;
  }

  bool matchesFilters(Activity activity) {
    final bool categoryMatches =
        category == 'Toutes' || activity.category == category;

    final bool dayMatches = _matchesSelectedDay(activity);
    final bool timeMatches = overlaps(activity);

    return categoryMatches && dayMatches && timeMatches;
  }

  Future<void> _saveSearch() async {
    final selectedDate = _resolveSelectedDate();
    final startDateTime = _combineDateAndTime(selectedDate, startTime);
    final endDateTime = _combineDateAndTime(selectedDate, endTime);

    await searchService.saveSearch(
      day: _formatDateOnly(selectedDate),
      startTime: startTime,
      endTime: endTime,
      category: category,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
    );

    if (!mounted) return;

    setState(() => _searchSaved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recherche sauvegardée dans votre agenda'),
      ),
    );
  }

  String _statusLabel(Activity activity) {
    if (activity.isCancelled) return 'Annulée';
    if (activity.isDone || activity.hasEnded) return 'Terminée';
    if (activity.isFull) return 'Complète';
    return 'Ouverte';
  }

  Color _statusChipBackground(Activity activity) {
    if (activity.isCancelled) return Colors.red.shade100;
    if (activity.isDone || activity.hasEnded) return Colors.grey.shade300;
    if (activity.isFull) return Colors.orange.shade100;
    return Colors.green.shade100;
  }

  Color _statusChipTextColor(Activity activity) {
    if (activity.isCancelled) return Colors.red.shade800;
    if (activity.isDone || activity.hasEnded) return Colors.grey.shade800;
    if (activity.isFull) return Colors.orange.shade800;
    return Colors.green.shade800;
  }

  String _visibilityLabel(Activity activity) {
    if (activity.isInviteOnly) return 'Sur invitation';
    if (activity.isPrivate) return 'Privée';
    return 'Publique';
  }

  Color _visibilityChipBackground(Activity activity) {
    if (activity.isInviteOnly) return Colors.purple.shade100;
    if (activity.isPrivate) return Colors.blueGrey.shade100;
    return Colors.blue.shade100;
  }

  Color _visibilityChipTextColor(Activity activity) {
    if (activity.isInviteOnly) return Colors.purple.shade800;
    if (activity.isPrivate) return Colors.blueGrey.shade800;
    return Colors.blue.shade800;
  }

  String _activityTypeLabel(Activity activity) {
    if (activity.isMixedGroupActivity) {
      return 'Groupe + Public';
    }
    if (activity.isGroupPrivateActivity) {
      return 'Activité de groupe';
    }
    if (activity.isPublic) {
      return 'Activité publique';
    }
    return 'Privée';
  }

  Color _activityTypeChipBackground(Activity activity) {
    if (activity.isMixedGroupActivity) {
      return Colors.teal.shade100;
    }
    if (activity.isGroupPrivateActivity) {
      return Colors.indigo.shade100;
    }
    if (activity.isPublic) {
      return Colors.blue.shade100;
    }
    return Colors.grey.shade300;
  }

  Color _activityTypeChipTextColor(Activity activity) {
    if (activity.isMixedGroupActivity) {
      return Colors.teal.shade800;
    }
    if (activity.isGroupPrivateActivity) {
      return Colors.indigo.shade800;
    }
    if (activity.isPublic) {
      return Colors.blue.shade800;
    }
    return Colors.grey.shade800;
  }

  String _formatSchedule(Activity activity) {
    final scheduleLabel = activity.scheduleLabel.trim();

    if (scheduleLabel.isNotEmpty) {
      return scheduleLabel;
    }

    return '${activity.effectiveDay} • ${activity.effectiveStartTime} - ${activity.effectiveEndTime}';
  }

  @override
  void initState() {
    super.initState();
    startTime = widget.hour;
    endTime = getNextSlot(widget.hour);
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = generateTimeSlots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher une activité'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: _searchSaved ? null : _saveSearch,
            child: Text(
              _searchSaved
                  ? 'Recherche sauvegardée ✓'
                  : 'Sauvegarder cette recherche',
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Jour sélectionné : ${widget.day}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: startTime,
              items: timeSlots
                  .map(
                    (time) => DropdownMenuItem<String>(
                      value: time,
                      child: Text(time),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  startTime = value;
                  final selectedStart = timeToMinutes(startTime);
                  final selectedEnd = timeToMinutes(endTime);
                  if (selectedEnd <= selectedStart) {
                    endTime = getNextSlot(startTime);
                  }
                  _searchSaved = false;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Heure de début',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: endTime,
              items: timeSlots
                  .map(
                    (time) => DropdownMenuItem<String>(
                      value: time,
                      child: Text(time),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final proposedEnd = value;
                final startMinutes = timeToMinutes(startTime);
                final endMinutes = timeToMinutes(proposedEnd);
                setState(() {
                  endTime = endMinutes <= startMinutes
                      ? getNextSlot(startTime)
                      : proposedEnd;
                  _searchSaved = false;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Heure de fin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              items: categories
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  category = value;
                  _searchSaved = false;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Activity>>(
                stream: activityService.getAllActivities(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Erreur : ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final activities = snapshot.data ?? [];
                  final filteredActivities =
                      activities.where(matchesFilters).toList();

                  if (filteredActivities.isEmpty) {
                    return const Center(
                      child: Text('Aucune activité trouvée'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredActivities.length,
                    itemBuilder: (context, index) {
                      final activity = filteredActivities[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityDetailPage(
                                  activity: activity,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: FutureBuilder<bool>(
                              future:
                                  activityRepository.canJoinActivity(activity),
                              builder: (context, canJoinSnapshot) {
                                final bool canJoin =
                                    canJoinSnapshot.data ?? false;

                                String buttonLabel = 'Rejoindre';

                                if (activity.isCancelled) {
                                  buttonLabel = 'Activité annulée';
                                } else if (activity.isDone || activity.hasEnded) {
                                  buttonLabel = 'Activité terminée';
                                } else if (activity.isInviteOnly) {
                                  buttonLabel = 'Sur invitation';
                                } else if (activity.isFull) {
                                  buttonLabel = 'Activité complète';
                                } else if (activity.isMixedGroupActivity) {
                                  buttonLabel = 'Rejoindre (Groupe + Public)';
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (activity.description.trim().isNotEmpty)
                                      Text(activity.description),
                                    const SizedBox(height: 6),
                                    Text(_formatSchedule(activity)),
                                    const SizedBox(height: 4),
                                    Text(activity.location),
                                    const SizedBox(height: 4),
                                    Text('Catégorie : ${activity.category}'),
                                    if (activity.isGroupActivity &&
                                        (activity.groupName ?? '')
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Groupe : ${activity.groupName!.trim()}',
                                      ),
                                    ],
                                    const SizedBox(height: 8),
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
                                            color: _statusChipBackground(
                                              activity,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _statusLabel(activity),
                                            style: TextStyle(
                                              color: _statusChipTextColor(
                                                activity,
                                              ),
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
                                            color: _visibilityChipBackground(
                                              activity,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _visibilityLabel(activity),
                                            style: TextStyle(
                                              color: _visibilityChipTextColor(
                                                activity,
                                              ),
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
                                            color: _activityTypeChipBackground(
                                              activity,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _activityTypeLabel(activity),
                                            style: TextStyle(
                                              color: _activityTypeChipTextColor(
                                                activity,
                                              ),
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
                                            color: Colors.blue.shade100,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            activity.hasUnlimitedPlaces
                                                ? '${activity.participantCount} participant(s) • illimité'
                                                : '${activity.participantCount} / ${activity.maxParticipants} participants',
                                            style: TextStyle(
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (activity.remainingPlaces != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: activity.remainingPlaces == 0
                                                  ? Colors.red.shade100
                                                  : Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              activity.remainingPlaces == 0
                                                  ? 'Complet'
                                                  : '${activity.remainingPlaces} place(s)',
                                              style: TextStyle(
                                                color: activity.remainingPlaces == 0
                                                    ? Colors.red.shade800
                                                    : Colors.green.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: canJoin
                                            ? () async {
                                                final joined =
                                                    await activityRepository
                                                        .joinActivity(activity);

                                                if (!context.mounted) return;

                                                if (joined) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Vous avez rejoint l’activité',
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Impossible de rejoindre l’activité',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            : null,
                                        child: Text(buttonLabel),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}