import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/repositories/chat_repository.dart';
import 'package:agenda_app/repositories/group_chat_repository.dart';
import 'package:agenda_app/services/current_user.dart';

class MessageBadgeRepository {
  final FirebaseFirestore _db;
  final ChatRepository _chatRepository;
  final GroupChatRepository _groupChatRepository;

  MessageBadgeRepository({
    FirebaseFirestore? db,
    ChatRepository? chatRepository,
    GroupChatRepository? groupChatRepository,
  })  : _db = db ?? FirebaseFirestore.instance,
        _chatRepository = chatRepository ?? ChatRepository(),
        _groupChatRepository = groupChatRepository ?? GroupChatRepository();

  String get currentUserId => CurrentUser.id.trim();

  Stream<List<String>> watchMyActivityIds() {
    if (currentUserId.isEmpty) {
      return Stream.value(<String>[]);
    }

    return _db
        .collectionGroup(FirestoreCollections.participants)
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      final ids = snapshot.docs
          .map((doc) => (doc.reference.parent.parent?.id ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      ids.sort();
      return ids;
    });
  }

  Stream<List<String>> watchMyGroupIds() {
    if (currentUserId.isEmpty) {
      return Stream.value(<String>[]);
    }

    return _db
        .collectionGroup(FirestoreCollections.members)
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      final ids = snapshot.docs
          .map((doc) => (doc.reference.parent.parent?.id ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      ids.sort();
      return ids;
    });
  }

  Stream<int> watchTotalUnreadCount() {
    if (currentUserId.isEmpty) {
      return Stream.value(0);
    }

    final controller = StreamController<int>.broadcast();

    StreamSubscription<List<String>>? activityIdsSubscription;
    StreamSubscription<List<String>>? groupIdsSubscription;

    final Map<String, StreamSubscription<int>> activityUnreadSubscriptions = {};
    final Map<String, StreamSubscription<int>> groupUnreadSubscriptions = {};

    final Map<String, int> activityUnreadCounts = {};
    final Map<String, int> groupUnreadCounts = {};

    void emitTotal() {
      final activityTotal =
          activityUnreadCounts.values.fold<int>(0, (sum, value) => sum + value);
      final groupTotal =
          groupUnreadCounts.values.fold<int>(0, (sum, value) => sum + value);

      final total = activityTotal + groupTotal;

      if (!controller.isClosed) {
        controller.add(total);
      }
    }

    Future<void> replaceActivitySubscriptions(List<String> activityIds) async {
      final nextIds = activityIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
      final existingIds = activityUnreadSubscriptions.keys.toSet();

      for (final removedId in existingIds.difference(nextIds)) {
        await activityUnreadSubscriptions[removedId]?.cancel();
        activityUnreadSubscriptions.remove(removedId);
        activityUnreadCounts.remove(removedId);
      }

      for (final activityId in nextIds.difference(existingIds)) {
        activityUnreadSubscriptions[activityId] =
            _chatRepository.watchUnreadCount(activityId).listen(
          (count) {
            activityUnreadCounts[activityId] = count;
            emitTotal();
          },
          onError: (_) {
            activityUnreadCounts[activityId] = 0;
            emitTotal();
          },
        );
      }

      emitTotal();
    }

    Future<void> replaceGroupSubscriptions(List<String> groupIds) async {
      final nextIds = groupIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
      final existingIds = groupUnreadSubscriptions.keys.toSet();

      for (final removedId in existingIds.difference(nextIds)) {
        await groupUnreadSubscriptions[removedId]?.cancel();
        groupUnreadSubscriptions.remove(removedId);
        groupUnreadCounts.remove(removedId);
      }

      for (final groupId in nextIds.difference(existingIds)) {
        groupUnreadSubscriptions[groupId] =
            _groupChatRepository.watchUnreadCount(groupId).listen(
          (count) {
            groupUnreadCounts[groupId] = count;
            emitTotal();
          },
          onError: (_) {
            groupUnreadCounts[groupId] = 0;
            emitTotal();
          },
        );
      }

      emitTotal();
    }

    activityIdsSubscription = watchMyActivityIds().listen(
      (activityIds) {
        replaceActivitySubscriptions(activityIds);
      },
      onError: (_) {
        if (!controller.isClosed) {
          controller.add(0);
        }
      },
    );

    groupIdsSubscription = watchMyGroupIds().listen(
      (groupIds) {
        replaceGroupSubscriptions(groupIds);
      },
      onError: (_) {
        if (!controller.isClosed) {
          controller.add(0);
        }
      },
    );

    controller.onCancel = () async {
      await activityIdsSubscription?.cancel();
      await groupIdsSubscription?.cancel();

      for (final sub in activityUnreadSubscriptions.values) {
        await sub.cancel();
      }

      for (final sub in groupUnreadSubscriptions.values) {
        await sub.cancel();
      }

      activityUnreadSubscriptions.clear();
      groupUnreadSubscriptions.clear();
      activityUnreadCounts.clear();
      groupUnreadCounts.clear();
    };

    return controller.stream;
  }
}