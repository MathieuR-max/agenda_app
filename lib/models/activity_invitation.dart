import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityInvitation {
  final String id;
  final String activityId;
  final String activityTitle;
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
      id: id,
      activityId: (map['activityId'] ?? '').toString(),
      activityTitle: (map['activityTitle'] ?? '').toString(),
      activityDay: (map['activityDay'] ?? '').toString(),
      activityStartTime: (map['activityStartTime'] ?? '').toString(),
      activityLocation: (map['activityLocation'] ?? '').toString(),
      fromUserId: (map['fromUserId'] ?? '').toString(),
      fromUserPseudo: (map['fromUserPseudo'] ?? '').toString(),
      toUserId: (map['toUserId'] ?? '').toString(),
      toUserPseudo: (map['toUserPseudo'] ?? '').toString(),
      status: (map['status'] ?? statusPending).toString(),
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
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
    };
  }

  bool get isPending => status == statusPending;
  bool get isAccepted => status == statusAccepted;
  bool get isRefused => status == statusRefused;
  bool get isCancelled => status == statusCancelled;

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}