import 'package:flutter/material.dart';
import 'package:agenda_app/services/firestore/search_firestore_service.dart';

class SearchDetailPage extends StatelessWidget {
  final String searchId;
  final String day;
  final String startTime;
  final String endTime;
  final String category;

  const SearchDetailPage({
    super.key,
    required this.searchId,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.category,
  });

  Future<void> _confirmDeleteSearch(
    BuildContext context,
    SearchFirestoreService searchService,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer la recherche'),
          content: const Text(
            'Voulez-vous vraiment supprimer cette recherche ?',
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

    await searchService.deleteSearch(searchId);

    if (!context.mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recherche supprimée'),
      ),
    );
  }

  String _resolvedCategoryLabel(String value) {
    final trimmedCategory = value.trim();
    return trimmedCategory.isEmpty ? 'Toutes' : trimmedCategory;
  }

  String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTimeOnly(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _resolvedDayLabel(Map<String, dynamic> search) {
    final startDateTime = search['startDateTime'] as DateTime?;
    if (startDateTime != null) {
      return _formatDateOnly(startDateTime);
    }

    final rawDay = (search['day'] ?? '').toString().trim();
    return rawDay.isEmpty ? day.trim() : rawDay;
  }

  String _resolvedStartTimeLabel(Map<String, dynamic> search) {
    final startDateTime = search['startDateTime'] as DateTime?;
    if (startDateTime != null) {
      return _formatTimeOnly(startDateTime);
    }

    final rawStartTime = (search['startTime'] ?? '').toString().trim();
    return rawStartTime.isEmpty ? startTime.trim() : rawStartTime;
  }

  String _resolvedEndTimeLabel(Map<String, dynamic> search) {
    final endDateTime = search['endDateTime'] as DateTime?;
    if (endDateTime != null) {
      return _formatTimeOnly(endDateTime);
    }

    final rawEndTime = (search['endTime'] ?? '').toString().trim();
    return rawEndTime.isEmpty ? endTime.trim() : rawEndTime;
  }

  String _resolvedScheduleLabel(Map<String, dynamic> search) {
    final resolvedDay = _resolvedDayLabel(search);
    final resolvedStart = _resolvedStartTimeLabel(search);
    final resolvedEnd = _resolvedEndTimeLabel(search);

    if (resolvedDay.isNotEmpty &&
        resolvedStart.isNotEmpty &&
        resolvedEnd.isNotEmpty) {
      return '$resolvedDay • $resolvedStart - $resolvedEnd';
    }

    if (resolvedDay.isNotEmpty) {
      return resolvedDay;
    }

    return 'Créneau non renseigné';
  }

  @override
  Widget build(BuildContext context) {
    final searchService = SearchFirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail recherche'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: searchService.watchSearch(searchId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur recherche : ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final search = snapshot.data;

          if (search == null) {
            return const Center(
              child: Text('Recherche introuvable'),
            );
          }

          final resolvedCategory =
              (search['category'] ?? '').toString().trim().isNotEmpty
                  ? (search['category'] ?? '').toString()
                  : category;

          final scheduleLabel = _resolvedScheduleLabel(search);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recherche d’activité',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Créneau : $scheduleLabel'),
                        const SizedBox(height: 8),
                        Text(
                          'Catégorie : ${_resolvedCategoryLabel(resolvedCategory)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        _confirmDeleteSearch(context, searchService),
                    child: const Text('Supprimer la recherche'),
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