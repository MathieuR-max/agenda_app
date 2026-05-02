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
        _chatRepository = chatRepository ?? ChatRepository(db: db),
        _groupChatRepository =
            groupChatRepository ?? GroupChatRepository(db: db);

  String? get currentUserIdOrNull {
    final uid = AuthUser.uidOrNull?.trim();

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return uid;
  }

  Stream<List<String>> watchMyActivityIds() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<String>[]);
    }

    return _db
        .collectionGroup(FirestoreCollections.participants)
        .where('userId', isEqualTo: uid)
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
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(<String>[]);
    }

    return _db
        .collectionGroup(FirestoreCollections.members)
        .where('userId', isEqualTo: uid)
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

  Stream<int> watchActivityUnreadCount() {
    return _watchUnreadCountForIds(
      idsStream: watchMyActivityIds(),
      watchUnreadCount: _chatRepository.watchUnreadCount,
    );
  }

  Stream<int> watchGroupUnreadCount() {
    return _watchUnreadCountForIds(
      idsStream: watchMyGroupIds(),
      watchUnreadCount: _groupChatRepository.watchUnreadCount,
    );
  }

  Stream<int> watchTotalUnreadCount() {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(0);
    }

    final controller = StreamController<int>.broadcast();

    StreamSubscription<int>? activitySubscription;
    StreamSubscription<int>? groupSubscription;

    int activityTotal = 0;
    int groupTotal = 0;

    void emitTotal() {
      if (!controller.isClosed) {
        controller.add(activityTotal + groupTotal);
      }
    }

    activitySubscription = watchActivityUnreadCount().listen(
      (count) {
        activityTotal = count;
        emitTotal();
      },
      onError: (_) {
        activityTotal = 0;
        emitTotal();
      },
    );

    groupSubscription = watchGroupUnreadCount().listen(
      (count) {
        groupTotal = count;
        emitTotal();
      },
      onError: (_) {
        groupTotal = 0;
        emitTotal();
      },
    );

    controller.onCancel = () async {
      await activitySubscription?.cancel();
      await groupSubscription?.cancel();
    };

    return controller.stream;
  }

  Stream<int> _watchUnreadCountForIds({
    required Stream<List<String>> idsStream,
    required Stream<int> Function(String id) watchUnreadCount,
  }) {
    final uid = currentUserIdOrNull;

    if (uid == null) {
      return Stream.value(0);
    }

    final controller = StreamController<int>.broadcast();

    StreamSubscription<List<String>>? idsSubscription;
    final Map<String, StreamSubscription<int>> unreadSubscriptions = {};
    final Map<String, int> unreadCounts = {};

    void emitTotal() {
      final total = unreadCounts.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );

      if (!controller.isClosed) {
        controller.add(total);
      }
    }

    Future<void> replaceSubscriptions(List<String> ids) async {
      final nextIds = ids
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final existingIds = unreadSubscriptions.keys.toSet();

      for (final removedId in existingIds.difference(nextIds)) {
        await unreadSubscriptions[removedId]?.cancel();
        unreadSubscriptions.remove(removedId);
        unreadCounts.remove(removedId);
      }

      for (final id in nextIds.difference(existingIds)) {
        unreadSubscriptions[id] = watchUnreadCount(id).listen(
          (count) {
            unreadCounts[id] = count;
            emitTotal();
          },
          onError: (_) {
            unreadCounts[id] = 0;
            emitTotal();
          },
        );
      }

      emitTotal();
    }

    idsSubscription = idsStream.listen(
      (ids) {
        replaceSubscriptions(ids);
      },
      onError: (_) {
        if (!controller.isClosed) {
          controller.add(0);
        }
      },
    );

    controller.onCancel = () async {
      await idsSubscription?.cancel();

      for (final sub in unreadSubscriptions.values) {
        await sub.cancel();
      }

      unreadSubscriptions.clear();
      unreadCounts.clear();
    };

    return controller.stream;
  }
}