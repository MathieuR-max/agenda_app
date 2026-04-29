import 'package:flutter/material.dart';
import 'package:agenda_app/models/group_model.dart';
import 'package:agenda_app/repositories/group_chat_repository.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'create_group_page.dart';
import 'group_detail_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late final GroupsRepository _repository;
  late final GroupChatRepository _groupChatRepository;

  @override
  void initState() {
    super.initState();
    _repository = GroupsRepository();
    _groupChatRepository = GroupChatRepository();
  }

  String _visibilityLabel(GroupModel group) {
    if (group.isFriendsOnly) {
      return 'Entre amis';
    }
    return 'Privé';
  }

  Color _visibilityChipBackground(GroupModel group) {
    if (group.isFriendsOnly) {
      return Colors.green.shade100;
    }
    return Colors.blueGrey.shade100;
  }

  Color _visibilityChipTextColor(GroupModel group) {
    if (group.isFriendsOnly) {
      return Colors.green.shade800;
    }
    return Colors.blueGrey.shade800;
  }

  Future<void> _openCreateGroupPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateGroupPage(),
      ),
    );
  }

  Future<void> _openGroupDetailPage(
    BuildContext context,
    GroupModel group,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(groupId: group.id),
      ),
    );
  }

  Widget _buildUnreadTrailing(String groupId) {
    return StreamBuilder<int>(
      stream: _groupChatRepository.watchUnreadCount(groupId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        if (unreadCount <= 0) {
          return const Icon(Icons.chevron_right);
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              label: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
              ),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Vous n’avez pas encore de groupe.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openCreateGroupPage(context),
              icon: const Icon(Icons.add),
              label: const Text('Créer un groupe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList(BuildContext context, List<GroupModel> groups) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
              ),
            ),
            title: Text(group.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  group.description.isNotEmpty
                      ? group.description
                      : 'Aucune description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _visibilityChipBackground(group),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _visibilityLabel(group),
                    style: TextStyle(
                      color: _visibilityChipTextColor(group),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: _buildUnreadTrailing(group.id),
            onTap: () => _openGroupDetailPage(context, group),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes groupes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateGroupPage(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<GroupModel>>(
        stream: _repository.watchMyGroups(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur groupes : ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final groups = snapshot.data ?? <GroupModel>[];

          if (groups.isEmpty) {
            return _buildEmptyState(context);
          }

          return _buildGroupsList(context, groups);
        },
      ),
    );
  }
}