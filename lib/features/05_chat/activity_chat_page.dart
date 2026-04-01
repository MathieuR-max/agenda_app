import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/core/constants/app_status.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
import 'package:agenda_app/services/firestore/chat_firestore_service.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';

class ActivityChatPage extends StatefulWidget {
  final Activity activity;

  const ActivityChatPage({
    super.key,
    required this.activity,
  });

  @override
  State<ActivityChatPage> createState() => _ActivityChatPageState();
}

class _ActivityChatPageState extends State<ActivityChatPage> {
  final ChatFirestoreService chatService = ChatFirestoreService();
  final UserFirestoreService userService = UserFirestoreService();
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final TextEditingController messageController = TextEditingController();

  bool isSending = false;

  bool _isSystemMessage(Map<String, dynamic> message) {
    return (message['type'] ?? '').toString() == MessageTypeValues.system;
  }

  bool _isCurrentUserMessage(Map<String, dynamic> message) {
    return (message['senderId'] ?? '').toString() == CurrentUser.id;
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime? date;

    if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is Timestamp) {
      date = timestamp.toDate();
    }

    if (date == null) return '';

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _sendMessage(Activity currentActivity) async {
    final text = messageController.text.trim();
    final bool chatReadOnly =
        currentActivity.isCancelled || currentActivity.isDone;

    if (text.isEmpty || isSending || chatReadOnly) return;

    setState(() {
      isSending = true;
    });

    try {
      final senderPseudo = await userService.getCurrentUserPseudo();

      await chatService.sendMessage(
        activityId: currentActivity.id,
        senderId: CurrentUser.id,
        senderPseudo: senderPseudo,
        text: text,
      );

      messageController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l’envoi : $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Widget _buildSystemMessage(Map<String, dynamic> message) {
    final text = (message['text'] ?? '').toString();
    final time = _formatTime(message['createdAt']);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessage(Map<String, dynamic> message) {
    final bool isMe = _isCurrentUserMessage(message);
    final String senderPseudo = (message['senderPseudo'] ?? '').toString();
    final String text = (message['text'] ?? '').toString();
    final String time = _formatTime(message['createdAt']);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && senderPseudo.trim().isNotEmpty) ...[
              Text(
                senderPseudo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blueGrey.shade700,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    if (_isSystemMessage(message)) {
      return _buildSystemMessage(message);
    }

    return _buildUserMessage(message);
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: activityService.watchActivity(widget.activity.id),
      builder: (context, activitySnapshot) {
        if (activitySnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chat activité'),
            ),
            body: Center(
              child: Text('Erreur activité : ${activitySnapshot.error}'),
            ),
          );
        }

        if (!activitySnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chat activité'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final activityData = activitySnapshot.data;

        if (activityData == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chat activité'),
            ),
            body: const Center(
              child: Text('Cette activité n’existe plus'),
            ),
          );
        }

        final currentActivity = Activity.fromMap(widget.activity.id, activityData);
        final bool chatReadOnly =
            currentActivity.isCancelled || currentActivity.isDone;

        return Scaffold(
          appBar: AppBar(
            title: Text('Chat • ${currentActivity.title}'),
          ),
          body: Column(
            children: [
              if (currentActivity.ownerPending)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange.shade100,
                  child: const Text(
                    'Cette activité recherche un organisateur.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (chatReadOnly)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade300,
                  child: Text(
                    currentActivity.isCancelled
                        ? 'Cette activité est annulée. Le chat est en lecture seule.'
                        : 'Cette activité est terminée. Le chat est en lecture seule.',
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: chatService.getMessages(currentActivity.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Erreur messages : ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('Aucun message pour le moment'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _buildMessage(message);
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          minLines: 1,
                          maxLines: 4,
                          enabled: !chatReadOnly && !isSending,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: chatReadOnly
                                ? 'Envoi désactivé'
                                : 'Écrire un message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: chatReadOnly
                            ? null
                            : () => _sendMessage(currentActivity),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        child: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}