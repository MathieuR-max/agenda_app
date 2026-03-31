import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String id;
  final String title;
  final String description;
  final String category;
  final String day;
  final String startTime;
  final String endTime;
  final String location;
  final int maxParticipants;
  final String level;
  final String groupType;
  final String ownerId;
  final String ownerPseudo;
  final bool ownerPending;
  final int participantCount;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String visibility; // public | private | inviteOnly
  final String status; // open | full | cancelled | done

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
    required this.location,
    required this.maxParticipants,
    required this.level,
    required this.groupType,
    required this.ownerId,
    required this.ownerPseudo,
    required this.ownerPending,
    required this.participantCount,
    this.lastMessageText,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
    required this.visibility,
    required this.status,
  });

  factory Activity.fromMap(String id, Map<String, dynamic> map) {
    return Activity(
      id: id,
      title: _parseString(map['title']),
      description: _parseString(map['description']),
      category: _parseString(map['category']),
      day: _parseString(map['day']),
      startTime: _parseString(map['startTime']),
      endTime: _parseString(map['endTime']),
      location: _parseString(map['location']),
      maxParticipants: _parseInt(map['maxParticipants']),
      level: _parseString(map['level']),
      groupType: _parseString(map['groupType']),
      ownerId: _parseString(map['ownerId']),
      ownerPseudo: _parseString(map['ownerPseudo']),
      ownerPending: _parseBool(map['ownerPending']),
      participantCount: _parseInt(map['participantCount']),
      lastMessageText: _parseNullableString(map['lastMessageText']),
      lastMessageAt: _toDateTime(map['lastMessageAt']),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      visibility: _normalizeVisibility(
        _parseString(map['visibility'], fallback: visibilityPublic),
      ),
      status: _normalizeStatus(
        _parseString(map['status'], fallback: statusOpen),
      ),
    );
  }

  factory Activity.fromFirestore(Map<String, dynamic> data, String id) {
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
      location: '',
      maxParticipants: 0,
      level: '',
      groupType: '',
      ownerId: '',
      ownerPseudo: '',
      ownerPending: false,
      participantCount: 0,
      lastMessageText: null,
      lastMessageAt: null,
      createdAt: null,
      updatedAt: null,
      visibility: visibilityPublic,
      status: statusOpen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'maxParticipants': maxParticipants,
      'level': level,
      'groupType': groupType,
      'ownerId': ownerId,
      'ownerPseudo': ownerPseudo,
      'ownerPending': ownerPending,
      'participantCount': participantCount,
      'lastMessageText': lastMessageText,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'visibility': visibility,
      'status': status,
    };
  }

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? day,
    String? startTime,
    String? endTime,
    String? location,
    int? maxParticipants,
    String? level,
    String? groupType,
    String? ownerId,
    String? ownerPseudo,
    bool? ownerPending,
    int? participantCount,
    String? lastMessageText,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? visibility,
    String? status,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      level: level ?? this.level,
      groupType: groupType ?? this.groupType,
      ownerId: ownerId ?? this.ownerId,
      ownerPseudo: ownerPseudo ?? this.ownerPseudo,
      ownerPending: ownerPending ?? this.ownerPending,
      participantCount: participantCount ?? this.participantCount,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
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

  int? get remainingPlaces {
    if (hasUnlimitedPlaces) return null;
    final remaining = maxParticipants - participantCount;
    return remaining < 0 ? 0 : remaining;
  }

  String get displayedMaxParticipants {
    return hasUnlimitedPlaces ? 'Non défini' : maxParticipants.toString();
  }

  bool get canBeJoined =>
      !isCancelled &&
      !isDone &&
      !isFull &&
      !isInviteOnly &&
      (hasUnlimitedPlaces || participantCount < maxParticipants);

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  static String _normalizeVisibility(String value) {
    switch (value) {
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
    switch (value) {
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