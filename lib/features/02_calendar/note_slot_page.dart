import 'package:flutter/material.dart';
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
  String type = 'Disponible';
  String visibility = 'Privé';

  late String startTime;
  late String endTime;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  final AvailabilityFirestoreService availabilityService =
      AvailabilityFirestoreService();

  final List<String> types = [
    'Disponible',
    'Indisponible',
    'Activité personnelle',
    'Peut-être disponible',
  ];

  final List<String> visibilities = [
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

  @override
  void initState() {
    super.initState();
    startTime = widget.hour;
    endTime = getNextSlot(widget.hour);
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _saveSlot() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de renseigner un titre'),
        ),
      );
      return;
    }

    if (startTime == endTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’heure de fin doit être différente de l’heure de début',
          ),
        ),
      );
      return;
    }

    try {
      await availabilityService.saveAvailability(
        type: type,
        title: titleController.text.trim(),
        note: noteController.text.trim(),
        visibility: visibility,
        day: widget.day,
        startTime: startTime,
        endTime: endTime,
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
            Text('Jour sélectionné : ${widget.day}'),
            const SizedBox(height: 20),
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
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: types
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t),
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
              initialValue: visibility,
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
            ElevatedButton(
              onPressed: _saveSlot,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}