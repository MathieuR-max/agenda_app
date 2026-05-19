import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderPseudo;
  final String text;
  final String type;
  final DateTime? createdAt;

  static const String typeUser = 'text';
  static const String typeSystem = 'system';

  const PrivateMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderPseudo,
    required this.text,
    required this.type,
    required this.createdAt,
  });

  bool get isSystem => type == typeSystem;

  factory PrivateMessage.fromMap(
    String id,
    String chatId,
    Map<String, dynamic> data,
  ) {
    return PrivateMessage(
      id: id,
      chatId: chatId,
      senderId: (data['senderId'] ?? '').toString(),
      senderPseudo: (data['senderPseudo'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      type: (data['type'] ?? typeUser).toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderPseudo': senderPseudo,
      'text': text,
      'type': type,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
