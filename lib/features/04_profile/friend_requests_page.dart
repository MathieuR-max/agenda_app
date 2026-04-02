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

  String _displayName(Friendship friendship, {required bool received}) {
    final pseudo = received
        ? friendship.requesterPseudo.trim()
        : friendship.addresseePseudo.trim();

    final id = received
        ? friendship.requesterId.trim()
        : friendship.addresseeId.trim();

    if (pseudo.isNotEmpty) return pseudo;
    if (id.isNotEmpty) return id;
    return 'Utilisateur';
  }

  Widget _buildSummaryChip({
    required String label,
    required int count,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label : $count',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _acceptRequest(
    BuildContext context,
    FriendshipRepository friendshipRepository,
    Friendship friendship,
  ) async {
    if (friendship.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’accepter cette demande'),
        ),
      );
      return;
    }

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
    if (friendship.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de refuser cette demande'),
        ),
      );
      return;
    }

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
    final displayName = _displayName(friendship, received: received);
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

  Widget _buildRequestsTab({
    required BuildContext context,
    required AsyncSnapshot<List<Friendship>> snapshot,
    required FriendshipRepository friendshipRepository,
    required bool received,
    required String emptyLabel,
    required String errorLabel,
  }) {
    if (snapshot.hasError) {
      return Center(
        child: Text('$errorLabel : ${snapshot.error}'),
      );
    }

    if (!snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final requests = snapshot.data ?? [];
    final pendingCount = requests.where((r) => r.isPending).length;
    final acceptedCount = requests.where((r) => r.isAccepted).length;
    final refusedCount = requests.where((r) => r.isRefused).length;
    final cancelledCount = requests.where((r) => r.isCancelled).length;

    if (requests.isEmpty) {
      return Center(
        child: Text(emptyLabel),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSummaryChip(
                label: 'En attente',
                count: pendingCount,
                backgroundColor: Colors.orange.shade100,
                textColor: Colors.orange.shade800,
              ),
              _buildSummaryChip(
                label: 'Acceptées',
                count: acceptedCount,
                backgroundColor: Colors.green.shade100,
                textColor: Colors.green.shade800,
              ),
              _buildSummaryChip(
                label: 'Refusées',
                count: refusedCount,
                backgroundColor: Colors.red.shade100,
                textColor: Colors.red.shade800,
              ),
              _buildSummaryChip(
                label: 'Annulées',
                count: cancelledCount,
                backgroundColor: Colors.grey.shade300,
                textColor: Colors.grey.shade800,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final friendship = requests[index];
              return _buildRequestCard(
                context: context,
                friendshipRepository: friendshipRepository,
                friendship: friendship,
                received: received,
              );
            },
          ),
        ),
      ],
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
                      return _buildRequestsTab(
                        context: context,
                        snapshot: snapshot,
                        friendshipRepository: friendshipRepository,
                        received: true,
                        emptyLabel: 'Aucune demande reçue',
                        errorLabel: 'Erreur demandes reçues',
                      );
                    },
                  ),
                  StreamBuilder<List<Friendship>>(
                    stream: friendshipService.getSentFriendRequests(),
                    builder: (context, snapshot) {
                      return _buildRequestsTab(
                        context: context,
                        snapshot: snapshot,
                        friendshipRepository: friendshipRepository,
                        received: false,
                        emptyLabel: 'Aucune demande envoyée',
                        errorLabel: 'Erreur demandes envoyées',
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