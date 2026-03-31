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
            const SizedBox(height: 12),
            Text('Jour : $day'),
            Text('Heure : $startTime - $endTime'),
            Text('Catégorie : $category'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await searchService.deleteSearch(searchId);

                if (!context.mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recherche supprimée'),
                  ),
                );
              },
              child: const Text('Supprimer la recherche'),
            ),
          ],
        ),
      ),
    );
  }
}