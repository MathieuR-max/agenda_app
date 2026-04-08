import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/services/current_user.dart';

class SearchFirestoreService {
  final FirebaseFirestore _db;

  SearchFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get currentUserId => CurrentUser.id;

  CollectionReference<Map<String, dynamic>> get _searches =>
      _db.collection(FirestoreCollections.searches);

  Future<void> saveSearch({
    required String day,
    required String startTime,
    required String endTime,
    required String category,

    /// Nouvelle projection temporelle optionnelle.
    /// Si absente, on tente de la reconstruire à partir du legacy.
    DateTime? startDateTime,
    DateTime? endDateTime,
  }) async {
    final trimmedDay = day.trim();
    final trimmedStartTime = startTime.trim();
    final trimmedEndTime = endTime.trim();
    final trimmedCategory = category.trim();

    final resolvedStartDateTime = startDateTime ??
        _combineLegacyDateAndTime(trimmedDay, trimmedStartTime);
    final resolvedEndDateTime = endDateTime ??
        _combineLegacyDateAndTime(trimmedDay, trimmedEndTime);

    if (trimmedDay.isEmpty) {
      throw Exception('Le jour de recherche est requis.');
    }

    if (trimmedStartTime.isEmpty) {
      throw Exception('L\'heure de début est requise.');
    }

    if (trimmedEndTime.isEmpty) {
      throw Exception('L\'heure de fin est requise.');
    }

    if (trimmedCategory.isEmpty) {
      throw Exception('La catégorie est requise.');
    }

    if (resolvedStartDateTime != null &&
        resolvedEndDateTime != null &&
        !resolvedEndDateTime.isAfter(resolvedStartDateTime)) {
      throw Exception('La fin doit être après le début.');
    }

    final payload = <String, dynamic>{
      'userId': currentUserId,
      'day': trimmedDay,
      'startTime': trimmedStartTime,
      'endTime': trimmedEndTime,
      'category': trimmedCategory,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (resolvedStartDateTime != null) {
      payload['startDateTime'] = Timestamp.fromDate(resolvedStartDateTime);
    }

    if (resolvedEndDateTime != null) {
      payload['endDateTime'] = Timestamp.fromDate(resolvedEndDateTime);
    }

    await _searches.add(payload);
  }

  Stream<List<Map<String, dynamic>>> getSearches() {
    return _searches
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();

        final resolvedStartDateTime =
            _toDateTime(data['startDateTime']) ??
                _combineLegacyDateAndTime(
                  _parseString(data['day']),
                  _parseString(data['startTime']),
                );

        final resolvedEndDateTime =
            _toDateTime(data['endDateTime']) ??
                _combineLegacyDateAndTime(
                  _parseString(data['day']),
                  _parseString(data['endTime']),
                );

        return <String, dynamic>{
          'id': doc.id,
          'userId': _parseString(data['userId']),
          'day': _parseString(data['day']),
          'startTime': _parseString(data['startTime']),
          'endTime': _parseString(data['endTime']),
          'category': _parseString(data['category']),
          'startDateTime': resolvedStartDateTime,
          'endDateTime': resolvedEndDateTime,
          'createdAt': _toDateTime(data['createdAt']),
          'effectiveSortDateTime':
              resolvedStartDateTime ?? _toDateTime(data['createdAt']),
        };
      }).toList();

      items.sort((a, b) {
        final aDate =
            a['effectiveSortDateTime'] as DateTime? ?? DateTime(2000);
        final bDate =
            b['effectiveSortDateTime'] as DateTime? ?? DateTime(2000);

        final compareDate = bDate.compareTo(aDate);
        if (compareDate != 0) return compareDate;

        final aCategory = (a['category'] as String).toLowerCase();
        final bCategory = (b['category'] as String).toLowerCase();
        return aCategory.compareTo(bCategory);
      });

      return items;
    });
  }

  Stream<List<Map<String, dynamic>>> getSearchesForRange({
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _searches
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
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return <String, dynamic>{
          'id': doc.id,
          'userId': _parseString(data['userId']),
          'day': _parseString(data['day']),
          'startTime': _parseString(data['startTime']),
          'endTime': _parseString(data['endTime']),
          'category': _parseString(data['category']),
          'startDateTime': _toDateTime(data['startDateTime']),
          'endDateTime': _toDateTime(data['endDateTime']),
          'createdAt': _toDateTime(data['createdAt']),
        };
      }).toList();
    });
  }

  Future<Map<String, dynamic>?> getSearchById(String searchId) async {
    final trimmedSearchId = searchId.trim();

    if (trimmedSearchId.isEmpty) {
      return null;
    }

    final doc = await _searches.doc(trimmedSearchId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final data = doc.data()!;

    final resolvedStartDateTime =
        _toDateTime(data['startDateTime']) ??
            _combineLegacyDateAndTime(
              _parseString(data['day']),
              _parseString(data['startTime']),
            );

    final resolvedEndDateTime =
        _toDateTime(data['endDateTime']) ??
            _combineLegacyDateAndTime(
              _parseString(data['day']),
              _parseString(data['endTime']),
            );

    return <String, dynamic>{
      'id': doc.id,
      'userId': _parseString(data['userId']),
      'day': _parseString(data['day']),
      'startTime': _parseString(data['startTime']),
      'endTime': _parseString(data['endTime']),
      'category': _parseString(data['category']),
      'startDateTime': resolvedStartDateTime,
      'endDateTime': resolvedEndDateTime,
      'createdAt': _toDateTime(data['createdAt']),
      'effectiveSortDateTime':
          resolvedStartDateTime ?? _toDateTime(data['createdAt']),
    };
  }

  Stream<Map<String, dynamic>?> watchSearch(String searchId) {
    final trimmedSearchId = searchId.trim();

    if (trimmedSearchId.isEmpty) {
      return Stream.value(null);
    }

    return _searches.doc(trimmedSearchId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;

      final resolvedStartDateTime =
          _toDateTime(data['startDateTime']) ??
              _combineLegacyDateAndTime(
                _parseString(data['day']),
                _parseString(data['startTime']),
              );

      final resolvedEndDateTime =
          _toDateTime(data['endDateTime']) ??
              _combineLegacyDateAndTime(
                _parseString(data['day']),
                _parseString(data['endTime']),
              );

      return <String, dynamic>{
        'id': doc.id,
        'userId': _parseString(data['userId']),
        'day': _parseString(data['day']),
        'startTime': _parseString(data['startTime']),
        'endTime': _parseString(data['endTime']),
        'category': _parseString(data['category']),
        'startDateTime': resolvedStartDateTime,
        'endDateTime': resolvedEndDateTime,
        'createdAt': _toDateTime(data['createdAt']),
        'effectiveSortDateTime':
            resolvedStartDateTime ?? _toDateTime(data['createdAt']),
      };
    });
  }

  Future<void> deleteSearch(String searchId) async {
    final trimmedSearchId = searchId.trim();

    if (trimmedSearchId.isEmpty) {
      return;
    }

    await _searches.doc(trimmedSearchId).delete();
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }

    return null;
  }

  static DateTime? _combineLegacyDateAndTime(String day, String time) {
    if (day.trim().isEmpty || time.trim().isEmpty) {
      return null;
    }

    try {
      final date = DateTime.parse(day);
      final parts = time.split(':');
      if (parts.length < 2) return null;

      final hour = int.tryParse(parts[0].trim()) ?? 0;
      final minute = int.tryParse(parts[1].trim()) ?? 0;

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

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString().trim();
  }
}