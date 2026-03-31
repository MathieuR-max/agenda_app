import 'package:flutter/material.dart';
import '../../models/availability.dart';
import '../../services/firestore/availability_firestore_service.dart';

class AvailabilityDetailPage extends StatelessWidget {
  final Availability availability;

  const AvailabilityDetailPage({
    super.key,
    required this.availability,
  });

  @override
  Widget build(BuildContext context) {
    final availabilityService = AvailabilityFirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail disponibilité'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              availability.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('Type : ${availability.type}'),
            Text(
              'Horaire : ${availability.day} ${availability.startTime} - ${availability.endTime}',
            ),
            Text('Visibilité : ${availability.visibility}'),
            const SizedBox(height: 12),
            if (availability.note.isNotEmpty) Text('Note : ${availability.note}'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await availabilityService.deleteAvailability(availability.id);

                if (!context.mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Disponibilité supprimée'),
                  ),
                );
              },
              child: const Text('Supprimer la disponibilité'),
            ),
          ],
        ),
      ),
    );
  }
}