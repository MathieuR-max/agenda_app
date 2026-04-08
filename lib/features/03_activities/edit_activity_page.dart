import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/repositories/activity_repository.dart';

class EditActivityPage extends StatefulWidget {
  final Activity activity;
  final int participantCount;

  const EditActivityPage({
    super.key,
    required this.activity,
    required this.participantCount,
  });

  @override
  State<EditActivityPage> createState() => _EditActivityPageState();
}

class _EditActivityPageState extends State<EditActivityPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController maxParticipantsController =
      TextEditingController();

  final ActivityRepository activityRepository = ActivityRepository();

  late DateTime selectedDate;
  late String startTime;
  late String endTime;
  late String category;
  late String level;
  late String groupType;
  late String visibility;

  bool isSaving = false;

  bool get canFullyEdit => widget.participantCount <= 1;
  bool get canPartiallyEdit => widget.participantCount > 1;

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

  String _pageTitle() {
    return canFullyEdit ? 'Modifier l’activité' : 'Modification limitée';
  }

  String _helperText() {
    if (canFullyEdit) {
      return 'Vous êtes seul sur cette activité. Tous les champs peuvent être modifiés.';
    }

    return 'Des participants ont déjà rejoint cette activité. Seuls la description et le lieu peuvent être modifiés.';
  }

  String _resolveDropdownValue({
    required String? currentValue,
    required List<String> allowedValues,
    required String fallback,
  }) {
    final normalized = (currentValue ?? '').trim();

    if (allowedValues.contains(normalized)) {
      return normalized;
    }

    return fallback;
  }

  String _resolveVisibilityValue(String? currentValue) {
    final normalized = (currentValue ?? '').trim();

    final allowedValues =
        visibilityOptions.map((option) => option['value']!).toList();

    if (allowedValues.contains(normalized)) {
      return normalized;
    }

    return ActivityVisibilityValues.public;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _resolveInitialDate() {
    final resolvedStart = widget.activity.resolvedStartDateTime;
    if (resolvedStart != null) {
      return _normalizeDate(resolvedStart);
    }

    final parsedLegacy = _tryParseLegacyDay(widget.activity.day);
    if (parsedLegacy != null) {
      return _normalizeDate(parsedLegacy);
    }

    return _normalizeDate(DateTime.now());
  }

  DateTime? _tryParseLegacyDay(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    try {
      return DateTime.parse(trimmed);
    } catch (_) {
      return null;
    }
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

  String _buildSchedulePreview() {
    return '${_formatDisplayDate(selectedDate)} • $startTime - $endTime';
  }

  Future<void> _pickSelectedDate() async {
    if (!canFullyEdit || isSaving) return;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = _normalizeDate(pickedDate);
    });
  }

  @override
  void initState() {
    super.initState();

    selectedDate = _resolveInitialDate();

    final resolvedStart = widget.activity.resolvedStartDateTime;
    final resolvedEnd = widget.activity.resolvedEndDateTime;

    startTime = resolvedStart != null
        ? widget.activity.effectiveStartTime
        : (widget.activity.startTime.trim().isNotEmpty
            ? widget.activity.startTime.trim()
            : '18:00');

    endTime = resolvedEnd != null
        ? widget.activity.effectiveEndTime
        : (widget.activity.endTime.trim().isNotEmpty
            ? widget.activity.endTime.trim()
            : getNextSlot(startTime));

    category = _resolveDropdownValue(
      currentValue: widget.activity.category,
      allowedValues: categories,
      fallback: categories.first,
    );

    level = _resolveDropdownValue(
      currentValue: widget.activity.level,
      allowedValues: levels,
      fallback: 'Tous niveaux',
    );

    groupType = _resolveDropdownValue(
      currentValue: widget.activity.groupType,
      allowedValues: groupTypes,
      fallback: widget.activity.isGroupActivity ? 'Privé' : 'Ouvert à tous',
    );

    visibility = _resolveVisibilityValue(widget.activity.visibility);

    titleController.text = widget.activity.title;
    descriptionController.text = widget.activity.description;
    locationController.text = widget.activity.location;
    maxParticipantsController.text = widget.activity.hasUnlimitedPlaces
        ? ''
        : widget.activity.maxParticipants.toString();

    if (endTime.trim().isEmpty) {
      endTime = getNextSlot(startTime);
    }

    if (timeToMinutes(endTime) <= timeToMinutes(startTime)) {
      endTime = getNextSlot(startTime);
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

  Future<void> _saveActivity() async {
    if (isSaving) return;

    final trimmedTitle = titleController.text.trim();
    final trimmedDescription = descriptionController.text.trim();
    final trimmedLocation = locationController.text.trim();

    if (trimmedDescription.isEmpty || trimmedLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de remplir les champs obligatoires'),
        ),
      );
      return;
    }

    if (canFullyEdit && trimmedTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le titre est obligatoire'),
        ),
      );
      return;
    }

    DateTime? startDateTime;
    DateTime? endDateTime;

    if (canFullyEdit) {
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

      startDateTime = _combineDateAndTime(selectedDate, startTime);
      endDateTime = _combineDateAndTime(selectedDate, endTime);

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
    }

    setState(() {
      isSaving = true;
    });

    try {
      if (canFullyEdit) {
        final normalizedMaxParticipants =
            maxParticipantsController.text.trim().isEmpty
                ? '0'
                : maxParticipantsController.text.trim();

        await activityRepository.updateActivity(
          activityId: widget.activity.id,
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
          visibility: visibility,
          isLimitedEdit: false,
        );
      } else {
        await activityRepository.updateActivity(
          activityId: widget.activity.id,
          description: trimmedDescription,
          location: trimmedLocation,
          isLimitedEdit: true,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour : $e'),
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
        title: Text(_pageTitle()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: canFullyEdit
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canFullyEdit
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Text(
                _helperText(),
                style: TextStyle(
                  color: canFullyEdit
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (canFullyEdit) ...[
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
                  'Créneau prévu : ${_buildSchedulePreview()}',
                  style: TextStyle(
                    color: Colors.blueGrey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            InkWell(
              onTap: !canFullyEdit || isSaving ? null : _pickSelectedDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDisplayDate(selectedDate)),
                    if (canFullyEdit && !isSaving)
                      const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
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
              onChanged: !canFullyEdit || isSaving
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
              onChanged: !canFullyEdit || isSaving
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
              enabled: canFullyEdit && !isSaving,
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
              onChanged: !canFullyEdit || isSaving
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
              enabled: canFullyEdit && !isSaving,
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
              value: level,
              items: levels
                  .map(
                    (l) => DropdownMenuItem(
                      value: l,
                      child: Text(l),
                    ),
                  )
                  .toList(),
              onChanged: !canFullyEdit || isSaving
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
              onChanged: !canFullyEdit || isSaving
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
              value: visibility,
              items: visibilityOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option['value']!,
                      child: Text(option['label']!),
                    ),
                  )
                  .toList(),
              onChanged: !canFullyEdit || isSaving
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
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveActivity,
                child: isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer les modifications'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}