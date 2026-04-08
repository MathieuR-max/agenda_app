import 'package:flutter/material.dart';
import 'package:agenda_app/services/firestore/datetime_migration_service.dart';

class DateTimeMigrationPage extends StatefulWidget {
  const DateTimeMigrationPage({super.key});

  @override
  State<DateTimeMigrationPage> createState() => _DateTimeMigrationPageState();
}

class _DateTimeMigrationPageState extends State<DateTimeMigrationPage> {
  final DateTimeMigrationService migrationService = DateTimeMigrationService();

  bool isRunning = false;
  String resultText = 'Aucune migration lancée';

  Future<void> _runMigration({required bool dryRun}) async {
    if (isRunning) return;

    setState(() {
      isRunning = true;
      resultText = dryRun
          ? 'Analyse en cours...'
          : 'Migration en cours...';
    });

    try {
      final report = await migrationService.migrateAll(
        dryRun: dryRun,
      );

      setState(() {
        resultText = report.toString();
      });
    } catch (e) {
      setState(() {
        resultText = 'Erreur : $e';
      });
    } finally {
      setState(() {
        isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration DateTime'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isRunning
                    ? null
                    : () => _runMigration(dryRun: true),
                child: const Text('Dry run'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isRunning
                    ? null
                    : () => _runMigration(dryRun: false),
                child: const Text('Lancer la migration'),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(resultText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}