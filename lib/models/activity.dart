import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String id;
  final String title;
  final String description;
  final String category;

  /// Legacy compatibility fields.
  /// À supprimer quand toute la migration Firestore sera terminée.
  final String day;
  final String startTime;
  final String endTime;

  /// New source of truth.
  final DateTime? startDateTime;
  final DateTime? endDateTime;

  final String location;
  final int maxParticipants;
  final String level;
  final String groupType;

  /// Current organizer
  final String ownerId;
  final String ownerPseudo;

  /// Original creator
  final String createdById;
  final String createdByPseudo;

  /// Reclaimed organizer
  final String? reclaimedById;
  final String? reclaimedByPseudo;
  final DateTime? reclaimedAt;

  final bool ownerPending;
  final int participantCount;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String visibility; // public | private | inviteOnly
  final String status; // open | full | cancelled | done

  final String? groupId;
  final String? groupName;

  static const String visibilityPublic = 'public';
  static const String visibilityPrivate = 'private';
  static const String visibilityInviteOnly = 'inviteOnly';

  static const String statusOpen = 'open';
  static const String statusFull = 'full';
  static const String statusCancelled = 'cancelled';
  static const String statusDone = 'done';

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.startDateTime,
    required this.endDateTime,
    required this.location,
    required this.maxParticipants,
    required this.level,
    required this.groupType,
    required this.ownerId,
    required this.ownerPseudo,
    required this.createdById,
    required this.createdByPseudo,
    this.reclaimedById,
    this.reclaimedByPseudo,
    this.reclaimedAt,
    required this.ownerPending,
    required this.participantCount,
    this.lastMessageText,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
    required this.visibility,
    required this.status,
    this.groupId,
    this.groupName,
  });

  factory Activity.fromMap(String id, Map<String, dynamic> map) {
    final DateTime? resolvedStartDateTime = _resolveStartDateTime(map);

    final DateTime? resolvedEndDateTime = _resolveEndDateTime(
      map,
      fallbackStartDateTime: resolvedStartDateTime,
    );

    final String resolvedDay = resolvedStartDateTime != null
        ? _formatDateOnly(resolvedStartDateTime)
        : _parseString(map['day']);

    final String resolvedStartTime = resolvedStartDateTime != null
        ? _formatTimeOnly(resolvedStartDateTime)
        : _parseString(map['startTime']);

    final String resolvedEndTime = resolvedEndDateTime != null
        ? _formatTimeOnly(resolvedEndDateTime)
        : _parseString(map['endTime']);

    final ownerPseudo = _parseString(map['ownerPseudo']);

    return Activity(
      id: _parseString(id),
      title: _parseString(map['title']),
      description: _parseString(map['description']),
      category: _parseString(map['category']),
      day: resolvedDay,
      startTime: resolvedStartTime,
      endTime: resolvedEndTime,
      startDateTime: resolvedStartDateTime,
      endDateTime: resolvedEndDateTime,
      location: _parseString(map['location']),
      maxParticipants: _parseInt(map['maxParticipants']),
      level: _parseString(map['level']),
      groupType: _parseString(map['groupType']),
      ownerId: _parseString(map['ownerId']),
      ownerPseudo: ownerPseudo,

      createdById: _parseString(
        map['createdById'],
        fallback: _parseString(map['ownerId']),
      ),

      createdByPseudo: _parseString(
        map['createdByPseudo'],
        fallback: ownerPseudo,
      ),

      reclaimedById: _parseNullableString(map['reclaimedById']),
      reclaimedByPseudo: _parseNullableString(map['reclaimedByPseudo']),
      reclaimedAt: _toDateTime(map['reclaimedAt']),

      ownerPending: _parseBool(map['ownerPending']),
      participantCount: _parseInt(map['participantCount']),
      lastMessageText: _parseNullableString(map['lastMessageText']),
      lastMessageAt: _toDateTime(map['lastMessageAt']),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),

      visibility: _normalizeVisibility(
        _parseString(
          map['visibility'],
          fallback: visibilityPublic,
        ),
      ),

      status: _normalizeStatus(
        _parseString(
          map['status'],
          fallback: statusOpen,
        ),
      ),

      groupId: _parseNullableString(map['groupId']),
      groupName: _parseNullableString(map['groupName']),
    );
  }

  factory Activity.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return Activity.fromMap(id, data);
  }

  factory Activity.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    if (data == null) {
      return Activity.empty(doc.id);
    }

    return Activity.fromMap(doc.id, data);
  }

  factory Activity.empty(String id) {
    return Activity(
      id: id,
      title: '',
      description: '',
      category: '',
      day: '',
      startTime: '',
      endTime: '',
      startDateTime: null,
      endDateTime: null,
      location: '',
      maxParticipants: 0,
      level: '',
      groupType: '',
      ownerId: '',
      ownerPseudo: '',
      createdById: '',
      createdByPseudo: '',
      reclaimedById: null,
      reclaimedByPseudo: null,
      reclaimedAt: null,
      ownerPending: false,
      participantCount: 0,
      lastMessageText: null,
      lastMessageAt: null,
      createdAt: null,
      updatedAt: null,
      visibility: visibilityPublic,
      status: statusOpen,
      groupId: null,
      groupName: null,
    );
  }

  Map<String, dynamic> toMap({
    bool includeLegacyFields = true,
  }) {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'category': category,

      'startDateTime':
          startDateTime != null
              ? Timestamp.fromDate(startDateTime!)
              : null,

      'endDateTime':
          endDateTime != null
              ? Timestamp.fromDate(endDateTime!)
              : null,

      'location': location,
      'maxParticipants': maxParticipants,
      'level': level,
      'groupType': groupType,

      'ownerId': ownerId,
      'ownerPseudo': ownerPseudo,

      'createdById': createdById,
      'createdByPseudo': createdByPseudo,

      'reclaimedById': reclaimedById,
      'reclaimedByPseudo': reclaimedByPseudo,

      'reclaimedAt':
          reclaimedAt != null
              ? Timestamp.fromDate(reclaimedAt!)
              : null,

      'ownerPending': ownerPending,
      'participantCount': participantCount,
      'lastMessageText': lastMessageText,

      'lastMessageAt':
          lastMessageAt != null
              ? Timestamp.fromDate(lastMessageAt!)
              : null,

      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : null,

      'updatedAt':
          updatedAt != null
              ? Timestamp.fromDate(updatedAt!)
              : null,

      'visibility': visibility,
      'status': status,

      'groupId': groupId,
      'groupName': groupName,
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

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? day,
    String? startTime,
    String? endTime,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? location,
    int? maxParticipants,
    String? level,
    String? groupType,

    String? ownerId,
    String? ownerPseudo,

    String? createdById,
    String? createdByPseudo,

    String? reclaimedById,
    String? reclaimedByPseudo,
    DateTime? reclaimedAt,

    bool? ownerPending,
    int? participantCount,

    String? lastMessageText,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,

    String? visibility,
    String? status,

    String? groupId,
    String? groupName,

    bool clearGroupId = false,
    bool clearGroupName = false,

    bool clearStartDateTime = false,
    bool clearEndDateTime = false,

    bool clearLastMessageText = false,
    bool clearLastMessageAt = false,

    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,

    bool clearReclaimedById = false,
    bool clearReclaimedByPseudo = false,
    bool clearReclaimedAt = false,
  }) {
    final DateTime? nextStartDateTime = clearStartDateTime
        ? null
        : (startDateTime ?? this.startDateTime);

    final DateTime? nextEndDateTime = clearEndDateTime
        ? null
        : (endDateTime ?? this.endDateTime);

    final String resolvedDay = day ??
        (
          nextStartDateTime != null
              ? _formatDateOnly(nextStartDateTime)
              : this.day
        );

    final String resolvedStartTime = startTime ??
        (
          nextStartDateTime != null
              ? _formatTimeOnly(nextStartDateTime)
              : this.startTime
        );

    final String resolvedEndTime = endTime ??
        (
          nextEndDateTime != null
              ? _formatTimeOnly(nextEndDateTime)
              : this.endTime
        );

    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,

      day: resolvedDay,
      startTime: resolvedStartTime,
      endTime: resolvedEndTime,

      startDateTime: nextStartDateTime,
      endDateTime: nextEndDateTime,

      location: location ?? this.location,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      level: level ?? this.level,
      groupType: groupType ?? this.groupType,

      ownerId: ownerId ?? this.ownerId,
      ownerPseudo: ownerPseudo ?? this.ownerPseudo,

      createdById: createdById ?? this.createdById,
      createdByPseudo: createdByPseudo ?? this.createdByPseudo,

      reclaimedById: clearReclaimedById
          ? null
          : (reclaimedById ?? this.reclaimedById),

      reclaimedByPseudo: clearReclaimedByPseudo
          ? null
          : (reclaimedByPseudo ?? this.reclaimedByPseudo),

      reclaimedAt: clearReclaimedAt
          ? null
          : (reclaimedAt ?? this.reclaimedAt),

      ownerPending: ownerPending ?? this.ownerPending,
      participantCount: participantCount ?? this.participantCount,

      lastMessageText: clearLastMessageText
          ? null
          : (lastMessageText ?? this.lastMessageText),

      lastMessageAt: clearLastMessageAt
          ? null
          : (lastMessageAt ?? this.lastMessageAt),

      createdAt: clearCreatedAt
          ? null
          : (createdAt ?? this.createdAt),

      updatedAt: clearUpdatedAt
          ? null
          : (updatedAt ?? this.updatedAt),

      visibility: visibility != null
          ? _normalizeVisibility(visibility)
          : this.visibility,

      status: status != null
          ? _normalizeStatus(status)
          : this.status,

      groupId: clearGroupId
          ? null
          : (
              groupId != null
                  ? _parseNullableString(groupId)
                  : this.groupId
            ),

      groupName: clearGroupName
          ? null
          : (
              groupName != null
                  ? _parseNullableString(groupName)
                  : this.groupName
            ),
    );
  }

  bool get isPublic => visibility == visibilityPublic;

  bool get isPrivate => visibility == visibilityPrivate;

  bool get isInviteOnly => visibility == visibilityInviteOnly;

  bool get isOpen => status == statusOpen;

  bool get isFull => status == statusFull;

  bool get isCancelled => status == statusCancelled;

  bool get isDone => status == statusDone;

  bool get hasUnlimitedPlaces => maxParticipants <= 0;

  bool get isGroupActivity =>
      groupId != null && groupId!.trim().isNotEmpty;

  bool get isGroupPrivateActivity =>
      isGroupActivity && visibility == visibilityPrivate;

  bool get isMixedGroupActivity =>
      isGroupActivity && visibility == visibilityPublic;

  bool get isStandardActivity => !isGroupActivity;

  bool get hasRealDateTime =>
      startDateTime != null && endDateTime != null;

  bool get hasAnyResolvedDateTime =>
      resolvedStartDateTime != null ||
      resolvedEndDateTime != null;

  bool get hasJoinedParticipants => participantCount > 1;

  bool get canEditActivity => !hasJoinedParticipants;

  bool get hasBeenReclaimed =>
      reclaimedByPseudo != null &&
      reclaimedByPseudo!.trim().isNotEmpty;

  String get organizerDisplayLabel {
  final created = createdByPseudo.trim().isNotEmpty
      ? createdByPseudo.trim()
      : ownerPseudo.trim().isNotEmpty
          ? ownerPseudo.trim()
          : 'Utilisateur inconnu';

  if (!hasBeenReclaimed) {
    return 'Créée par $created';
  }

  return 'Créée par $created • Reprise par ${reclaimedByPseudo!.trim()}';
}

  DateTime? get resolvedStartDateTime => startDateTime;

  DateTime? get resolvedEndDateTime =>
      endDateTime ?? _resolveEndDateTimeFromLegacyFallback();

  DateTime? get effectiveSortDateTime =>
      resolvedStartDateTime ?? resolvedEndDateTime;

  bool get hasStarted {
    final start = resolvedStartDateTime;

    if (start == null) return false;

    return !DateTime.now().isBefore(start);
  }

  bool get hasEnded {
    final end = resolvedEndDateTime;

    if (end == null) return false;

    return DateTime.now().isAfter(end);
  }

  bool get isOngoing {
    final start = resolvedStartDateTime;
    final end = resolvedEndDateTime;

    if (start == null || end == null) {
      return false;
    }

    final now = DateTime.now();

    return !now.isBefore(start) && now.isBefore(end);
  }

  int? get remainingPlaces {
    if (hasUnlimitedPlaces) return null;

    final remaining = maxParticipants - participantCount;

    return remaining < 0 ? 0 : remaining;
  }

  String get displayedMaxParticipants {
    return hasUnlimitedPlaces
        ? 'Illimité'
        : maxParticipants.toString();
  }

  bool get canBeJoined =>
      !isCancelled &&
      !isDone &&
      !isFull &&
      !isInviteOnly &&
      !hasEnded &&
      (
        hasUnlimitedPlaces ||
        participantCount < maxParticipants
      );

  bool get requiresOwner => ownerPending;

  bool get isJoinRestricted =>
      isInviteOnly ||
      isCancelled ||
      isDone ||
      isFull ||
      hasEnded;

  String get activityTypeLabel {
    if (isMixedGroupActivity) {
      return 'G+P';
    }

    if (isGroupPrivateActivity) {
      return 'Groupe';
    }

    if (isInviteOnly) {
      return 'Invite';
    }

    if (isPrivate) {
      return 'Privée';
    }

    return 'Public';
  }

  List<String> get calendarIndicators {
    final List<String> indicators = [];

    if (hasUnlimitedPlaces) {
      indicators.add('Illimité');
    }

    if (isFull) {
      indicators.add('Complet');
    }

    if (requiresOwner) {
      indicators.add('Owner requis');
    }

    return indicators;
  }

  String get effectiveDay {
    if (resolvedStartDateTime != null) {
      return _formatDateOnly(resolvedStartDateTime!);
    }

    if (day.trim().isNotEmpty) {
      return day;
    }

    if (resolvedEndDateTime != null) {
      return _formatDateOnly(resolvedEndDateTime!);
    }

    return '';
  }

  String get effectiveStartTime {
    if (resolvedStartDateTime != null) {
      return _formatTimeOnly(resolvedStartDateTime!);
    }

    return startTime;
  }

  String get effectiveEndTime {
    if (resolvedEndDateTime != null) {
      return _formatTimeOnly(resolvedEndDateTime!);
    }

    return endTime;
  }

  String get scheduleLabel {
    final parts = <String>[];

    if (effectiveDay.isNotEmpty) {
      parts.add(effectiveDay);
    }

    final start = effectiveStartTime;
    final end = effectiveEndTime;

    if (start.isNotEmpty && end.isNotEmpty) {
      parts.add('$start - $end');
    } else if (start.isNotEmpty) {
      parts.add(start);
    } else if (end.isNotEmpty) {
      parts.add(end);
    }

    return parts.join(' • ');
  }

  DateTime? _resolveEndDateTimeFromLegacyFallback() {
    if (endDateTime != null) {
      return endDateTime;
    }

    final effectiveDayValue = effectiveDay;
    final effectiveEndTimeValue = endTime.trim();

    if (
      effectiveDayValue.isEmpty ||
      effectiveEndTimeValue.isEmpty
    ) {
      return null;
    }

    return _combineLegacyDateAndTime(
      effectiveDayValue,
      effectiveEndTimeValue,
    );
  }

  static DateTime? _resolveStartDateTime(
    Map<String, dynamic> map,
  ) {
    final direct = _toDateTime(map['startDateTime']);

    if (direct != null) return direct;

    final legacyDay = _parseNullableString(map['day']);
    final legacyStartTime = _parseNullableString(map['startTime']);

    if (legacyDay == null || legacyStartTime == null) {
      return null;
    }

    return _combineLegacyDateAndTime(
      legacyDay,
      legacyStartTime,
    );
  }

  static DateTime? _resolveEndDateTime(
    Map<String, dynamic> map, {
    DateTime? fallbackStartDateTime,
  }) {
    final direct = _toDateTime(map['endDateTime']);

    if (direct != null) return direct;

    final legacyDay =
        _parseNullableString(map['day']) ??
        (
          fallbackStartDateTime != null
              ? _formatDateOnly(fallbackStartDateTime)
              : null
        );

    final legacyEndTime = _parseNullableString(map['endTime']);

    if (legacyDay == null || legacyEndTime == null) {
      return null;
    }

    return _combineLegacyDateAndTime(
      legacyDay,
      legacyEndTime,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static DateTime? _combineLegacyDateAndTime(
    String day,
    String time,
  ) {
    try {
      final date = DateTime.parse(day.trim());

      final parts = time.trim().split(':');

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

  static int _parseInt(dynamic value) {
    if (value is int) return value;

    if (value is double) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }

    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;

    if (value is String) {
      return value.toLowerCase().trim() == 'true';
    }

    return false;
  }

  static String _parseString(
    dynamic value, {
    String fallback = '',
  }) {
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
      case visibilityPrivate:
        return visibilityPrivate;

      case visibilityInviteOnly:
        return visibilityInviteOnly;

      case visibilityPublic:
      default:
        return visibilityPublic;
    }
  }

  static String _normalizeStatus(String value) {
    switch (value.trim()) {
      case statusFull:
        return statusFull;

      case statusCancelled:
        return statusCancelled;

      case statusDone:
        return statusDone;

      case statusOpen:
      default:
        return statusOpen;
    }
  }
}