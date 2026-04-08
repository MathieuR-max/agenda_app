import 'package:flutter/material.dart';
import 'package:agenda_app/core/constants/availability_constants.dart';
import '../../models/availability.dart';
import '../../services/firestore/availability_firestore_service.dart';

class EditAvailabilityPage extends StatefulWidget {
  final Availability availability;

  const EditAvailabilityPage({
    super.key,
    required this.availability,
  });

  @override
  State<EditAvailabilityPage> createState() => _EditAvailabilityPageState();
}

class _EditAvailabilityPageState extends State<EditAvailabilityPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  final AvailabilityFirestoreService availabilityService =
      AvailabilityFirestoreService();

  late DateTime selectedDate;
  late String selectedType;
  late String selectedVisibility;
  late String selectedStartTime;
  late String selectedEndTime;

  bool isSaving = false;

  final List<String> types = AvailabilityTypes.all;

  final List<String> visibilities = const [
    'public',
    'private',
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

  String visibilityLabel(String visibility) {
    switch (visibility.trim()) {
      case 'public':
        return 'Publique';
      case 'private':
      default:
        return 'Privée';
    }
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

    if (visibilities.contains(normalized)) {
      return normalized;
    }

    return 'private';
  }

  String _resolveTimeValue({
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

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _resolveInitialDate() {
    final resolvedStart = widget.availability.resolvedStartDateTime;
    if (resolvedStart != null) {
      return _normalizeDate(resolvedStart);
    }

    final parsedLegacy = _tryParseLegacyDay(widget.availability.day);
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

  String _schedulePreview() {
    return '${_formatDisplayDate(selectedDate)} • $selectedStartTime - $selectedEndTime';
  }

  Future<void> _pickSelectedDate() async {
    if (isSaving) return;

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

    final timeSlots = generateTimeSlots();

    titleController.text = widget.availability.title;
    noteController.text = widget.availability.note;

    selectedDate = _resolveInitialDate();

    selectedType = _resolveDropdownValue(
      currentValue: widget.availability.type,
      allowedValues: types,
      fallback: AvailabilityTypes.personal,
    );

    selectedVisibility = _resolveVisibilityValue(widget.availability.visibility);

    selectedStartTime = _resolveTimeValue(
      currentValue: widget.availability.effectiveStartTime,
      allowedValues: timeSlots,
      fallback: '18:00',
    );

    selectedEndTime = _resolveTimeValue(
      currentValue: widget.availability.effectiveEndTime,
      allowedValues: timeSlots,
      fallback: '18:30',
    );

    final startMinutes = timeToMinutes(selectedStartTime);
    final endMinutes = timeToMinutes(selectedEndTime);

    if (endMinutes <= startMinutes) {
      final startIndex = timeSlots.indexOf(selectedStartTime);
      if (startIndex != -1 && startIndex < timeSlots.length - 1) {
        selectedEndTime = timeSlots[startIndex + 1];
      } else {
        selectedEndTime = selectedStartTime;
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _saveAvailability() async {
    if (isSaving) return;

    final trimmedTitle = titleController.text.trim();
    final trimmedNote = noteController.text.trim();

    if (trimmedTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le titre est obligatoire'),
        ),
      );
      return;
    }

    final startMinutes = timeToMinutes(selectedStartTime);
    final endMinutes = timeToMinutes(selectedEndTime);

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

    final startDateTime =
        _combineDateAndTime(selectedDate, selectedStartTime);
    final endDateTime =
        _combineDateAndTime(selectedDate, selectedEndTime);

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

    setState(() {
      isSaving = true;
    });

    try {
      await availabilityService.updateAvailability(
        availabilityId: widget.availability.id,
        title: trimmedTitle,
        type: selectedType,
        note: trimmedNote,
        visibility: selectedVisibility,
        day: _formatDateOnly(selectedDate),
        startTime: selectedStartTime,
        endTime: selectedEndTime,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la modification : $e'),
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
        title: const Text('Modifier la disponibilité'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              enabled: !isSaving,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: types
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(AvailabilityTypes.label(type)),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        selectedType = value;
                      });
                    },
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            InkWell(
              onTap: isSaving ? null : _pickSelectedDate,
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
                    if (!isSaving) const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedStartTime,
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
                        selectedStartTime = value;

                        final startMinutes = timeToMinutes(selectedStartTime);
                        final endMinutes = timeToMinutes(selectedEndTime);

                        if (endMinutes <= startMinutes) {
                          final startIndex =
                              timeSlots.indexOf(selectedStartTime);
                          if (startIndex != -1 &&
                              startIndex < timeSlots.length - 1) {
                            selectedEndTime = timeSlots[startIndex + 1];
                          }
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
              value: selectedEndTime,
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
                        final startMinutes = timeToMinutes(selectedStartTime);
                        final endMinutes = timeToMinutes(proposedEnd);

                        if (endMinutes <= startMinutes) {
                          final startIndex =
                              timeSlots.indexOf(selectedStartTime);
                          if (startIndex != -1 &&
                              startIndex < timeSlots.length - 1) {
                            selectedEndTime = timeSlots[startIndex + 1];
                          } else {
                            selectedEndTime = selectedStartTime;
                          }
                        } else {
                          selectedEndTime = proposedEnd;
                        }
                      });
                    },
              decoration: const InputDecoration(
                labelText: 'Heure de fin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedVisibility,
              items: visibilities
                  .map(
                    (visibility) => DropdownMenuItem(
                      value: visibility,
                      child: Text(visibilityLabel(visibility)),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        selectedVisibility = value;
                      });
                    },
              decoration: const InputDecoration(
                labelText: 'Visibilité',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: noteController,
              enabled: !isSaving,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveAvailability,
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