import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final String ownerPseudo;
  final String visibility;
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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  bool get isPrivate => visibility == visibilityPrivate;

  bool get isFriendsOnly => visibility == visibilityFriends;

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