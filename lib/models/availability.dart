import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/availability_constants.dart';

class Availability {
  final String id;
  final String type;
  final String title;
  final String note;
  final String visibility;

  /// Legacy compatibility fields.
  /// À supprimer quand la migration Firestore sera terminée.
  final String day;
  final String startTime;
  final String endTime;

  /// New source of truth.
  final DateTime? startDateTime;
  final DateTime? endDateTime;

  final String userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const String visibilityPublic = 'public';
  static const String visibilityPrivate = 'private';

  Availability({
    required this.id,
    required this.type,
    required this.title,
    required this.note,
    required this.visibility,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.startDateTime,
    required this.endDateTime,
    required this.userId,
    this.createdAt,
    this.updatedAt,
  });

  factory Availability.fromMap(String id, Map<String, dynamic> data) {
    final DateTime? resolvedStartDateTime = _resolveStartDateTime(data);
    final DateTime? resolvedEndDateTime = _resolveEndDateTime(data);

    return Availability(
      id: _parseString(id),
      type: _normalizeType(_parseString(data['type'])),
      title: _parseString(data['title']),
      note: _parseString(data['note']),
      visibility: _normalizeVisibility(
        _parseString(data['visibility'], fallback: visibilityPrivate),
      ),
      day: resolvedStartDateTime != null
          ? _formatDateOnly(resolvedStartDateTime)
          : _parseString(data['day']),
      startTime: resolvedStartDateTime != null
          ? _formatTimeOnly(resolvedStartDateTime)
          : _parseString(data['startTime']),
      endTime: resolvedEndDateTime != null
          ? _formatTimeOnly(resolvedEndDateTime)
          : _parseString(data['endTime']),
      startDateTime: resolvedStartDateTime,
      endDateTime: resolvedEndDateTime,
      userId: _parseString(data['userId']),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  factory Availability.fromFirestore(Map<String, dynamic> data, String id) {
    return Availability.fromMap(id, data);
  }

  factory Availability.empty(String id) {
    return Availability(
      id: id,
      type: '',
      title: '',
      note: '',
      visibility: visibilityPrivate,
      day: '',
      startTime: '',
      endTime: '',
      startDateTime: null,
      endDateTime: null,
      userId: '',
      createdAt: null,
      updatedAt: null,
    );
  }

  Map<String, dynamic> toMap({
    bool includeLegacyFields = true,
  }) {
    final map = <String, dynamic>{
      'type': _normalizeType(type),
      'title': title.trim(),
      'note': note.trim(),
      'visibility': _normalizeVisibility(visibility),
      'startDateTime': resolvedStartDateTime != null
          ? Timestamp.fromDate(resolvedStartDateTime!)
          : null,
      'endDateTime': resolvedEndDateTime != null
          ? Timestamp.fromDate(resolvedEndDateTime!)
          : null,
      'userId': userId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };

    if (includeLegacyFields) {
      map.addAll({
        'day': effectiveDay,
        'startTime': effectiveStartTime,
        'endTime': effectiveEndTime,
      });
    }

    return map;
  }

  Availability copyWith({
    String? id,
    String? type,
    String? title,
    String? note,
    String? visibility,
    String? day,
    String? startTime,
    String? endTime,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearStartDateTime = false,
    bool clearEndDateTime = false,
  }) {
    final DateTime? nextStartDateTime = clearStartDateTime
        ? null
        : (startDateTime ?? this.startDateTime);

    final DateTime? nextEndDateTime = clearEndDateTime
        ? null
        : (endDateTime ?? this.endDateTime);

    final String nextDay = day ??
        (nextStartDateTime != null
            ? _formatDateOnly(nextStartDateTime)
            : this.day);

    final String nextStartTime = startTime ??
        (nextStartDateTime != null
            ? _formatTimeOnly(nextStartDateTime)
            : this.startTime);

    final String nextEndTime = endTime ??
        (nextEndDateTime != null
            ? _formatTimeOnly(nextEndDateTime)
            : this.endTime);

    return Availability(
      id: id ?? this.id,
      type: _normalizeType(type ?? this.type),
      title: title ?? this.title,
      note: note ?? this.note,
      visibility: visibility ?? this.visibility,
      day: nextDay,
      startTime: nextStartTime,
      endTime: nextEndTime,
      startDateTime: nextStartDateTime,
      endDateTime: nextEndDateTime,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasNote => note.trim().isNotEmpty;

  bool get isPublic => visibility == visibilityPublic;

  bool get isPrivate => visibility == visibilityPrivate;

  bool get hasRealDateTime =>
      resolvedStartDateTime != null && resolvedEndDateTime != null;

  bool get hasCompleteLegacySchedule =>
      day.trim().isNotEmpty &&
      startTime.trim().isNotEmpty &&
      endTime.trim().isNotEmpty;

  DateTime? get resolvedStartDateTime {
    if (startDateTime != null) return startDateTime;
    if (day.trim().isEmpty || startTime.trim().isEmpty) return null;
    return _combineLegacyDateAndTime(day, startTime);
  }

  DateTime? get resolvedEndDateTime {
    if (endDateTime != null) return endDateTime;
    if (day.trim().isEmpty || endTime.trim().isEmpty) return null;
    return _combineLegacyDateAndTime(day, endTime);
  }

  bool get isSingleDay {
    final start = resolvedStartDateTime;
    final end = resolvedEndDateTime;
    if (start == null || end == null) return true;

    return start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
  }

  bool get hasValidResolvedRange {
    final start = resolvedStartDateTime;
    final end = resolvedEndDateTime;
    if (start == null || end == null) return false;
    return !end.isBefore(start);
  }

  String get typeLabel {
    return AvailabilityTypes.label(type);
  }

  String get visibilityLabel {
    switch (visibility) {
      case visibilityPublic:
        return 'Publique';
      case visibilityPrivate:
      default:
        return 'Privée';
    }
  }

  String get effectiveDay {
    final start = resolvedStartDateTime;
    if (start != null) return _formatDateOnly(start);
    return day;
  }

  String get effectiveStartTime {
    final start = resolvedStartDateTime;
    if (start != null) return _formatTimeOnly(start);
    return startTime;
  }

  String get effectiveEndTime {
    final end = resolvedEndDateTime;
    if (end != null) return _formatTimeOnly(end);
    return endTime;
  }

  DateTime? get effectiveSortDateTime =>
      resolvedStartDateTime ?? resolvedEndDateTime;

  String get scheduleLabel {
    final start = resolvedStartDateTime;
    final end = resolvedEndDateTime;

    if (start != null && end != null) {
      final dayLabel = _formatDateOnly(start);
      final startLabel = _formatTimeOnly(start);
      final endLabel = _formatTimeOnly(end);
      return '$dayLabel • $startLabel - $endLabel';
    }

    if (effectiveDay.trim().isNotEmpty &&
        effectiveStartTime.trim().isNotEmpty &&
        effectiveEndTime.trim().isNotEmpty) {
      return '$effectiveDay • $effectiveStartTime - $effectiveEndTime';
    }

    if (effectiveDay.trim().isNotEmpty) {
      return effectiveDay;
    }

    return '';
  }

  static DateTime? _resolveStartDateTime(Map<String, dynamic> data) {
    final direct = _toDateTime(data['startDateTime']);
    if (direct != null) return direct;

    final legacyDay = _parseNullableString(data['day']);
    final legacyStartTime = _parseNullableString(data['startTime']);

    if (legacyDay == null || legacyStartTime == null) return null;
    return _combineLegacyDateAndTime(legacyDay, legacyStartTime);
  }

  static DateTime? _resolveEndDateTime(Map<String, dynamic> data) {
    final direct = _toDateTime(data['endDateTime']);
    if (direct != null) return direct;

    final legacyDay = _parseNullableString(data['day']);
    final legacyEndTime = _parseNullableString(data['endTime']);

    if (legacyDay == null || legacyEndTime == null) return null;
    return _combineLegacyDateAndTime(legacyDay, legacyEndTime);
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

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString().trim();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  static String _normalizeVisibility(String value) {
    switch (value.trim()) {
      case visibilityPublic:
        return visibilityPublic;
      case visibilityPrivate:
      default:
        return visibilityPrivate;
    }
  }

  static String _normalizeType(String value) {
    final trimmed = value.trim();

    if (AvailabilityTypes.all.contains(trimmed)) {
      return trimmed;
    }

    switch (trimmed.toLowerCase()) {
      case 'disponible':
      case 'disponibilité':
        return AvailabilityTypes.available;
      case 'indisponible':
      case 'indisponibilité':
        return AvailabilityTypes.unavailable;
      case 'activité personnelle':
      case 'activite personnelle':
      case 'personal':
      case 'note':
        return AvailabilityTypes.personal;
      case 'peut-être disponible':
      case 'peut etre disponible':
      case 'maybe':
        return AvailabilityTypes.maybe;
      default:
        return trimmed;
    }
  }
}