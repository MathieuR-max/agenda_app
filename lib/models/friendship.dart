import 'package:cloud_firestore/cloud_firestore.dart';

class Friendship {
  final String id;
  final String requesterId;
  final String requesterPseudo;
  final String addresseeId;
  final String addresseePseudo;
  final String status; // pending | accepted | refused | cancelled
  final DateTime? createdAt;
  final DateTime? respondedAt;

  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusRefused = 'refused';
  static const String statusCancelled = 'cancelled';

  Friendship({
    required this.id,
    required this.requesterId,
    required this.requesterPseudo,
    required this.addresseeId,
    required this.addresseePseudo,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  factory Friendship.fromMap(String id, Map<String, dynamic> map) {
    return Friendship(
      id: id,
      requesterId: (map['requesterId'] ?? '').toString(),
      requesterPseudo: (map['requesterPseudo'] ?? '').toString(),
      addresseeId: (map['addresseeId'] ?? '').toString(),
      addresseePseudo: (map['addresseePseudo'] ?? '').toString(),
      status: (map['status'] ?? statusPending).toString(),
      createdAt: _toDateTime(map['createdAt']),
      respondedAt: _toDateTime(map['respondedAt']),
    );
  }

  factory Friendship.fromFirestore(Map<String, dynamic> data, String id) {
    return Friendship.fromMap(id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'requesterId': requesterId,
      'requesterPseudo': requesterPseudo,
      'addresseeId': addresseeId,
      'addresseePseudo': addresseePseudo,
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