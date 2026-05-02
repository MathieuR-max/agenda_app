import 'package:flutter/material.dart';

import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/user_model.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/repositories/chat_repository.dart';
import 'package:agenda_app/repositories/profile_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';

import 'activity_detail_page.dart';

class AllActivitiesPage extends StatefulWidget {
  const AllActivitiesPage({super.key});

  @override
  State<AllActivitiesPage> createState() => _AllActivitiesPageState();
}

class _AllActivitiesPageState extends State<AllActivitiesPage> {
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final ActivityRepository activityRepository = ActivityRepository();
  final ChatRepository chatRepository = ChatRepository();
  final ProfileRepository profileRepository = ProfileRepository();

  String selectedDay = 'Tous';
  String selectedCategory = 'Toutes';
  String selectedSort = 'Jour / heure';

  bool onlyAvailable = false;
  bool onlyOwnerNeeded = false;
  bool onlyMyFavorites = false;
  bool prioritizeUnreadMessages = true;

  final Map<String, int> _unreadCountsByActivityId = <String, int>{};

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

  void _rememberUnreadCount(String activityId, int count) {
    final trimmedActivityId = activityId.trim();
    if (trimmedActivityId.isEmpty) return;

    final previous = _unreadCountsByActivityId[trimmedActivityId] ?? 0;
    if (previous == count) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _unreadCountsByActivityId[trimmedActivityId] = count;
      });
    });
  }

  int _unreadCountFor(Activity activity) {
    return _unreadCountsByActivityId[activity.id.trim()] ?? 0;
  }

  void _sortUnreadFirst(List<Activity> activities) {
    if (!prioritizeUnreadMessages) return;

    activities.sort((a, b) {
      final aUnread = _unreadCountFor(a);
      final bUnread = _unreadCountFor(b);

      final aHasUnread = aUnread > 0;
      final bHasUnread = bUnread > 0;

      if (aHasUnread != bHasUnread) {
        return bHasUnread ? 1 : -1;
      }

      if (aUnread != bUnread) {
        return bUnread.compareTo(aUnread);
      }

      final aTime = a.lastMessageAt ?? a.updatedAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.updatedAt ?? b.createdAt;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });
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
        return 99;
    }
  }

  int dayOrder(Activity activity) {
    final start = activity.resolvedStartDateTime;
    if (start != null) return start.weekday;

    final weekday = _weekdayFromFrenchDay(activity.effectiveDay);
    return weekday == 99 ? 99 : weekday;
  }

  int timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  int startMinutesFor(Activity activity) {
    final start = activity.resolvedStartDateTime;
    if (start != null) return start.hour * 60 + start.minute;

    return timeToMinutes(activity.effectiveStartTime);
  }

  int remainingPlacesFor(Activity activity) {
    if (activity.maxParticipants <= 0) return 999999;
    return activity.maxParticipants - activity.participantCount;
  }

  bool isFull(Activity activity) {
    return activity.isFull ||
        (activity.maxParticipants > 0 &&
            activity.participantCount >= activity.maxParticipants);
  }

  bool _matchesSelectedDay(Activity activity) {
    if (selectedDay == 'Tous') return true;

    final start = activity.resolvedStartDateTime;
    if (start != null) {
      return _weekdayFromFrenchDay(selectedDay) == start.weekday;
    }

    return activity.effectiveDay == selectedDay;
  }

  List<Activity> _mergeActivities({
    required List<Activity> createdActivities,
    required List<Activity> joinedActivities,
  }) {
    final Map<String, Activity> mergedById = {};

    for (final activity in createdActivities) {
      final activityId = activity.id.trim();
      if (activityId.isNotEmpty) {
        mergedById[activityId] = activity;
      }
    }

    for (final activity in joinedActivities) {
      final activityId = activity.id.trim();
      if (activityId.isNotEmpty) {
        mergedById[activityId] = activity;
      }
    }

    return mergedById.values.toList();
  }

  List<Activity> filterAndSortActivities({
    required List<Activity> activities,
    required List<String> favoriteCategories,
    required List<String> joinedIds,
    required String currentUserId,
  }) {
    final normalizedCurrentUserId = currentUserId.trim();
    final normalizedJoinedIds = joinedIds.map((id) => id.trim()).toSet();

    final filtered = activities.where((activity) {
      final activityId = activity.id.trim();

      final bool validActivityId = activityId.isNotEmpty;
      final bool validTitle = activity.title.trim().isNotEmpty;

      final bool dayOk = _matchesSelectedDay(activity);
      final bool categoryOk =
          selectedCategory == 'Toutes' || activity.category == selectedCategory;

      final bool availableOk =
          !onlyAvailable ||
          (!isFull(activity) &&
              !activity.isCancelled &&
              !activity.isDone &&
              !activity.hasEnded);

      final bool ownerNeededOk = !onlyOwnerNeeded || activity.ownerPending;
      final bool favoriteOk =
          !onlyMyFavorites || favoriteCategories.contains(activity.category);

      final bool isOwner = activity.ownerId.trim() == normalizedCurrentUserId;
      final bool isParticipant = normalizedJoinedIds.contains(activityId);
      final bool participationOk = isOwner || isParticipant;

      return validActivityId &&
          validTitle &&
          dayOk &&
          categoryOk &&
          availableOk &&
          ownerNeededOk &&
          favoriteOk &&
          participationOk;
    }).toList();

    switch (selectedSort) {
      case 'Places restantes':
        filtered.sort((a, b) {
          final remainingCompare =
              remainingPlacesFor(b).compareTo(remainingPlacesFor(a));
          if (remainingCompare != 0) return remainingCompare;

          final dayCompare = dayOrder(a).compareTo(dayOrder(b));
          if (dayCompare != 0) return dayCompare;

          return startMinutesFor(a).compareTo(startMinutesFor(b));
        });
        break;

      case 'Plus récent':
        filtered.sort((a, b) {
          final aTime = a.lastMessageAt ??
              a.updatedAt ??
              a.createdAt ??
              a.resolvedStartDateTime;
          final bTime = b.lastMessageAt ??
              b.updatedAt ??
              b.createdAt ??
              b.resolvedStartDateTime;

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
          final aDate = a.effectiveSortDateTime ??
              a.updatedAt ??
              a.createdAt ??
              DateTime(2100);
          final bDate = b.effectiveSortDateTime ??
              b.updatedAt ??
              b.createdAt ??
              DateTime(2100);

          final compareDate = aDate.compareTo(bDate);
          if (compareDate != 0) return compareDate;

          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }

    _sortUnreadFirst(filtered);

    return filtered;
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

  String _statusLabel(Activity activity) {
    if (activity.isCancelled) return 'Annulée';
    if (activity.isDone || activity.hasEnded) return 'Terminée';
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

  String _activityTypeLabel(Activity activity) {
    if (activity.isMixedGroupActivity) return 'Groupe + Public';
    if (activity.isGroupPrivateActivity) return 'Activité de groupe';
    if (activity.isPublic) return 'Activité publique';
    return 'Privée';
  }

  Color _activityTypeChipBackground(Activity activity) {
    if (activity.isMixedGroupActivity) return Colors.teal.shade100;
    if (activity.isGroupPrivateActivity) return Colors.indigo.shade100;
    if (activity.isPublic) return Colors.blue.shade100;
    return Colors.grey.shade300;
  }

  Color _activityTypeChipTextColor(Activity activity) {
    if (activity.isMixedGroupActivity) return Colors.teal.shade800;
    if (activity.isGroupPrivateActivity) return Colors.indigo.shade800;
    if (activity.isPublic) return Colors.blue.shade800;
    return Colors.grey.shade800;
  }

  Widget _buildChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int unreadCount) {
    if (unreadCount <= 0) return const SizedBox.shrink();

    final label = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildUnreadInfo({
    required Activity activity,
    required int unreadCount,
  }) {
    if (unreadCount <= 0) return const SizedBox.shrink();

    final lastMessage = (activity.lastMessageText ?? '').trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.mark_chat_unread_outlined,
            size: 18,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lastMessage.isNotEmpty
                  ? '$unreadCount nouveau(x) message(s) • $lastMessage'
                  : '$unreadCount nouveau(x) message(s)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _joinButtonLabel({
    required Activity activity,
    required bool isOwner,
    required bool isParticipant,
    required bool full,
  }) {
    if (isOwner) return 'Vous êtes organisateur';
    if (isParticipant) return 'Déjà participant';
    if (activity.isCancelled) return 'Activité annulée';
    if (activity.isDone || activity.hasEnded) return 'Activité terminée';
    if (activity.isInviteOnly) return 'Sur invitation';
    if (full) return 'Activité complète';
    if (activity.isMixedGroupActivity) return 'Rejoindre (Groupe + Public)';
    return 'Rejoindre';
  }

  String _formatSchedule(Activity activity) {
    final scheduleLabel = activity.scheduleLabel.trim();

    if (scheduleLabel.isNotEmpty) return scheduleLabel;

    return '${activity.effectiveDay} • ${activity.effectiveStartTime} - ${activity.effectiveEndTime}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthUser.uidOrNull?.trim();

    if (currentUserId == null || currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Utilisateur non connecté'),
        ),
      );
    }

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
                            value: selectedDay,
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
                            value: selectedCategory,
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
                      value: selectedSort,
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
                      title: const Text('Prioriser les messages non lus'),
                      value: prioritizeUnreadMessages,
                      onChanged: (value) {
                        setState(() {
                          prioritizeUnreadMessages = value;
                        });
                      },
                    ),
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
                      value:
                          favoriteCategories.isEmpty ? false : onlyMyFavorites,
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
                      builder: (context, joinedActivitiesSnapshot) {
                        if (joinedActivitiesSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'Erreur activités rejointes : ${joinedActivitiesSnapshot.error}',
                            ),
                          );
                        }

                        if (!joinedActivitiesSnapshot.hasData) {
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
                                  'Erreur IDs activités rejointes : ${joinedIdsSnapshot.error}',
                                ),
                              );
                            }

                            if (!joinedIdsSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final createdActivities =
                                createdSnapshot.data ?? [];
                            final joinedActivities =
                                joinedActivitiesSnapshot.data ?? [];
                            final joinedIds = joinedIdsSnapshot.data ?? [];

                            final sourceActivities = _mergeActivities(
                              createdActivities: createdActivities,
                              joinedActivities: joinedActivities,
                            );

                            final activities = filterAndSortActivities(
                              activities: sourceActivities,
                              favoriteCategories: favoriteCategories,
                              joinedIds: joinedIds,
                              currentUserId: currentUserId,
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

                                final participantCount =
                                    activity.participantCount;
                                final maxParticipants =
                                    activity.maxParticipants;

                                final full = isFull(activity);
                                final remainingPlaces =
                                    activity.remainingPlaces;

                                final organizerName =
                                    activity.ownerPseudo.isNotEmpty
                                        ? activity.ownerPseudo
                                        : activity.ownerId;

                                final isOwner =
                                    activity.ownerId.trim() == currentUserId;
                                final isParticipant = joinedIds
                                    .map((id) => id.trim())
                                    .contains(activity.id.trim());

                                final buttonLabel = _joinButtonLabel(
                                  activity: activity,
                                  isOwner: isOwner,
                                  isParticipant: isParticipant,
                                  full: full,
                                );

                                return StreamBuilder<int>(
                                  stream: chatRepository.watchUnreadCount(
                                    activity.id,
                                  ),
                                  builder: (context, unreadSnapshot) {
                                    final unreadCount =
                                        unreadSnapshot.data ?? 0;

                                    _rememberUnreadCount(
                                      activity.id,
                                      unreadCount,
                                    );

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ActivityDetailPage(
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
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      activity.title,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  _buildUnreadBadge(
                                                    unreadCount,
                                                  ),
                                                ],
                                              ),
                                              _buildUnreadInfo(
                                                activity: activity,
                                                unreadCount: unreadCount,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(_formatSchedule(activity)),
                                              const SizedBox(height: 4),
                                              Text(activity.location),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Catégorie : ${activity.category}',
                                              ),
                                              if (activity.isGroupActivity &&
                                                  (activity.groupName ?? '')
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Groupe : ${activity.groupName!.trim()}',
                                                ),
                                              ],
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
                                                Text(
                                                  'Organisé par : $organizerName',
                                                ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _buildChip(
                                                    label: activity
                                                            .hasUnlimitedPlaces
                                                        ? '$participantCount participant(s) • illimité'
                                                        : '$participantCount / $maxParticipants participants',
                                                    backgroundColor: full
                                                        ? Colors.red.shade100
                                                        : Colors.blue.shade100,
                                                    textColor: full
                                                        ? Colors.red.shade800
                                                        : Colors.blue.shade800,
                                                  ),
                                                  if (remainingPlaces != null)
                                                    _buildChip(
                                                      label: full
                                                          ? 'Complet'
                                                          : '$remainingPlaces place(s)',
                                                      backgroundColor: full
                                                          ? Colors.red.shade100
                                                          : Colors
                                                              .green.shade100,
                                                      textColor: full
                                                          ? Colors.red.shade800
                                                          : Colors
                                                              .green.shade800,
                                                    ),
                                                  _buildChip(
                                                    label:
                                                        _statusLabel(activity),
                                                    backgroundColor:
                                                        _statusChipBackground(
                                                      activity,
                                                    ),
                                                    textColor:
                                                        _statusChipTextColor(
                                                      activity,
                                                    ),
                                                  ),
                                                  _buildChip(
                                                    label: _visibilityLabel(
                                                      activity,
                                                    ),
                                                    backgroundColor:
                                                        _visibilityChipBackground(
                                                      activity,
                                                    ),
                                                    textColor:
                                                        _visibilityChipTextColor(
                                                      activity,
                                                    ),
                                                  ),
                                                  _buildChip(
                                                    label: _activityTypeLabel(
                                                      activity,
                                                    ),
                                                    backgroundColor:
                                                        _activityTypeChipBackground(
                                                      activity,
                                                    ),
                                                    textColor:
                                                        _activityTypeChipTextColor(
                                                      activity,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if ((activity.lastMessageText ?? '')
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 10),
                                                Text(
                                                  'Dernier message : ${activity.lastMessageText!.trim()}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 12),
                                              FutureBuilder<bool>(
                                                future: activityRepository
                                                    .canJoinActivity(activity),
                                                builder:
                                                    (context, joinSnapshot) {
                                                  final repositoryCanJoin =
                                                      joinSnapshot.data ??
                                                          false;

                                                  final canJoin = !isOwner &&
                                                      !isParticipant &&
                                                      repositoryCanJoin;

                                                  return SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      onPressed: canJoin
                                                          ? () async {
                                                              final joined =
                                                                  await activityRepository
                                                                      .joinActivity(
                                                                activity,
                                                              );

                                                              if (!context
                                                                  .mounted) {
                                                                return;
                                                              }

                                                              ScaffoldMessenger
                                                                      .of(
                                                                context,
                                                              ).showSnackBar(
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
                                                  );
                                                },
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