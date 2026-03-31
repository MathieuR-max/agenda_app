import 'package:flutter/material.dart';
import 'package:agenda_app/repositories/activity_repository.dart';

class CreateActivityPage extends StatefulWidget {
  final String day;
  final String hour;

  const CreateActivityPage({
    super.key,
    required this.day,
    required this.hour,
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

  String category = 'Sport';
  String level = 'Tous niveaux';
  String groupType = 'Ouvert à tous';

  late String startTime;
  late String endTime;

  bool isSaving = false;

  final List<String> categories = [
    'Sport',
    'Sortie',
    'Culture',
    'Jeux',
    'Études',
    'Travail',
    'Détente',
    'Autre',
  ];

  final List<String> levels = [
    'Débutant',
    'Intermédiaire',
    'Confirmé',
    'Tous niveaux',
  ];

  final List<String> groupTypes = [
    'Ouvert à tous',
    'Femmes uniquement',
    'Hommes uniquement',
    'Non mixte',
    'Privé',
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

  @override
  void initState() {
    super.initState();
    startTime = widget.hour;
    endTime = getNextSlot(widget.hour);
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

    if (titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty) {
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
    if (maxParticipantsText.isNotEmpty &&
        int.tryParse(maxParticipantsText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le nombre max de participants doit être un nombre valide',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await activityRepository.createActivity(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        category: category,
        day: widget.day,
        startTime: startTime,
        endTime: endTime,
        location: locationController.text.trim(),
        maxParticipants: maxParticipantsText,
        level: level,
        groupType: groupType,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activité enregistrée')),
      );

      Navigator.pop(context);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une activité'),
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
              decoration: const InputDecoration(
                labelText: 'Nombre max participants',
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
                    : const Text('Créer l’activité'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}