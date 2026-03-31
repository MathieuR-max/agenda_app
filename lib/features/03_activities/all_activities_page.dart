import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/user_model.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/repositories/profile_repository.dart';
import 'activity_detail_page.dart';

class AllActivitiesPage extends StatefulWidget {
  const AllActivitiesPage({super.key});

  @override
  State<AllActivitiesPage> createState() => _AllActivitiesPageState();
}

class _AllActivitiesPageState extends State<AllActivitiesPage> {
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final ActivityRepository activityRepository = ActivityRepository();
  final ProfileRepository profileRepository = ProfileRepository();

  String selectedDay = 'Tous';
  String selectedCategory = 'Toutes';
  String selectedSort = 'Jour / heure';

  bool onlyAvailable = false;
  bool onlyOwnerNeeded = false;
  bool onlyMyFavorites = false;

  final List<String> days = const [
    'Tous',
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

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

  final List<String> sortOptions = const [
    'Jour / heure',
    'Places restantes',
    'Plus récent',
    'Titre A → Z',
  ];

  int dayOrder(String day) {
    const orderedDays = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return orderedDays.indexOf(day);
  }

  int timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  int remainingPlacesFor(Activity activity) {
    if (activity.maxParticipants <= 0) {
      return 999999;
    }

    return activity.maxParticipants - activity.participantCount;
  }

  bool isFull(Activity activity) {
    return activity.isFull ||
        (activity.maxParticipants > 0 &&
            activity.participantCount >= activity.maxParticipants);
  }

  List<Activity> filterAndSortActivities(
    List<Activity> activities,
    List<String> favoriteCategories,
  ) {
    final filtered = activities.where((activity) {
      final bool dayOk = selectedDay == 'Tous' || activity.day == selectedDay;
      final bool categoryOk =
          selectedCategory == 'Toutes' || activity.category == selectedCategory;

      final bool availableOk =
          !onlyAvailable ||
          (!isFull(activity) && !activity.isCancelled && !activity.isDone);

      final bool ownerNeededOk = !onlyOwnerNeeded || activity.ownerPending;
      final bool favoriteOk =
          !onlyMyFavorites || favoriteCategories.contains(activity.category);

      final bool visibilityOk = activity.isPublic;

      return dayOk &&
          categoryOk &&
          availableOk &&
          ownerNeededOk &&
          favoriteOk &&
          visibilityOk;
    }).toList();

    switch (selectedSort) {
      case 'Places restantes':
        filtered.sort((a, b) {
          final remainingCompare =
              remainingPlacesFor(b).compareTo(remainingPlacesFor(a));
          if (remainingCompare != 0) return remainingCompare;

          final dayCompare = dayOrder(a.day).compareTo(dayOrder(b.day));
          if (dayCompare != 0) return dayCompare;

          return timeToMinutes(a.startTime)
              .compareTo(timeToMinutes(b.startTime));
        });
        break;

      case 'Plus récent':
        filtered.sort((a, b) {
          final aTime = a.lastMessageAt ?? a.createdAt;
          final bTime = b.lastMessageAt ?? b.createdAt;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime);
        });
        break;

      case 'Titre A → Z':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;

      case 'Jour / heure':
      default:
        filtered.sort((a, b) {
          final dayCompare = dayOrder(a.day).compareTo(dayOrder(b.day));
          if (dayCompare != 0) return dayCompare;
          return timeToMinutes(a.startTime)
              .compareTo(timeToMinutes(b.startTime));
        });
        break;
    }

    return filtered;
  }

  Color _statusChipBackground(Activity activity) {
    if (activity.isCancelled) return Colors.red.shade100;
    if (activity.isDone) return Colors.grey.shade300;
    if (activity.isFull) return Colors.orange.shade100;
    return Colors.green.shade100;
  }

  Color _statusChipTextColor(Activity activity) {
    if (activity.isCancelled) return Colors.red.shade800;
    if (activity.isDone) return Colors.grey.shade800;
    if (activity.isFull) return Colors.orange.shade800;
    return Colors.green.shade800;
  }

  String _statusLabel(Activity activity) {
    if (activity.isCancelled) return 'Annulée';
    if (activity.isDone) return 'Terminée';
    if (activity.isFull) return 'Complète';
    return 'Ouverte';
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = CurrentUser.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorer'),
      ),
      body: StreamBuilder<UserModel?>(
        stream: profileRepository.watchUser(currentUserId),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(
              child: Text('Erreur profil : ${userSnapshot.error}'),
            );
          }

          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final currentUser = userSnapshot.data;
          final favoriteCategories = currentUser?.favoriteCategories ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDay,
                            decoration: const InputDecoration(
                              labelText: 'Jour',
                              border: OutlineInputBorder(),
                            ),
                            items: days
                                .map(
                                  (day) => DropdownMenuItem(
                                    value: day,
                                    child: Text(day),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                selectedDay = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Catégorie',
                              border: OutlineInputBorder(),
                            ),
                            items: categories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                selectedCategory = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSort,
                      decoration: const InputDecoration(
                        labelText: 'Trier par',
                        border: OutlineInputBorder(),
                      ),
                      items: sortOptions
                          .map(
                            (sort) => DropdownMenuItem(
                              value: sort,
                              child: Text(sort),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedSort = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Seulement avec places disponibles'),
                      value: onlyAvailable,
                      onChanged: (value) {
                        setState(() {
                          onlyAvailable = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Seulement organisateur recherché'),
                      value: onlyOwnerNeeded,
                      onChanged: (value) {
                        setState(() {
                          onlyOwnerNeeded = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Seulement mes catégories favorites'),
                      subtitle: favoriteCategories.isEmpty
                          ? const Text(
                              'Ajoutez des catégories favorites dans votre profil',
                            )
                          : Text(favoriteCategories.join(', ')),
                      value: favoriteCategories.isEmpty ? false : onlyMyFavorites,
                      onChanged: favoriteCategories.isEmpty
                          ? null
                          : (value) {
                              setState(() {
                                onlyMyFavorites = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Activity>>(
                  stream: activityService.getAllActivities(),
                  builder: (context, allSnapshot) {
                    if (allSnapshot.hasError) {
                      return Center(
                        child: Text('Erreur activités : ${allSnapshot.error}'),
                      );
                    }

                    if (!allSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    return StreamBuilder<List<String>>(
                      stream: activityService.getJoinedActivityIds(),
                      builder: (context, joinedIdsSnapshot) {
                        if (joinedIdsSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'Erreur activités rejointes : ${joinedIdsSnapshot.error}',
                            ),
                          );
                        }

                        if (!joinedIdsSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final joinedIds = joinedIdsSnapshot.data ?? [];
                        final allActivities = allSnapshot.data ?? [];
                        final activities = filterAndSortActivities(
                          allActivities,
                          favoriteCategories,
                        );

                        if (activities.isEmpty) {
                          return const Center(
                            child: Text('Aucune activité trouvée'),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: activities.length,
                          itemBuilder: (context, index) {
                            final activity = activities[index];

                            final int participantCount = activity.participantCount;
                            final int maxParticipants = activity.maxParticipants;

                            final bool full = isFull(activity);

                            final int? remainingPlaces = maxParticipants > 0
                                ? (maxParticipants - participantCount)
                                : null;

                            final String organizerName =
                                activity.ownerPseudo.isNotEmpty
                                    ? activity.ownerPseudo
                                    : activity.ownerId;

                            final bool isOwner = activity.ownerId == currentUserId;
                            final bool isParticipant =
                                joinedIds.contains(activity.id);

                            String buttonLabel = 'Rejoindre';
                            bool canJoin = true;

                            if (isOwner) {
                              buttonLabel = 'Vous êtes organisateur';
                              canJoin = false;
                            } else if (isParticipant) {
                              buttonLabel = 'Déjà participant';
                              canJoin = false;
                            } else if (activity.isCancelled) {
                              buttonLabel = 'Activité annulée';
                              canJoin = false;
                            } else if (activity.isDone) {
                              buttonLabel = 'Activité terminée';
                              canJoin = false;
                            } else if (activity.isInviteOnly) {
                              buttonLabel = 'Sur invitation';
                              canJoin = false;
                            } else if (full) {
                              buttonLabel = 'Activité complète';
                              canJoin = false;
                            }

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
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activity.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${activity.day} • ${activity.startTime} - ${activity.endTime}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(activity.location),
                                      const SizedBox(height: 4),
                                      Text('Catégorie : ${activity.category}'),
                                      const SizedBox(height: 4),
                                      if (activity.ownerPending)
                                        const Text(
                                          'Organisateur recherché',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      else
                                        Text('Organisé par : $organizerName'),
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
                                              color: full
                                                  ? Colors.red.shade100
                                                  : Colors.blue.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              maxParticipants > 0
                                                  ? '$participantCount / $maxParticipants participants'
                                                  : '$participantCount participant(s)',
                                              style: TextStyle(
                                                color: full
                                                    ? Colors.red.shade800
                                                    : Colors.blue.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (remainingPlaces != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: full
                                                    ? Colors.red.shade100
                                                    : Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                full
                                                    ? 'Complet'
                                                    : '$remainingPlaces place(s)',
                                                style: TextStyle(
                                                  color: full
                                                      ? Colors.red.shade800
                                                      : Colors.green.shade800,
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
                                              color: _statusChipBackground(activity),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _statusLabel(activity),
                                              style: TextStyle(
                                                color: _statusChipTextColor(activity),
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
                                        ],
                                      ),
                                      if ((activity.lastMessageText ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          'Dernier message : ${activity.lastMessageText!}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: canJoin
                                              ? () async {
                                                  final joined =
                                                      await activityRepository
                                                          .joinActivity(activity);

                                                  if (!context.mounted) return;

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        joined
                                                            ? 'Vous avez rejoint l’activité'
                                                            : 'Impossible de rejoindre l’activité',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              : null,
                                          child: Text(buttonLabel),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}