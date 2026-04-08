import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';

class DateTimeMigrationService {
  final FirebaseFirestore _db;

  DateTimeMigrationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<MigrationReport> migrateAll({
    bool migrateActivities = true,
    bool migrateAvailabilities = true,
    bool dryRun = false,
  }) async {
    int activitiesUpdated = 0;
    int activitiesSkipped = 0;
    int activitiesFailed = 0;

    int availabilitiesUpdated = 0;
    int availabilitiesSkipped = 0;
    int availabilitiesFailed = 0;

    if (migrateActivities) {
      final result = await _migrateCollection(
        collectionName: FirestoreCollections.activities,
        dryRun: dryRun,
      );
      activitiesUpdated = result.updated;
      activitiesSkipped = result.skipped;
      activitiesFailed = result.failed;
    }

    if (migrateAvailabilities) {
      final result = await _migrateCollection(
        collectionName: FirestoreCollections.availabilities,
        dryRun: dryRun,
      );
      availabilitiesUpdated = result.updated;
      availabilitiesSkipped = result.skipped;
      availabilitiesFailed = result.failed;
    }

    return MigrationReport(
      activitiesUpdated: activitiesUpdated,
      activitiesSkipped: activitiesSkipped,
      activitiesFailed: activitiesFailed,
      availabilitiesUpdated: availabilitiesUpdated,
      availabilitiesSkipped: availabilitiesSkipped,
      availabilitiesFailed: availabilitiesFailed,
    );
  }

  Future<_CollectionMigrationResult> _migrateCollection({
    required String collectionName,
    required bool dryRun,
  }) async {
    final snapshot = await _db.collection(collectionName).get();

    int updated = 0;
    int skipped = 0;
    int failed = 0;

    WriteBatch batch = _db.batch();
    int batchCount = 0;

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();

        final bool alreadyHasStart = data['startDateTime'] != null;
        final bool alreadyHasEnd = data['endDateTime'] != null;

        if (alreadyHasStart && alreadyHasEnd) {
          skipped++;
          continue;
        }

        final String day = (data['day'] ?? '').toString().trim();
        final String startTime = (data['startTime'] ?? '').toString().trim();
        final String endTime = (data['endTime'] ?? '').toString().trim();

        if (day.isEmpty || startTime.isEmpty || endTime.isEmpty) {
          failed++;
          continue;
        }

        final DateTime? startDateTime = _combineLegacyDateAndTime(day, startTime);
        final DateTime? endDateTime = _combineLegacyDateAndTime(day, endTime);

        if (startDateTime == null || endDateTime == null) {
          failed++;
          continue;
        }

        if (!endDateTime.isAfter(startDateTime)) {
          failed++;
          continue;
        }

        final updateData = <String, dynamic>{
          'startDateTime': Timestamp.fromDate(startDateTime),
          'endDateTime': Timestamp.fromDate(endDateTime),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!dryRun) {
          batch.update(doc.reference, updateData);
          batchCount++;

          if (batchCount >= 400) {
            await batch.commit();
            batch = _db.batch();
            batchCount = 0;
          }
        }

        updated++;
      } catch (_) {
        failed++;
      }
    }

    if (!dryRun && batchCount > 0) {
      await batch.commit();
    }

    return _CollectionMigrationResult(
      updated: updated,
      skipped: skipped,
      failed: failed,
    );
  }

  DateTime? _combineLegacyDateAndTime(String day, String time) {
    try {
      final date = DateTime.parse(day);
      final parts = time.split(':');
      if (parts.length < 2) return null;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      return DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
    } catch (_) {
      return null;
    }
  }
}

class MigrationReport {
  final int activitiesUpdated;
  final int activitiesSkipped;
  final int activitiesFailed;
  final int availabilitiesUpdated;
  final int availabilitiesSkipped;
  final int availabilitiesFailed;

  MigrationReport({
    required this.activitiesUpdated,
    required this.activitiesSkipped,
    required this.activitiesFailed,
    required this.availabilitiesUpdated,
    required this.availabilitiesSkipped,
    required this.availabilitiesFailed,
  });

  int get totalUpdated => activitiesUpdated + availabilitiesUpdated;
  int get totalSkipped => activitiesSkipped + availabilitiesSkipped;
  int get totalFailed => activitiesFailed + availabilitiesFailed;

  @override
  String toString() {
    return '''
MigrationReport(
  activitiesUpdated: $activitiesUpdated,
  activitiesSkipped: $activitiesSkipped,
  activitiesFailed: $activitiesFailed,
  availabilitiesUpdated: $availabilitiesUpdated,
  availabilitiesSkipped: $availabilitiesSkipped,
  availabilitiesFailed: $availabilitiesFailed,
  totalUpdated: $totalUpdated,
  totalSkipped: $totalSkipped,
  totalFailed: $totalFailed,
)
''';
  }
}

class _CollectionMigrationResult {
  final int updated;
  final int skipped;
  final int failed;

  _CollectionMigrationResult({
    required this.updated,
    required this.skipped,
    required this.failed,
  });
}