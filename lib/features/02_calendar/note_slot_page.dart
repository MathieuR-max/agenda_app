import 'package:flutter/material.dart';
import 'package:agenda_app/core/constants/availability_constants.dart';
import 'package:agenda_app/services/firestore/availability_firestore_service.dart';

class NoteSlotPage extends StatefulWidget {
  final String day;
  final String hour;

  const NoteSlotPage({
    super.key,
    required this.day,
    required this.hour,
  });

  @override
  State<NoteSlotPage> createState() => _NoteSlotPageState();
}

class _NoteSlotPageState extends State<NoteSlotPage> {
  String type = AvailabilityTypes.available;
  String visibility = 'Privé';

  late String startTime;
  late String endTime;
  late DateTime selectedDate;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  final AvailabilityFirestoreService availabilityService =
      AvailabilityFirestoreService();

  final List<String> types = AvailabilityTypes.all;

  final List<String> visibilities = const [
    'Privé',
    'Visible pour matching',
  ];

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

  String _formatDisplayDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  String _resolvedFirestoreVisibility() {
    return visibility == 'Visible pour matching' ? 'public' : 'private';
  }

  String _schedulePreview() {
    return '${_formatDisplayDate(selectedDate)} • $startTime - $endTime';
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
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _saveSlot() async {
    final trimmedTitle = titleController.text.trim();
    final trimmedNote = noteController.text.trim();

    if (trimmedTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de renseigner un titre'),
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

    try {
      await availabilityService.saveAvailability(
        type: type,
        title: trimmedTitle,
        note: trimmedNote,
        visibility: _resolvedFirestoreVisibility(),
        day: _formatDateOnly(selectedDate),
        startTime: startTime,
        endTime: endTime,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Créneau enregistré')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l’enregistrement : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = generateTimeSlots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Noter un créneau'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Jour sélectionné : ${_formatDisplayDate(selectedDate)}'),
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
              onChanged: (value) {
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
              onChanged: (value) {
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
            DropdownButtonFormField<String>(
              value: type,
              items: types
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(AvailabilityTypes.label(t)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  type = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: visibility,
              items: visibilities
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
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
                onPressed: _saveSlot,
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}