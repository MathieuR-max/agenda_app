import 'package:flutter/material.dart';
import 'package:agenda_app/models/friendship.dart';
import 'package:agenda_app/repositories/friendship_repository.dart';
import 'package:agenda_app/services/firestore/friendship_firestore_service.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  late final FriendshipFirestoreService _friendshipService;
  late final FriendshipRepository _friendshipRepository;

  final Set<String> _busyRequestIds = <String>{};

  @override
  void initState() {
    super.initState();
    _friendshipService = FriendshipFirestoreService();
    _friendshipRepository = FriendshipRepository();
  }

  bool _isBusy(String friendshipId) => _busyRequestIds.contains(friendshipId);

  void _setBusy(String friendshipId, bool value) {
    if (!mounted) return;

    setState(() {
      if (value) {
        _busyRequestIds.add(friendshipId);
      } else {
        _busyRequestIds.remove(friendshipId);
      }
    });
  }

  Color _statusBackgroundColor(
    Friendship friendship, {
    required bool received,
  }) {
    if (!received && friendship.status == Friendship.statusPending) {
      return Colors.blue.shade100;
    }

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

  Color _statusTextColor(
    Friendship friendship, {
    required bool received,
  }) {
    if (!received && friendship.status == Friendship.statusPending) {
      return Colors.blue.shade800;
    }

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

  String _statusLabel(
    Friendship friendship, {
    required bool received,
  }) {
    if (!received && friendship.status == Friendship.statusPending) {
      return 'Envoyée';
    }

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
    Friendship friendship,
  ) async {
    final friendshipId = friendship.id.trim();

    if (friendshipId.isEmpty || _isBusy(friendshipId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’accepter cette demande'),
        ),
      );
      return;
    }

    _setBusy(friendshipId, true);

    try {
      final accepted = await _friendshipRepository.acceptFriendRequest(
        friendshipId,
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
    } finally {
      _setBusy(friendshipId, false);
    }
  }

  Future<void> _refuseRequest(
    BuildContext context,
    Friendship friendship,
  ) async {
    final friendshipId = friendship.id.trim();

    if (friendshipId.isEmpty || _isBusy(friendshipId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de refuser cette demande'),
        ),
      );
      return;
    }

    _setBusy(friendshipId, true);

    try {
      final refused = await _friendshipRepository.refuseFriendRequest(
        friendshipId,
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
    } finally {
      _setBusy(friendshipId, false);
    }
  }

  Widget _buildRequestCard({
    required BuildContext context,
    required Friendship friendship,
    required bool received,
  }) {
    final displayName = _displayName(friendship, received: received);
    final subtitle = received ? 'Demande reçue' : 'Demande envoyée';
    final isBusy = _isBusy(friendship.id);

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBackgroundColor(
                      friendship,
                      received: received,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(
                      friendship,
                      received: received,
                    ),
                    style: TextStyle(
                      color: _statusTextColor(
                        friendship,
                        received: received,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (isBusy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (received && friendship.isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isBusy
                          ? null
                          : () => _acceptRequest(
                                context,
                                friendship,
                              ),
                      child: const Text('Accepter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () => _refuseRequest(
                                context,
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
    required bool received,
    required String emptyLabel,
    required String errorLabel,
  }) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$errorLabel : ${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final requests = snapshot.data ?? [];

    debugPrint(
      'FRIEND REQUESTS ${received ? "received" : "sent"} '
      'currentUserId=${_friendshipService.currentUserId} '
      'count=${requests.length}',
    );

    final pendingCount = requests.where((r) => r.isPending).length;
    final acceptedCount = requests.where((r) => r.isAccepted).length;
    final refusedCount = requests.where((r) => r.isRefused).length;
    final cancelledCount = requests.where((r) => r.isCancelled).length;

    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                emptyLabel,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Utilisateur courant : ${_friendshipService.currentUserId}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: Column(
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
                  label: received ? 'En attente' : 'Envoyées',
                  count: pendingCount,
                  backgroundColor:
                      received ? Colors.orange.shade100 : Colors.blue.shade100,
                  textColor:
                      received ? Colors.orange.shade800 : Colors.blue.shade800,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Utilisateur courant : ${_friendshipService.currentUserId}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
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
                  friendship: friendship,
                  received: received,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'FRIEND REQUESTS PAGE currentUserId=${_friendshipService.currentUserId}',
    );

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
                    stream: _friendshipService.getReceivedFriendRequests(),
                    builder: (context, snapshot) {
                      return _buildRequestsTab(
                        context: context,
                        snapshot: snapshot,
                        received: true,
                        emptyLabel: 'Aucune demande reçue',
                        errorLabel: 'Erreur demandes reçues',
                      );
                    },
                  ),
                  StreamBuilder<List<Friendship>>(
                    stream: _friendshipService.getSentFriendRequests(),
                    builder: (context, snapshot) {
                      return _buildRequestsTab(
                        context: context,
                        snapshot: snapshot,
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