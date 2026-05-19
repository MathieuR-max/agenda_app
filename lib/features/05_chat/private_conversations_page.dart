import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agenda_app/repositories/private_chat_repository.dart';
import 'package:agenda_app/services/current_user.dart';
import 'package:agenda_app/services/firestore/user_firestore_service.dart';
import 'private_chat_page.dart';

class PrivateConversationsPage extends StatelessWidget {
  const PrivateConversationsPage({super.key});

  String? get _currentUid {
    final uid = AuthUser.uidOrNull?.trim();
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final d = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$d/$mo';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages privés')),
        body: const Center(child: Text('Utilisateur non connecté')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages privés')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('private_chats')
            .where('participantIds', arrayContains: uid)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune conversation pour l\'instant',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final chatId = doc.id;
              final participantIds = List<String>.from(
                data['participantIds'] as List? ?? [],
              );
              final otherUid = participantIds.firstWhere(
                (id) => id != uid,
                orElse: () => '',
              );
              final lastText = (data['lastMessageText'] ?? '').toString();
              final lastTs = data['lastMessageAt'] as Timestamp?;

              return _ConversationTile(
                chatId: chatId,
                otherUid: otherUid,
                lastText: lastText,
                lastDate: _formatDate(lastTs),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String chatId;
  final String otherUid;
  final String lastText;
  final String lastDate;

  const _ConversationTile({
    required this.chatId,
    required this.otherUid,
    required this.lastText,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: otherUid.isNotEmpty
          ? UserFirestoreService().getUserById(otherUid)
          : Future.value(null),
      builder: (context, userSnapshot) {
        final pseudo = userSnapshot.data != null
            ? (userSnapshot.data!['pseudo'] ?? '').toString().trim()
            : otherUid;

        final displayName = pseudo.isNotEmpty ? pseudo : 'Utilisateur';
        final initial =
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

        final subtitle = lastText.isNotEmpty
            ? (lastText.length > 40
                ? '${lastText.substring(0, 40)}…'
                : lastText)
            : 'Nouvelle conversation';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: StreamBuilder<int>(
            stream: PrivateChatRepository().watchUnreadCount(chatId),
            builder: (context, unreadSnapshot) {
              final unreadCount = unreadSnapshot.data ?? 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Colors.indigo.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lastDate.isNotEmpty)
                      Text(
                        lastDate,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Badge(
                        label: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                        ),
                        child: const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrivateChatPage(
                        chatId: chatId,
                        otherUserPseudo: displayName,
                      ),
                    ),
                  );
                  await PrivateChatRepository().markAsRead(chatId);
                },
              );
            },
          ),
        );
      },
    );
  }
}
