import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/activity.dart';
import '../../models/activity_invitation.dart';
import '../../models/availability.dart';
import '../../services/firestore/activity_firestore_service.dart';
import '../../services/firestore/activity_invitation_firestore_service.dart';
import '../../services/firestore/availability_firestore_service.dart';
import '../../services/firestore/search_firestore_service.dart';
import '../01_auth/test_user_selector_page.dart';
import '../03_activities/activity_detail_page.dart';
import '../03_activities/create_activity_page.dart';
import '../03_activities/search_activity_page.dart';
import '../03_activities/search_detail_page.dart';
import '../03_activities/invitations_page.dart';
import '../04_profile/my_profile_page.dart';
import 'availability_detail_page.dart';
import 'note_slot_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final AvailabilityFirestoreService availabilityService =
      AvailabilityFirestoreService();
  final ActivityInvitationFirestoreService invitationService =
      ActivityInvitationFirestoreService();
  final SearchFirestoreService searchService = SearchFirestoreService();

  final List<String> days = const [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  List<String> generateTimeSlots() {
    final List<String> slots = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final hourStr = hour.toString().padLeft(2, '0');
        final minuteStr = minute.toString().padLeft(2, '0');
        slots.add('$hourStr:$minuteStr');
      }
    }
    return slots;
  }

  int timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  Activity? getActivityForSlot(
    String day,
    String slotTime,
    List<Activity> activities,
  ) {
    final slotMinutes = timeToMinutes(slotTime);

    for (final activity in activities) {
      if (activity.day != day) continue;

      final start = timeToMinutes(activity.startTime);
      final end = timeToMinutes(activity.endTime);

      if (slotMinutes >= start && slotMinutes < end) {
        return activity;
      }
    }
    return null;
  }

  Availability? getAvailabilityForSlot(
    String day,
    String slotTime,
    List<Availability> availabilities,
  ) {
    final slotMinutes = timeToMinutes(slotTime);

    for (final availability in availabilities) {
      if (availability.day != day) continue;

      final start = timeToMinutes(availability.startTime);
      final end = timeToMinutes(availability.endTime);

      if (slotMinutes >= start && slotMinutes < end) {
        return availability;
      }
    }
    return null;
  }

  Map<String, dynamic>? getSearchForSlot(
    String day,
    String slotTime,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> searches,
  ) {
    final slotMinutes = timeToMinutes(slotTime);

    for (final search in searches) {
      final data = search.data();

      if ((data['day'] ?? '').toString() != day) continue;

      final start = timeToMinutes((data['startTime'] ?? '').toString());
      final end = timeToMinutes((data['endTime'] ?? '').toString());

      if (slotMinutes >= start && slotMinutes < end) {
        return {
          'id': search.id,
          ...data,
        };
      }
    }
    return null;
  }

  List<Activity> _deduplicateJoinedActivities(
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
  ) {
    final createdIds = createdActivities.map((activity) => activity.id).toSet();

    return joinedActivities
        .where((activity) => !createdIds.contains(activity.id))
        .toList();
  }

  Future<void> _openUserSelector() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const TestUserSelectorPage(),
      ),
    );

    if (changed == true) {
      setState(() {});
    }
  }

  Future<void> _openInvitationsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InvitationsPage(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openMyProfilePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyProfilePage(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Widget _buildInvitationsIcon() {
    return StreamBuilder<List<ActivityInvitation>>(
      stream: invitationService.getPendingReceivedInvitations(),
      builder: (context, snapshot) {
        final pendingInvitations = snapshot.data ?? [];
        final pendingCount = pendingInvitations.length;

        return IconButton(
          tooltip: 'Invitations',
          onPressed: _openInvitationsPage,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.mail_outline),
              if (pendingCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      pendingCount > 99 ? '99+' : '$pendingCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = generateTimeSlots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Mon profil',
            onPressed: _openMyProfilePage,
          ),
          _buildInvitationsIcon(),
          IconButton(
            icon: const Icon(Icons.switch_account),
            tooltip: 'Changer d’utilisateur',
            onPressed: _openUserSelector,
          ),
        ],
      ),
      body: StreamBuilder<List<Activity>>(
        stream: activityService.getCreatedActivities(),
        builder: (context, createdSnapshot) {
          if (createdSnapshot.hasError) {
            return Center(
              child: Text(
                'Erreur activités créées : ${createdSnapshot.error}',
              ),
            );
          }

          if (!createdSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<List<Activity>>(
            stream: activityService.getJoinedActivities(),
            builder: (context, joinedSnapshot) {
              if (joinedSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Erreur activités rejointes : ${joinedSnapshot.error}',
                  ),
                );
              }

              if (!joinedSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return StreamBuilder<List<Availability>>(
                stream: availabilityService.getAvailabilities(),
                builder: (context, availabilitySnapshot) {
                  if (availabilitySnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erreur disponibilités : ${availabilitySnapshot.error}',
                      ),
                    );
                  }

                  if (!availabilitySnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: searchService.getSearches(),
                    builder: (context, searchSnapshot) {
                      if (searchSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erreur recherches : ${searchSnapshot.error}',
                          ),
                        );
                      }

                      if (!searchSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final createdActivities = createdSnapshot.data ?? [];
                      final joinedActivities = _deduplicateJoinedActivities(
                        createdActivities,
                        joinedSnapshot.data ?? [],
                      );
                      final availabilities = availabilitySnapshot.data ?? [];
                      final searches = searchSnapshot.data!.docs;

                      return Column(
                        children: [
                          buildDaysHeader(),
                          Expanded(
                            child: buildCalendarGrid(
                              context,
                              timeSlots,
                              createdActivities,
                              joinedActivities,
                              availabilities,
                              searches,
                            ),
                          ),
                        ],
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

  Widget buildDaysHeader() {
    return Row(
      children: [
        const SizedBox(width: 70),
        for (var day in days)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildCalendarGrid(
    BuildContext context,
    List<String> timeSlots,
    List<Activity> createdActivities,
    List<Activity> joinedActivities,
    List<Availability> availabilities,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> searches,
  ) {
    return ListView.builder(
      itemCount: timeSlots.length,
      itemBuilder: (context, index) {
        final hour = timeSlots[index];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                hour,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            for (var day in days)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final createdActivity =
                        getActivityForSlot(day, hour, createdActivities);

                    final joinedActivity =
                        getActivityForSlot(day, hour, joinedActivities);

                    final availability =
                        getAvailabilityForSlot(day, hour, availabilities);

                    final search = getSearchForSlot(day, hour, searches);

                    Color cellColor = Colors.grey[200]!;
                    String label = '';

                    if (search != null) {
                      cellColor = Colors.orange[200]!;
                      if ((search['startTime'] ?? '').toString() == hour) {
                        label = 'Recherche activité';
                      }
                    }

                    if (availability != null) {
                      cellColor = Colors.green[100]!;
                      if (availability.startTime == hour) {
                        label = availability.title;
                      }
                    }

                    if (joinedActivity != null) {
                      cellColor = Colors.purple[200]!;
                      if (joinedActivity.startTime == hour) {
                        label = joinedActivity.title;
                      }
                    }

                    if (createdActivity != null) {
                      cellColor = Colors.blue[200]!;
                      if (createdActivity.startTime == hour) {
                        label = createdActivity.title;
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        if (createdActivity != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActivityDetailPage(
                                activity: createdActivity,
                              ),
                            ),
                          );
                          return;
                        }

                        if (joinedActivity != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActivityDetailPage(
                                activity: joinedActivity,
                              ),
                            ),
                          );
                          return;
                        }

                        if (search != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchDetailPage(
                                searchId: search['id'],
                                day: (search['day'] ?? '').toString(),
                                startTime:
                                    (search['startTime'] ?? '').toString(),
                                endTime: (search['endTime'] ?? '').toString(),
                                category: (search['category'] ?? '').toString(),
                              ),
                            ),
                          );
                          return;
                        }

                        if (availability != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AvailabilityDetailPage(
                                availability: availability,
                              ),
                            ),
                          );
                          return;
                        }

                        showSlotActions(context, day, hour);
                      },
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.all(1),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: cellColor,
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: label.isNotEmpty
                            ? Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void showSlotActions(BuildContext context, String day, String hour) {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$day - $hour',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            NoteSlotPage(day: day, hour: hour),
                      ),
                    );
                  },
                  child: const Text('Noter une activité'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SearchActivityPage(day: day, hour: hour),
                      ),
                    );
                  },
                  child: const Text('Rechercher une activité'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreateActivityPage(day: day, hour: hour),
                      ),
                    );
                  },
                  child: const Text('Créer une activité'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}