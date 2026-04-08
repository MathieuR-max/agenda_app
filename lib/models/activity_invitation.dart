import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityInvitation {
  final String id;
  final String activityId;
  final String activityTitle;

  /// Legacy display fields kept for invitation snapshots.
  final String activityDay;
  final String activityStartTime;
  final String activityLocation;

  final String fromUserId;
  final String fromUserPseudo;
  final String toUserId;
  final String toUserPseudo;
  final String status; // pending | accepted | refused | cancelled
  final DateTime? createdAt;
  final DateTime? respondedAt;

  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusRefused = 'refused';
  static const String statusCancelled = 'cancelled';

  ActivityInvitation({
    required this.id,
    required this.activityId,
    required this.activityTitle,
    required this.activityDay,
    required this.activityStartTime,
    required this.activityLocation,
    required this.fromUserId,
    required this.fromUserPseudo,
    required this.toUserId,
    required this.toUserPseudo,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  factory ActivityInvitation.fromMap(String id, Map<String, dynamic> map) {
    return ActivityInvitation(
      id: _parseString(id),
      activityId: _parseString(map['activityId']),
      activityTitle: _parseString(map['activityTitle']),
      activityDay: _parseString(map['activityDay']),
      activityStartTime: _parseString(map['activityStartTime']),
      activityLocation: _parseString(map['activityLocation']),
      fromUserId: _parseString(map['fromUserId']),
      fromUserPseudo: _parseString(map['fromUserPseudo']),
      toUserId: _parseString(map['toUserId']),
      toUserPseudo: _parseString(map['toUserPseudo']),
      status: _normalizeStatus(
        _parseString(map['status'], fallback: statusPending),
      ),
      createdAt: _toDateTime(map['createdAt']),
      respondedAt: _toDateTime(map['respondedAt']),
    );
  }

  factory ActivityInvitation.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return ActivityInvitation.fromMap(id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'activityTitle': activityTitle,
      'activityDay': activityDay,
      'activityStartTime': activityStartTime,
      'activityLocation': activityLocation,
      'fromUserId': fromUserId,
      'fromUserPseudo': fromUserPseudo,
      'toUserId': toUserId,
      'toUserPseudo': toUserPseudo,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  ActivityInvitation copyWith({
    String? id,
    String? activityId,
    String? activityTitle,
    String? activityDay,
    String? activityStartTime,
    String? activityLocation,
    String? fromUserId,
    String? fromUserPseudo,
    String? toUserId,
    String? toUserPseudo,
    String? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return ActivityInvitation(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      activityTitle: activityTitle ?? this.activityTitle,
      activityDay: activityDay ?? this.activityDay,
      activityStartTime: activityStartTime ?? this.activityStartTime,
      activityLocation: activityLocation ?? this.activityLocation,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserPseudo: fromUserPseudo ?? this.fromUserPseudo,
      toUserId: toUserId ?? this.toUserId,
      toUserPseudo: toUserPseudo ?? this.toUserPseudo,
      status: status != null ? _normalizeStatus(status) : this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  bool get isPending => status == statusPending;
  bool get isAccepted => status == statusAccepted;
  bool get isRefused => status == statusRefused;
  bool get isCancelled => status == statusCancelled;

  String get statusLabel {
    switch (status) {
      case statusAccepted:
        return 'Acceptée';
      case statusRefused:
        return 'Refusée';
      case statusCancelled:
        return 'Annulée';
      case statusPending:
      default:
        return 'En attente';
    }
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String _normalizeStatus(String value) {
    switch (value) {
      case statusAccepted:
        return statusAccepted;
      case statusRefused:
        return statusRefused;
      case statusCancelled:
        return statusCancelled;
      case statusPending:
      default:
        return statusPending;
    }
  }
}