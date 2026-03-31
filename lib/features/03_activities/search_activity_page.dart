import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/search_firestore_service.dart';

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

  final List<String> categories = [
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
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool overlaps(Activity activity) {
    final selectedStart = timeToMinutes(startTime);
    final selectedEnd = timeToMinutes(endTime);
    final activityStart = timeToMinutes(activity.startTime);
    final activityEnd = timeToMinutes(activity.endTime);

    return activityStart < selectedEnd && activityEnd > selectedStart;
  }

  bool matchesFilters(Activity activity) {
    final bool categoryMatches =
        category == 'Toutes' || activity.category == category;

    final bool dayMatches = activity.day == widget.day;
    final bool timeMatches = overlaps(activity);

    return categoryMatches && dayMatches && timeMatches;
  }

  Future<void> _saveSearchIfNeeded() async {
    if (_searchSaved) return;

    await searchService.saveSearch(
      day: widget.day,
      startTime: startTime,
      endTime: endTime,
      category: category,
    );

    _searchSaved = true;
  }

  @override
  void initState() {
    super.initState();
    startTime = widget.hour;
    endTime = getNextSlot(widget.hour);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _saveSearchIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = generateTimeSlots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher une activité'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Jour sélectionné : ${widget.day}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: startTime,
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
                  if (startTime == endTime) {
                    endTime = getNextSlot(startTime);
                  }
                });
              },
              decoration: const InputDecoration(
                labelText: 'Heure de début',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: endTime,
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
                  endTime = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Heure de fin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
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
                              Text(activity.description),
                              const SizedBox(height: 6),
                              Text(
                                '${activity.day} ${activity.startTime} - ${activity.endTime}',
                              ),
                              Text(activity.location),
                              Text(activity.category),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  final joined = await activityRepository
                                      .joinActivity(activity);

                                  if (!context.mounted) return;

                                  if (joined) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Vous avez rejoint l’activité',
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Activité complète ou déjà rejointe',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Rejoindre'),
                              ),
                            ],
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