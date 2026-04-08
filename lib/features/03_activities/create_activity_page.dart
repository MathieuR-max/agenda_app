import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/models/group_model.dart';
import 'package:agenda_app/repositories/activity_invitation_repository.dart';
import 'package:agenda_app/repositories/activity_repository.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class CreateActivityPage extends StatefulWidget {
  final String day;
  final String hour;
  final DateTime? selectedDate;
  final String? groupId;
  final String? groupName;

  const CreateActivityPage({
    super.key,
    required this.day,
    required this.hour,
    this.selectedDate,
    this.groupId,
    this.groupName,
  });

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController maxParticipantsController =
      TextEditingController();

  final ActivityRepository activityRepository = ActivityRepository();
  final ActivityInvitationRepository invitationRepository =
      ActivityInvitationRepository();
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final UserFirestoreService userService = UserFirestoreService();
  final FriendshipRepository friendshipRepository = FriendshipRepository();
  final GroupsRepository groupsRepository = GroupsRepository();

  String category = 'Sport';
  String level = 'Tous niveaux';
  String groupType = 'Ouvert à tous';
  String visibility = ActivityVisibilityValues.public;
  String groupActivityAccess = 'group_only';

  late String startTime;
  late String endTime;
  late DateTime selectedDate;

  String? selectedGroupId;
  String? selectedGroupName;

  bool isSaving = false;

  final Set<String> selectedFriendIds = <String>{};

  final List<String> categories = const [
    'Sport',
    'Sortie',
    'Culture',
    'Jeux',
    'Études',
    'Travail',
    'Détente',
    'Autre',
  ];

  final List<String> levels = const [
    'Débutant',
    'Intermédiaire',
    'Confirmé',
    'Tous niveaux',
  ];

  final List<String> groupTypes = const [
    'Ouvert à tous',
    'Femmes uniquement',
    'Hommes uniquement',
    'Non mixte',
    'Privé',
  ];

  final List<Map<String, String>> visibilityOptions = const [
    {
      'value': ActivityVisibilityValues.public,
      'label': 'Publique',
    },
    {
      'value': ActivityVisibilityValues.private,
      'label': 'Privée',
    },
    {
      'value': ActivityVisibilityValues.inviteOnly,
      'label': 'Sur invitation',
    },
  ];

  final List<Map<String, String>> groupActivityAccessOptions = const [
    {
      'value': 'group_only',
      'label': 'Réservée au groupe',
    },
    {
      'value': 'group_and_public',
      'label': 'Groupe + nouveaux participants',
    },
  ];

  bool get isGroupActivity =>
      selectedGroupId != null && selectedGroupId!.trim().isNotEmpty;

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

  String getNextSlot(String currentHour) {
    final slots = generateTimeSlots();
    final index = slots.indexOf(currentHour);

    if (index != -1 && index < slots.length - 1) {
      return slots[index + 1];
    }

    return currentHour;
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
    if (widget.selectedDate != null) {
      return _normalizeDate(widget.selectedDate!);
    }

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

  String _formatDisplayDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  String _schedulePreview() {
    return '${_formatDisplayDate(selectedDate)} • $startTime - $endTime';
  }

  String _groupActivityInfoText() {
    final hasGroupName =
        selectedGroupName != null && selectedGroupName!.trim().isNotEmpty;
    final displayedGroupName = hasGroupName ? selectedGroupName!.trim() : '';

    if (groupActivityAccess == 'group_and_public') {
      return hasGroupName
          ? 'Activité liée au groupe "$displayedGroupName" et ouverte à de nouveaux participants.'
          : 'Activité liée à un groupe et ouverte à de nouveaux participants.';
    }

    return hasGroupName
        ? 'Activité réservée aux membres du groupe "$displayedGroupName".'
        : 'Activité réservée aux membres du groupe.';
  }

  String _displayUserName(Map<String, dynamic> user) {
    final pseudo = (user['pseudo'] ?? '').toString().trim();
    final prenom = (user['prenom'] ?? '').toString().trim();
    final nom = (user['nom'] ?? '').toString().trim();

    if (pseudo.isNotEmpty) return pseudo;
    if (prenom.isNotEmpty && nom.isNotEmpty) return '$prenom $nom';
    if (prenom.isNotEmpty) return prenom;
    return 'Utilisateur';
  }

  Future<List<Friendship>> _loadAcceptedFriendships() async {
    final friendships = await friendshipRepository.getAcceptedFriendships();

    friendships.sort((a, b) {
      final aDate = a.respondedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.respondedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return friendships;
  }

  Future<List<Map<String, dynamic>>> _loadFriendsFromFriendships() async {
    final friendships = await _loadAcceptedFriendships();
    final List<Map<String, dynamic>> users = [];

    for (final friendship in friendships) {
      final friendId = friendshipRepository.getOtherUserId(friendship).trim();
      if (friendId.isEmpty) continue;

      final data = await userService.getUserById(friendId);
      if (data == null) continue;

      users.add({
        'id': friendId,
        ...data,
      });
    }

    users.sort((a, b) {
      final aName = _displayUserName(a).toLowerCase();
      final bName = _displayUserName(b).toLowerCase();
      return aName.compareTo(bName);
    });

    return users;
  }

  Future<void> _openFriendSelection(
    BuildContext context,
    List<Map<String, dynamic>> friends,
  ) async {
    final Set<String> tempSelected = Set<String>.from(selectedFriendIds);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choisir les amis à inviter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: friends.isEmpty
                            ? const Center(
                                child: Text('Aucun ami disponible'),
                              )
                            : ListView.builder(
                                itemCount: friends.length,
                                itemBuilder: (context, index) {
                                  final friend = friends[index];
                                  final friendId =
                                      (friend['id'] ?? '').toString();
                                  final selected =
                                      tempSelected.contains(friendId);

                                  return CheckboxListTile(
                                    value: selected,
                                    onChanged: (value) {
                                      setModalState(() {
                                        if (value == true) {
                                          tempSelected.add(friendId);
                                        } else {
                                          tempSelected.remove(friendId);
                                        }
                                      });
                                    },
                                    title: Text(_displayUserName(friend)),
                                    subtitle: Text(
                                      ((friend['lieu'] ?? '')).toString().trim()
                                              .isNotEmpty
                                          ? (friend['lieu'] ?? '').toString()
                                          : 'Lieu non renseigné',
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                              },
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(
                                  bottomSheetContext,
                                  tempSelected,
                                );
                              },
                              child: const Text('Valider'),
                            ),
                          ),
                        ],
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

    if (result == null) return;

    setState(() {
      selectedFriendIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _openGroupSelection(
    BuildContext context,
    List<GroupModel> groups,
  ) async {
    final GroupModel? result = await showModalBottomSheet<GroupModel?>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choisir un groupe',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: groups.isEmpty
                        ? const Center(
                            child: Text('Aucun groupe disponible'),
                          )
                        : ListView.builder(
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.groups),
                                  title: Text(group.name),
                                  subtitle: Text(
                                    group.description.trim().isNotEmpty
                                        ? group.description
                                        : 'Aucune description',
                                  ),
                                  onTap: () {
                                    Navigator.pop(bottomSheetContext, group);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;

    setState(() {
      selectedGroupId = result.id;
      selectedGroupName = result.name;
      visibility = ActivityVisibilityValues.private;
      groupType = 'Privé';
      groupActivityAccess = 'group_only';
    });
  }

  Future<void> _sendInvitationsAfterCreate(
    String activityId,
    List<String> friendIds,
  ) async {
    final createdActivity = await activityService.getActivityById(activityId);
    if (createdActivity == null) return;

    final Set<String> recipients = <String>{};

    for (final friendId in friendIds) {
      final trimmedId = friendId.trim();
      if (trimmedId.isNotEmpty) {
        recipients.add(trimmedId);
      }
    }

    if (selectedGroupId != null && selectedGroupId!.trim().isNotEmpty) {
      final memberIds =
          await groupsRepository.getGroupMemberIds(selectedGroupId!);
      for (final memberId in memberIds) {
        final trimmedId = memberId.trim();
        if (trimmedId.isNotEmpty) {
          recipients.add(trimmedId);
        }
      }
    }

    recipients.remove(CurrentUser.id);

    for (final userId in recipients) {
      await invitationRepository.sendActivityInvitation(
        activity: createdActivity,
        toUserId: userId,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    selectedDate = _resolveSelectedDate();
    startTime = widget.hour;
    endTime = getNextSlot(widget.hour);

    if (timeToMinutes(endTime) <= timeToMinutes(startTime)) {
      endTime = getNextSlot(startTime);
    }

    selectedGroupId = widget.groupId?.trim().isNotEmpty == true
        ? widget.groupId!.trim()
        : null;
    selectedGroupName = widget.groupName?.trim().isNotEmpty == true
        ? widget.groupName!.trim()
        : null;

    if (isGroupActivity) {
      visibility = ActivityVisibilityValues.private;
      groupType = 'Privé';
      groupActivityAccess = 'group_only';
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _createActivity() async {
    if (isSaving) return;

    final trimmedTitle = titleController.text.trim();
    final trimmedDescription = descriptionController.text.trim();
    final trimmedLocation = locationController.text.trim();

    if (trimmedTitle.isEmpty ||
        trimmedDescription.isEmpty ||
        trimmedLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de remplir les champs obligatoires'),
        ),
      );
      return;
    }

    final startMinutes = timeToMinutes(startTime);
    final endMinutes = timeToMinutes(endTime);

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’heure de fin doit être après l’heure de début',
          ),
        ),
      );
      return;
    }

    final maxParticipantsText = maxParticipantsController.text.trim();
    final normalizedMaxParticipants =
        maxParticipantsText.isEmpty ? '0' : maxParticipantsText;

    if (maxParticipantsText.isNotEmpty) {
      final parsed = int.tryParse(maxParticipantsText);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le nombre max de participants doit être un nombre valide',
            ),
          ),
        );
        return;
      }
    }

    final startDateTime = _combineDateAndTime(selectedDate, startTime);
    final endDateTime = _combineDateAndTime(selectedDate, endTime);

    if (!endDateTime.isAfter(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La date de fin doit être après la date de début',
          ),
        ),
      );
      return;
    }

    final effectiveVisibility = isGroupActivity
        ? (groupActivityAccess == 'group_and_public'
            ? ActivityVisibilityValues.public
            : ActivityVisibilityValues.private)
        : visibility;

    setState(() {
      isSaving = true;
    });

    try {
      final selectedFriendsSnapshot = selectedFriendIds.toList();

      final activityId = await activityRepository.createActivity(
        title: trimmedTitle,
        description: trimmedDescription,
        category: category,
        day: _formatDateOnly(selectedDate),
        startTime: startTime,
        endTime: endTime,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        location: trimmedLocation,
        maxParticipants: normalizedMaxParticipants,
        level: level,
        groupType: groupType,
        visibility: effectiveVisibility,
        groupId: selectedGroupId,
        groupName: selectedGroupName,
      );

      await _sendInvitationsAfterCreate(
        activityId,
        selectedFriendsSnapshot,
      );

      if (!mounted) return;

      final int inviteCount = selectedFriendsSnapshot.length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isGroupActivity
                ? inviteCount > 0
                    ? 'Activité de groupe créée et invitations envoyées'
                    : 'Activité de groupe enregistrée'
                : inviteCount > 0
                    ? 'Activité créée et $inviteCount invitation(s) envoyée(s)'
                    : 'Activité enregistrée',
          ),
        ),
      );

      Navigator.pop(context, trimmedTitle);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l’enregistrement : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = generateTimeSlots();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadFriendsFromFriendships(),
      builder: (context, friendsSnapshot) {
        final friends = friendsSnapshot.data ?? [];
        final selectedFriends = friends
            .where(
              (friend) => selectedFriendIds.contains(
                (friend['id'] ?? '').toString(),
              ),
            )
            .toList();

        return StreamBuilder<List<GroupModel>>(
          stream: groupsRepository.watchMyGroups(),
          builder: (context, groupsSnapshot) {
            final groups = groupsSnapshot.data ?? [];

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  isGroupActivity
                      ? 'Créer une activité de groupe'
                      : 'Créer une activité',
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Jour sélectionné : ${_formatDisplayDate(selectedDate)}',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueGrey.shade100,
                        ),
                      ),
                      child: Text(
                        'Créneau prévu : ${_schedulePreview()}',
                        style: TextStyle(
                          color: Colors.blueGrey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: startTime,
                      items: timeSlots
                          .map(
                            (time) => DropdownMenuItem(
                              value: time,
                              child: Text(time),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() {
                                startTime = value;

                                final startMinutes = timeToMinutes(startTime);
                                final endMinutes = timeToMinutes(endTime);

                                if (endMinutes <= startMinutes) {
                                  endTime = getNextSlot(startTime);
                                }
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: 'Heure de début',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: endTime,
                      items: timeSlots
                          .map(
                            (time) => DropdownMenuItem(
                              value: time,
                              child: Text(time),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() {
                                final proposedEnd = value;
                                final startMinutes = timeToMinutes(startTime);
                                final endMinutes = timeToMinutes(proposedEnd);

                                endTime = endMinutes <= startMinutes
                                    ? getNextSlot(startTime)
                                    : proposedEnd;
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: 'Heure de fin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: titleController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: descriptionController,
                      enabled: !isSaving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: category,
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
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
                    const SizedBox(height: 15),
                    TextField(
                      controller: locationController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Lieu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: maxParticipantsController,
                      enabled: !isSaving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText:
                            'Nombre max participants (laisser vide = illimité)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: level,
                      items: levels
                          .map(
                            (l) => DropdownMenuItem(
                              value: l,
                              child: Text(l),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() {
                                level = value;
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: 'Niveau',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: groupType,
                      items: groupTypes
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text(g),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() {
                                groupType = value;
                              });
                            },
                      decoration: const InputDecoration(
                        labelText: 'Type de groupe',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isGroupActivity) ...[
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: groupActivityAccess,
                        items: groupActivityAccessOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option['value']!,
                                child: Text(option['label']!),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  groupActivityAccess = value;
                                });
                              },
                        decoration: const InputDecoration(
                          labelText: 'Accès à l’activité',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (!isGroupActivity) ...[
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: visibility,
                        items: visibilityOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option['value']!,
                                child: Text(option['label']!),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  visibility = value;
                                });
                              },
                        decoration: const InputDecoration(
                          labelText: 'Visibilité',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inviter des amis',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isSaving ||
                                        friendsSnapshot.connectionState ==
                                            ConnectionState.waiting
                                    ? null
                                    : () => _openFriendSelection(
                                          context,
                                          friends,
                                        ),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: Text(
                                  selectedFriendIds.isEmpty
                                      ? 'Choisir des amis'
                                      : '${selectedFriendIds.length} ami(s) sélectionné(s)',
                                ),
                              ),
                            ),
                            if (friendsSnapshot.connectionState ==
                                ConnectionState.waiting) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(),
                            ],
                            if (friendsSnapshot.connectionState !=
                                    ConnectionState.waiting &&
                                friends.isEmpty) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'Aucun ami disponible pour le moment.',
                              ),
                            ],
                            if (selectedFriends.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedFriends.map((friend) {
                                  final friendId =
                                      (friend['id'] ?? '').toString();

                                  return Chip(
                                    label: Text(_displayUserName(friend)),
                                    onDeleted: isSaving
                                        ? null
                                        : () {
                                            setState(() {
                                              selectedFriendIds.remove(friendId);
                                            });
                                          },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Associer un groupe',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isSaving ||
                                        groupsSnapshot.connectionState ==
                                            ConnectionState.waiting
                                    ? null
                                    : () => _openGroupSelection(
                                          context,
                                          groups,
                                        ),
                                icon: const Icon(Icons.groups),
                                label: Text(
                                  isGroupActivity
                                      ? 'Groupe sélectionné : ${selectedGroupName ?? 'Groupe'}'
                                      : 'Choisir un groupe',
                                ),
                              ),
                            ),
                            if (groupsSnapshot.connectionState ==
                                ConnectionState.waiting) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(),
                            ],
                            if (groupsSnapshot.connectionState !=
                                    ConnectionState.waiting &&
                                groups.isEmpty) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'Aucun groupe disponible pour le moment.',
                              ),
                            ],
                            if (isGroupActivity) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      selectedGroupName ?? 'Groupe',
                                    ),
                                    onDeleted: isSaving
                                        ? null
                                        : () {
                                            setState(() {
                                              selectedGroupId = null;
                                              selectedGroupName = null;
                                              groupActivityAccess = 'group_only';
                                              if (visibility ==
                                                  ActivityVisibilityValues.private) {
                                                visibility =
                                                    ActivityVisibilityValues.public;
                                              }
                                            });
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Text(_groupActivityInfoText()),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _createActivity,
                        child: isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                isGroupActivity
                                    ? 'Créer l’activité du groupe'
                                    : 'Créer l’activité',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}