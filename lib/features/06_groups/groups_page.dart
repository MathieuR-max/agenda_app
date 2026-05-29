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
    if (group.isFriendsOnly) return const Color(0xFFECFDF4);
    return const Color(0xFFF1EFEB);
  }

  Color _visibilityChipTextColor(GroupModel group) {
    if (group.isFriendsOnly) return const Color(0xFF34C759);
    return const Color(0xFF6F6F6F);
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 64, color: Color(0xFFA8A8A8)),
            const SizedBox(height: 16),
            const Text(
              "Vous n’avez pas encore de groupe.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openCreateGroupPage(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4A6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              ),
              icon: const Icon(Icons.add),
              label: const Text("Créer un groupe", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList(BuildContext context, List<GroupModel> groups) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];

        return GestureDetector(
          onTap: () => _openGroupDetailPage(context, group),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB8ECE6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00B4A6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StreamBuilder<int>(
                          stream: _groupChatRepository.watchUnreadCount(group.id),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data ?? 0;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E1E1E),
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Badge(
                                    label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                                    child: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF6F6F6F)),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          group.description.isNotEmpty ? group.description : 'Aucune description',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _visibilityChipBackground(group),
                            borderRadius: BorderRadius.circular(20),
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
                  ),
                ],
              ),
            ),
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
        backgroundColor: const Color(0xFF00B4A6),
        foregroundColor: Colors.white,
        elevation: 0,
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