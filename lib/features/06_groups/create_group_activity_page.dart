import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/repositories/activity_repository.dart';

class CreateGroupActivityPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const CreateGroupActivityPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<CreateGroupActivityPage> createState() => _CreateGroupActivityPageState();
}

class _CreateGroupActivityPageState extends State<CreateGroupActivityPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController maxParticipantsController =
      TextEditingController();

  final ActivityRepository activityRepository = ActivityRepository();

  String selectedDay = 'Lundi';
  String category = 'Sport';
  String level = 'Tous niveaux';
  String groupType = 'Privé';
  String groupActivityAccess = 'group_only';

  late String startTime;
  late String endTime;

  bool isSaving = false;

  final List<String> days = const [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

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
    'Privé',
    'Ouvert à tous',
    'Femmes uniquement',
    'Hommes uniquement',
    'Non mixte',
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
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
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
    final today = _normalizeDate(DateTime.now());
    final targetWeekday = _weekdayFromFrenchDay(selectedDay);
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

  String _groupActivityInfoText() {
    final displayedGroupName = widget.groupName.trim();

    if (groupActivityAccess == 'group_and_public') {
      return displayedGroupName.isNotEmpty
          ? 'Activité liée au groupe "$displayedGroupName" et ouverte à de nouveaux participants.'
          : 'Activité liée à un groupe et ouverte à de nouveaux participants.';
    }

    return displayedGroupName.isNotEmpty
        ? 'Activité réservée uniquement aux membres du groupe "$displayedGroupName".'
        : 'Activité réservée uniquement aux membres du groupe.';
  }

  String _accessHelperText() {
    if (groupActivityAccess == 'group_and_public') {
      return 'Les membres du groupe et de nouveaux participants pourront rejoindre cette activité.';
    }

    return 'Seuls les membres du groupe pourront rejoindre cette activité.';
  }

  @override
  void initState() {
    super.initState();
    startTime = '18:00';
    endTime = getNextSlot(startTime);
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

    final baseDate = _resolveSelectedDate();
    final startDateTime = _combineDateAndTime(baseDate, startTime);
    final endDateTime = _combineDateAndTime(baseDate, endTime);

    final effectiveVisibility =
        groupActivityAccess == 'group_and_public'
            ? ActivityVisibilityValues.public
            : ActivityVisibilityValues.private;

    setState(() {
      isSaving = true;
    });

    try {
      await activityRepository.createActivity(
        title: trimmedTitle,
        description: trimmedDescription,
        category: category,
        day: selectedDay,
        startTime: startTime,
        endTime: endTime,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        location: trimmedLocation,
        maxParticipants: normalizedMaxParticipants,
        level: level,
        groupType: groupType,
        visibility: effectiveVisibility,
        groupId: widget.groupId,
        groupName: widget.groupName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activité de groupe enregistrée'),
        ),
      );

      Navigator.pop(context, trimmedTitle);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l’enregistrement : $e'),
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une activité de groupe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.groups),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_groupActivityInfoText()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedDay,
              items: days
                  .map(
                    (day) => DropdownMenuItem(
                      value: day,
                      child: Text(day),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        selectedDay = value;
                      });
                    },
              decoration: const InputDecoration(
                labelText: 'Jour',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: startTime,
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
              initialValue: endTime,
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
                        endTime = value;
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
              initialValue: category,
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
                labelText: 'Nombre max participants (laisser vide = illimité)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: level,
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
              initialValue: groupType,
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
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: groupActivityAccess,
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _accessHelperText(),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
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
                    : const Text('Créer l’activité du groupe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}