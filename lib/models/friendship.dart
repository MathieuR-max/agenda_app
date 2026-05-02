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
      requesterId: (map['requesterId'] ?? '').toString().trim(),
      requesterPseudo: (map['requesterPseudo'] ?? '').toString().trim(),
      addresseeId: (map['addresseeId'] ?? '').toString().trim(),
      addresseePseudo: (map['addresseePseudo'] ?? '').toString().trim(),
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
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  /// ===== GETTERS =====

  bool get isPending => status == statusPending;
  bool get isAccepted => status == statusAccepted;
  bool get isRefused => status == statusRefused;
  bool get isCancelled => status == statusCancelled;

  bool involvesUser(String userId) {
    final uid = userId.trim();
    return requesterId == uid || addresseeId == uid;
  }

  String otherUserId(String currentUserId) {
    final uid = currentUserId.trim();
    return requesterId == uid ? addresseeId : requesterId;
  }

  String otherUserPseudo(String currentUserId) {
    final uid = currentUserId.trim();
    final pseudo =
        requesterId == uid ? addresseePseudo : requesterPseudo;

    return pseudo.isNotEmpty ? pseudo : 'Utilisateur';
  }

  DateTime? get friendshipDate => respondedAt ?? createdAt;

  /// ===== COPY WITH (super utile pour UI / state) =====

  Friendship copyWith({
    String? status,
    DateTime? respondedAt,
  }) {
    return Friendship(
      id: id,
      requesterId: requesterId,
      requesterPseudo: requesterPseudo,
      addresseeId: addresseeId,
      addresseePseudo: addresseePseudo,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  /// ===== UTILS =====

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}