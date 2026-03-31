import 'package:flutter/material.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/services/firestore/friendship_firestore_service.dart';

class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({super.key});

  Color _statusBackgroundColor(Friendship friendship) {
    switch (friendship.status) {
      case Friendship.statusAccepted:
        return Colors.green.shade100;
      case Friendship.statusRefused:
        return Colors.red.shade100;
      case Friendship.statusCancelled:
        return Colors.grey.shade300;
      case Friendship.statusPending:
      default:
        return Colors.orange.shade100;
    }
  }

  Color _statusTextColor(Friendship friendship) {
    switch (friendship.status) {
      case Friendship.statusAccepted:
        return Colors.green.shade800;
      case Friendship.statusRefused:
        return Colors.red.shade800;
      case Friendship.statusCancelled:
        return Colors.grey.shade800;
      case Friendship.statusPending:
      default:
        return Colors.orange.shade800;
    }
  }

  String _statusLabel(Friendship friendship) {
    switch (friendship.status) {
      case Friendship.statusAccepted:
        return 'Acceptée';
      case Friendship.statusRefused:
        return 'Refusée';
      case Friendship.statusCancelled:
        return 'Annulée';
      case Friendship.statusPending:
      default:
        return 'En attente';
    }
  }

  Future<void> _acceptRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
  ) async {
    final accepted = await friendshipRepository.acceptFriendRequest(
      friendship.id,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? 'Demande d’ami acceptée'
              : 'Impossible d’accepter la demande',
        ),
      ),
    );
  }

  Future<void> _refuseRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
  ) async {
    final refused = await friendshipRepository.refuseFriendRequest(
      friendship.id,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          refused
              ? 'Demande d’ami refusée'
              : 'Impossible de refuser la demande',
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required BuildContext context,
    required FriendshipRepository friendshipRepository,
    required Friendship friendship,
    required bool received,
  }) {
    final displayName = received
        ? (friendship.requesterPseudo.isNotEmpty
            ? friendship.requesterPseudo
            : friendship.requesterId)
        : (friendship.addresseePseudo.isNotEmpty
            ? friendship.addresseePseudo
            : friendship.addresseeId);

    final subtitle = received ? 'Demande reçue' : 'Demande envoyée';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _statusBackgroundColor(friendship),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(friendship),
                style: TextStyle(
                  color: _statusTextColor(friendship),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (received && friendship.isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptRequest(
                        context,
                        friendshipRepository,
                        friendship,
                      ),
                      child: const Text('Accepter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _refuseRequest(
                        context,
                        friendshipRepository,
                        friendship,
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendshipService = FriendshipFirestoreService();
    final friendshipRepository = FriendshipRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes d’amis'),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Reçues'),
                Tab(text: 'Envoyées'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  StreamBuilder<List<Friendship>>(
                    stream: friendshipService.getReceivedFriendRequests(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erreur demandes reçues : ${snapshot.error}',
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final requests = snapshot.data ?? [];

                      if (requests.isEmpty) {
                        return const Center(
                          child: Text('Aucune demande reçue'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final friendship = requests[index];
                          return _buildRequestCard(
                            context: context,
                            friendshipRepository: friendshipRepository,
                            friendship: friendship,
                            received: true,
                          );
                        },
                      );
                    },
                  ),
                  StreamBuilder<List<Friendship>>(
                    stream: friendshipService.getSentFriendRequests(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erreur demandes envoyées : ${snapshot.error}',
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final requests = snapshot.data ?? [];

                      if (requests.isEmpty) {
                        return const Center(
                          child: Text('Aucune demande envoyée'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final friendship = requests[index];
                          return _buildRequestCard(
                            context: context,
                            friendshipRepository: friendshipRepository,
                            friendship: friendship,
                            received: false,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}