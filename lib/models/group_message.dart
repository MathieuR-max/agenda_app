import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderPseudo;
  final String type; // user | system
  final DateTime? createdAt;

  static const String typeUser = 'user';
  static const String typeSystem = 'system';

  GroupMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderPseudo,
    required this.type,
    this.createdAt,
  });

  factory GroupMessage.fromMap(String id, Map<String, dynamic> map) {
    return GroupMessage(
      id: id,
      text: (map['text'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      senderPseudo: (map['senderPseudo'] ?? '').toString(),
      type: (map['type'] ?? typeUser).toString(),
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'senderPseudo': senderPseudo,
      'type': type,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}