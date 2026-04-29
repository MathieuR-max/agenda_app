import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final String ownerPseudo;
  final String visibility;
  final List<String> memberIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const String visibilityPrivate = 'private';
  static const String visibilityFriends = 'friends';

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.ownerPseudo,
    required this.visibility,
    required this.memberIds,
    this.createdAt,
    this.updatedAt,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: _parseString(id),
      name: _parseString(map['name']),
      description: _parseString(map['description']),
      ownerId: _parseString(map['ownerId']),
      ownerPseudo: _parseString(map['ownerPseudo']),
      visibility: _normalizeVisibility(
        _parseString(map['visibility'], fallback: visibilityPrivate),
      ),
      memberIds: _parseStringList(map['memberIds']),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'ownerPseudo': ownerPseudo,
      'visibility': visibility,
      'memberIds': memberIds,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  bool get isPrivate => visibility == visibilityPrivate;

  bool get isFriendsOnly => visibility == visibilityFriends;

  bool get hasMembers => memberIds.isNotEmpty;

  bool isMember(String userId) {
    return memberIds.contains(userId);
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is Iterable) {
      return value
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }

  static String _normalizeVisibility(String value) {
    switch (value) {
      case visibilityFriends:
        return visibilityFriends;
      case visibilityPrivate:
      default:
        return visibilityPrivate;
    }
  }
}