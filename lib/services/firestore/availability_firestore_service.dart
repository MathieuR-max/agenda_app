import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/models/availability.dart';
import 'package:agenda_app/services/current_user.dart';

class AvailabilityFirestoreService {
  final FirebaseFirestore _db;

  AvailabilityFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  CollectionReference<Map<String, dynamic>> get _availabilities =>
      _db.collection(FirestoreCollections.availabilities);

  Future<void> saveAvailability({
    required String type,
    required String title,
    required String note,
    required String visibility,

    /// Legacy compatibility input.
    String? day,
    String? startTime,
    String? endTime,

    /// New source of truth.
    required DateTime startDateTime,
    required DateTime endDateTime,

    bool includeLegacyFields = true,
  }) async {
    _validateSchedule(startDateTime, endDateTime);

    final payload = _buildAvailabilityPayload(
      type: type,
      title: title,
      note: note,
      visibility: visibility,
      day: day,
      startTime: startTime,
      endTime: endTime,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      includeLegacyFields: includeLegacyFields,
      includeUserId: true,
      includeCreatedAt: true,
      includeUpdatedAt: true,
    );

    await _availabilities.add(payload);
  }

  Future<void> updateAvailability({
    required String availabilityId,
    required String type,
    required String title,
    required String note,
    required String visibility,

    /// Legacy compatibility input.
    String? day,
    String? startTime,
    String? endTime,

    /// New source of truth.
    required DateTime startDateTime,
    required DateTime endDateTime,

    bool includeLegacyFields = true,
  }) async {
    final trimmedAvailabilityId = availabilityId.trim();

    if (trimmedAvailabilityId.isEmpty) {
      throw Exception('Identifiant de disponibilité invalide.');
    }

    _validateSchedule(startDateTime, endDateTime);

    final payload = _buildAvailabilityPayload(
      type: type,
      title: title,
      note: note,
      visibility: visibility,
      day: day,
      startTime: startTime,
      endTime: endTime,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      includeLegacyFields: includeLegacyFields,
      includeUserId: false,
      includeCreatedAt: false,
      includeUpdatedAt: true,
    );

    await _availabilities.doc(trimmedAvailabilityId).update(payload);
  }

  Future<void> updateAvailabilitySchedule({
    required String availabilityId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    bool includeLegacyFields = true,
  }) async {
    final trimmedAvailabilityId = availabilityId.trim();

    if (trimmedAvailabilityId.isEmpty) {
      throw Exception('Identifiant de disponibilité invalide.');
    }

    _validateSchedule(startDateTime, endDateTime);

    final payload = <String, dynamic>{
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (includeLegacyFields) {
      payload.addAll({
        'day': _formatDateOnly(startDateTime),
        'startTime': _formatTimeOnly(startDateTime),
        'endTime': _formatTimeOnly(endDateTime),
      });
    }

    await _availabilities.doc(trimmedAvailabilityId).update(payload);
  }

  Stream<List<Availability>> getAvailabilities() {
    return _availabilities
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Availability.fromFirestore(doc.data(), doc.id))
          .toList();

      _sortAvailabilities(items);
      return items;
    });
  }

  Stream<List<Availability>> getAvailabilitiesForRange({
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) {
      return Stream.value(<Availability>[]);
    }

    return _availabilities
        .where('userId', isEqualTo: currentUserId)
        .where(
          'startDateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'startDateTime',
          isLessThan: Timestamp.fromDate(end),
        )
        .orderBy('startDateTime')
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Availability.fromFirestore(doc.data(), doc.id))
          .toList();

      _sortAvailabilities(items);
      return items;
    });
  }

  Future<Availability?> getAvailabilityById(String availabilityId) async {
    final trimmedAvailabilityId = availabilityId.trim();

    if (trimmedAvailabilityId.isEmpty) {
      return null;
    }

    final doc = await _availabilities.doc(trimmedAvailabilityId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Availability.fromFirestore(doc.data()!, doc.id);
  }

  Stream<Availability?> watchAvailability(String availabilityId) {
    final trimmedAvailabilityId = availabilityId.trim();

    if (trimmedAvailabilityId.isEmpty) {
      return Stream.value(null);
    }

    return _availabilities.doc(trimmedAvailabilityId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return Availability.fromFirestore(doc.data()!, doc.id);
    });
  }

  Future<void> deleteAvailability(String availabilityId) async {
    final trimmedAvailabilityId = availabilityId.trim();

    if (trimmedAvailabilityId.isEmpty) {
      return;
    }

    await _availabilities.doc(trimmedAvailabilityId).delete();
  }

  Map<String, dynamic> _buildAvailabilityPayload({
    required String type,
    required String title,
    required String note,
    required String visibility,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? day,
    String? startTime,
    String? endTime,
    required bool includeLegacyFields,
    required bool includeUserId,
    required bool includeCreatedAt,
    required bool includeUpdatedAt,
  }) {
    final payload = <String, dynamic>{
      'type': type.trim(),
      'title': title.trim(),
      'note': note.trim(),
      'visibility': _normalizeVisibility(visibility),
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
    };

    if (includeUserId) {
      payload['userId'] = currentUserId;
    }

    if (includeCreatedAt) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    if (includeUpdatedAt) {
      payload['updatedAt'] = FieldValue.serverTimestamp();
    }

    if (includeLegacyFields) {
      payload.addAll({
        'day': _cleanOrFallback(day, _formatDateOnly(startDateTime)),
        'startTime': _cleanOrFallback(startTime, _formatTimeOnly(startDateTime)),
        'endTime': _cleanOrFallback(endTime, _formatTimeOnly(endDateTime)),
      });
    }

    return payload;
  }

  void _sortAvailabilities(List<Availability> availabilities) {
    availabilities.sort((a, b) {
      final aDate =
          a.effectiveSortDateTime ?? a.updatedAt ?? a.createdAt ?? DateTime(2000);
      final bDate =
          b.effectiveSortDateTime ?? b.updatedAt ?? b.createdAt ?? DateTime(2000);

      final compareDate = aDate.compareTo(bDate);
      if (compareDate != 0) return compareDate;

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  void _validateSchedule(DateTime startDateTime, DateTime endDateTime) {
    if (!endDateTime.isAfter(startDateTime)) {
      throw Exception('La fin doit être après le début.');
    }
  }

  String _cleanOrFallback(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : fallback;
  }

  String _normalizeVisibility(String value) {
    final trimmed = value.trim();

    switch (trimmed) {
      case Availability.visibilityPublic:
        return Availability.visibilityPublic;
      case Availability.visibilityPrivate:
      default:
        return Availability.visibilityPrivate;
    }
  }

  static String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _formatTimeOnly(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}