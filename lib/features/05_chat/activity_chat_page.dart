import 'package:agenda_app/services/current_user.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/models/activity.dart';
import 'package:agenda_app/models/activity_message.dart';
import 'package:agenda_app/repositories/chat_repository.dart';
import 'package:agenda_app/services/firestore/activity_firestore_service.dart';
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
  final ChatRepository chatRepository = ChatRepository();
  final UserFirestoreService userService = UserFirestoreService();
  final ActivityFirestoreService activityService = ActivityFirestoreService();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isSending = false;
  bool isMarkingRead = false;
  int lastMessageCount = 0;

  String? get currentUserId {
  final uid = AuthUser.uidOrNull?.trim();

  if (uid == null || uid.isEmpty) {
    return null;
  }

  return uid;
}

  @override
  void initState() {
    super.initState();
    _markChatAsRead();
  }

  bool _isCurrentUserMessage(ActivityMessage message) {
    final uid = currentUserId;
    return uid != null && message.senderId == uid;
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _markChatAsRead() async {
    if (isMarkingRead) return;

    isMarkingRead = true;

    try {
      await chatRepository.markActivityChatAsRead(widget.activity.id);
    } catch (_) {
      // Silencieux volontairement pour ne pas gêner l’UX.
    } finally {
      isMarkingRead = false;
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      final position = scrollController.position.maxScrollExtent;

      if (animated) {
        scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(position);
      }
    });
  }

  Future<void> _sendMessage(Activity currentActivity) async {
    final uid = currentUserId;
    final text = messageController.text.trim();

    final bool chatReadOnly = currentActivity.isCancelled ||
        currentActivity.isDone ||
        currentActivity.hasEnded;

    if (uid == null || uid.isEmpty) return;
    if (text.isEmpty || isSending || chatReadOnly) return;

    setState(() {
      isSending = true;
    });

    try {
      final senderPseudo = await userService.getCurrentUserPseudo();

      await chatRepository.sendMessage(
        activityId: currentActivity.id,
        senderId: uid,
        senderPseudo: senderPseudo,
        content: text,
      );

      messageController.clear();
      _scrollToBottom(animated: true);
      await _markChatAsRead();
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

  Widget _buildSystemMessage(ActivityMessage message) {
    final time = _formatTime(message.createdAt);

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
              message.content,
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

  Widget _buildUserMessage(ActivityMessage message) {
    final bool isMe = _isCurrentUserMessage(message);
    final String senderPseudo = message.senderPseudo;
    final String text = message.content;
    final String time = _formatTime(message.createdAt);

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

  Widget _buildMessage(ActivityMessage message) {
    if (message.isSystem) {
      return _buildSystemMessage(message);
    }

    return _buildUserMessage(message);
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Activity?>(
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

        if (activitySnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chat activité'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final currentActivity = activitySnapshot.data;

        if (currentActivity == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chat activité'),
            ),
            body: const Center(
              child: Text('Cette activité n’existe plus'),
            ),
          );
        }

        final bool chatReadOnly = currentActivity.isCancelled ||
            currentActivity.isDone ||
            currentActivity.hasEnded;

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
                child: StreamBuilder<List<ActivityMessage>>(
                  stream: chatRepository.streamMessages(currentActivity.id),
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

                    if (messages.length != lastMessageCount) {
                      lastMessageCount = messages.length;
                      _scrollToBottom();
                      _markChatAsRead();
                    }

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('Aucun message pour le moment'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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