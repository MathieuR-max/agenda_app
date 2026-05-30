import 'package:flutter/material.dart';
import 'package:agenda_app/models/private_message.dart';
import 'package:agenda_app/repositories/private_chat_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';
import 'package:agenda_app/features/03_activities/create_activity_page.dart';

class PrivateChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserPseudo;
  final String otherUserId;

  const PrivateChatPage({
    super.key,
    required this.chatId,
    required this.otherUserPseudo,
    required this.otherUserId,
  });

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final PrivateChatRepository _chatRepository = PrivateChatRepository();
  final UserFirestoreService _userService = UserFirestoreService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  int _lastMessageCount = 0;
  bool _isMarkingRead = false;
  String _senderPseudo = '';

  String? get _currentUserId {
    final uid = AuthUser.uidOrNull?.trim();
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  @override
  void initState() {
    super.initState();
    _markAsRead();
    _loadPseudo();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPseudo() async {
    try {
      final pseudo = await _userService.getCurrentUserPseudo();
      if (mounted) {
        setState(() => _senderPseudo = pseudo);
      }
    } catch (_) {}
  }

  Future<void> _markAsRead() async {
    if (_isMarkingRead) return;
    _isMarkingRead = true;
    try {
      await _chatRepository.markAsRead(widget.chatId);
    } catch (_) {
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _chatRepository.sendMessage(
        chatId: widget.chatId,
        senderPseudo: _senderPseudo,
        text: text,
      );

      if (!mounted) return;

      _controller.clear();
      _scrollToBottom(animated: true);
      await _markAsRead();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'envoyer le message")),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position);
      }
    });
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildMessageBubble(PrivateMessage message) {
    final uid = _currentUserId;
    final isMine = uid != null && message.senderId == uid;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF00B4A6) : const Color(0xFFF1EFEB),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(
                message.senderPseudo.isNotEmpty
                    ? message.senderPseudo
                    : widget.otherUserPseudo,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF00B4A6),
                ),
              ),
            if (!isMine) const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(
                color: isMine ? Colors.white : const Color(0xFF1E1E1E),
                fontSize: 14,
              ),
            ),
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.7)
                      : const Color(0xFFA8A8A8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCta() {
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        final hour = now.hour;
        final minute = now.minute >= 30 ? 30 : 0;
        final timeSlot =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi',
            'Vendredi', 'Samedi', 'Dimanche'];
        final dayLabel = days[now.weekday - 1];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateActivityPage(
              day: dayLabel,
              hour: timeSlot,
              selectedDate: now,
              preselectedFriendIds: [widget.otherUserId],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFEB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discutez, puis organisez.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Créer une activité avec ${widget.otherUserPseudo} →',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF00B4A6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.event_available, color: Color(0xFF00B4A6), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.otherUserPseudo.trim().isNotEmpty
        ? widget.otherUserPseudo.trim()
        : 'Discussion';

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<PrivateMessage>>(
              stream: _chatRepository.streamMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur messages : ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                  _markAsRead();
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Démarrez la conversation avec $displayName',
                      style: const TextStyle(color: Color(0xFFA8A8A8)),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _buildMessageBubble(messages[index]),
                );
              },
            ),
          ),
          _buildActivityCta(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isSending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!_isSending) _sendMessage();
                      },
                      decoration: InputDecoration(
                        hintText: 'Écrire un message...',
                        hintStyle: const TextStyle(color: Color(0xFFA8A8A8)),
                        filled: true,
                        fillColor: const Color(0xFFF1EFEB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFF00B4A6), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF00B4A6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
