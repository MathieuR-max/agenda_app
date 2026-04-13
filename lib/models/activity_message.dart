import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityMessage {
  final String id;
  final String activityId;
  final String senderId;
  final String senderPseudo;
  final String content;
  final String type;
  final DateTime? createdAt;

  const ActivityMessage({
    required this.id,
    required this.activityId,
    required this.senderId,
    required this.senderPseudo,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  bool get isSystem => type == 'system';

  factory ActivityMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return ActivityMessage(
      id: doc.id,
      activityId: doc.reference.parent.parent?.id ?? '',
      senderId: (data['senderId'] ?? '').toString(),
      senderPseudo: (data['senderPseudo'] ?? '').toString(),
      content: (data['text'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}