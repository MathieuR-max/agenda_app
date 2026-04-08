import 'package:flutter/material.dart';
import 'package:agenda_app/core/constants/availability_constants.dart';
import '../../models/availability.dart';
import '../../services/firestore/availability_firestore_service.dart';
import 'edit_availability_page.dart';

class AvailabilityDetailPage extends StatelessWidget {
  final Availability availability;

  const AvailabilityDetailPage({
    super.key,
    required this.availability,
  });

  Future<void> _openEditPage(
    BuildContext context,
    Availability currentAvailability,
  ) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditAvailabilityPage(
          availability: currentAvailability,
        ),
      ),
    );

    if (!context.mounted) return;

    if (updated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disponibilité modifiée'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteAvailability(
    BuildContext context,
    AvailabilityFirestoreService availabilityService,
    String availabilityId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer la disponibilité'),
          content: const Text(
            'Voulez-vous vraiment supprimer cette disponibilité ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await availabilityService.deleteAvailability(availabilityId);

    if (!context.mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disponibilité supprimée'),
      ),
    );
  }

  String _formatSchedule(Availability availability) {
    final scheduleLabel = availability.scheduleLabel.trim();

    if (scheduleLabel.isNotEmpty) {
      return scheduleLabel;
    }

    return '${availability.effectiveDay} '
        '${availability.effectiveStartTime} - ${availability.effectiveEndTime}';
  }

  @override
  Widget build(BuildContext context) {
    final availabilityService = AvailabilityFirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail disponibilité'),
      ),
      body: StreamBuilder<Availability?>(
        stream: availabilityService.watchAvailability(availability.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur disponibilité : ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final currentAvailability = snapshot.data;

          if (currentAvailability == null) {
            return const Center(
              child: Text('Disponibilité introuvable'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentAvailability.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Type : ${currentAvailability.typeLabel}',
                ),
                Text(
                  'Horaire : ${_formatSchedule(currentAvailability)}',
                ),
                Text('Visibilité : ${currentAvailability.visibilityLabel}'),
                if (currentAvailability.hasNote) ...[
                  const SizedBox(height: 12),
                  Text('Note : ${currentAvailability.note}'),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _openEditPage(
                      context,
                      currentAvailability,
                    ),
                    child: const Text('Modifier la disponibilité'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _confirmDeleteAvailability(
                      context,
                      availabilityService,
                      currentAvailability.id,
                    ),
                    child: const Text('Supprimer la disponibilité'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}