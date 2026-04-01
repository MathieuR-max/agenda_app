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

  @override
  Widget build(BuildContext context) {
    final searchService = SearchFirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail recherche'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recherche d’activité',
              style: const TextStyle(
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
                    Text('Jour : $day'),
                    const SizedBox(height: 8),
                    Text('Heure : $startTime - $endTime'),
                    const SizedBox(height: 8),
                    Text(
                      'Catégorie : ${category.trim().isEmpty ? 'Toutes' : category}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmDeleteSearch(context, searchService),
                child: const Text('Supprimer la recherche'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}