class FriendUser {
  final String friendshipId;
  final String userId;
  final String pseudo;
  final DateTime? friendsSince;

  FriendUser({
    required this.friendshipId,
    required this.userId,
    required this.pseudo,
    this.friendsSince,
  });
}