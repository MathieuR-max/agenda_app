import 'package:flutter/material.dart';
import 'package:agenda_app/models/group_model.dart';
import 'package:agenda_app/repositories/groups_repository.dart';
import 'create_group_page.dart';
import 'group_detail_page.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = GroupsRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes groupes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateGroupPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<GroupModel>>(
        stream: repository.watchMyGroups(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur groupes : ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return const Center(
              child: Text('Vous n’avez pas encore de groupe.'),
            );
          }

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
                      group.name.isNotEmpty
                          ? group.name[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(group.name),
                  subtitle: Text(
                    group.description.isNotEmpty
                        ? group.description
                        : 'Aucune description',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailPage(groupId: group.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}