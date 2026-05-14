import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agenda_app/core/constants/firestore_collections.dart';
import 'package:agenda_app/repositories/chat_repository.dart';
import 'package:agenda_app/repositories/group_chat_repository.dart';
import 'package:agenda_app/services/current_user.dart';

class MessageBadgeRepository {
  final FirebaseFirestore _db;
  final ChatRepository _chatRepository;
  final GroupChatRepository _groupChatRepository;

  // Cached broadcast streams — prevents double-subscription when NavigationDestination
  // renders both icon and selectedIcon from the same repository instance.
  Stream<int>? _activityUnreadCountCache;
  Stream<int>? _groupUnreadCountCache;

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

    final joinedActivitiesStream = _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection('joined_activities')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => (doc.data()['activityId'] ?? doc.id).toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    });

    final ownerStream = _db
        .collection(FirestoreCollections.activities)
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    });

    final controller = StreamController<List<String>>.broadcast();

    StreamSubscription<Set<String>>? joinedSub;
    StreamSubscription<Set<String>>? ownerSub;

    Set<String> joinedIds = {};
    Set<String> ownerIds = {};
    List<String>? lastEmittedIds; // dedup: skip if merged list unchanged

    void emit() {
      if (controller.isClosed) return;

      final merged = {...joinedIds, ...ownerIds}.toList()..sort();

      // Skip redundant emission when IDs haven't changed (e.g. both sources fire on init).
      if (lastEmittedIds != null &&
          lastEmittedIds!.length == merged.length &&
          lastEmittedIds!.every(merged.contains)) {
        return;
      }
      lastEmittedIds = merged;

      debugPrint('[MessageBadgeRepository] watchMyActivityIds: $merged');
      controller.add(merged);
    }

    joinedSub = joinedActivitiesStream.listen(
      (ids) {
        joinedIds = ids;
        emit();
      },
      onError: (error) {
        debugPrint(
          '[MessageBadgeRepository] joinedActivitiesStream error: $error',
        );
        joinedIds = {};
        emit();
      },
    );

    ownerSub = ownerStream.listen(
      (ids) {
        ownerIds = ids;
        emit();
      },
      onError: (error) {
        debugPrint('[MessageBadgeRepository] ownerStream error: $error');
        ownerIds = {};
        emit();
      },
    );

    controller.onCancel = () async {
      await joinedSub?.cancel();
      await ownerSub?.cancel();
    };

    return controller.stream;
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
    return _activityUnreadCountCache ??= _watchUnreadCountForIds(
      idsStream: watchMyActivityIds(),
      watchUnreadCount: _chatRepository.watchUnreadCount,
    ).map((n) {
      debugPrint('[MessageBadgeRepository] watchActivityUnreadCount: $n');
      return n;
    });
  }

  Stream<int> watchGroupUnreadCount() {
    return _groupUnreadCountCache ??= _watchUnreadCountForIds(
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
    int? lastEmittedTotal;

    void emitTotal() {
      if (controller.isClosed) return;
      final total = activityTotal + groupTotal;
      if (total == lastEmittedTotal) return;
      lastEmittedTotal = total;
      controller.add(total);
    }

    activitySubscription = watchActivityUnreadCount().listen(
      (count) {
        activityTotal = count;
        emitTotal();
      },
      onError: (error) {
        debugPrint(
          '[MessageBadgeRepository] watchActivityUnreadCount error: $error',
        );
        activityTotal = 0;
        emitTotal();
      },
    );

    groupSubscription = watchGroupUnreadCount().listen(
      (count) {
        groupTotal = count;
        emitTotal();
      },
      onError: (error) {
        debugPrint(
          '[MessageBadgeRepository] watchGroupUnreadCount error: $error',
        );
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

    int? lastEmitted;

    void emitTotal() {
      if (controller.isClosed) return;
      final total = unreadCounts.values.fold<int>(0, (acc, v) => acc + v);
      // Skip redundant emissions to avoid unnecessary widget rebuilds.
      if (total == lastEmitted) return;
      lastEmitted = total;
      controller.add(total);
    }

    // Serialisation guard: replaceSubscriptions is async; if idsStream emits
    // again before the previous call completes, we save the latest IDs and
    // process them once the current run finishes (drop intermediates).
    bool replacing = false;
    List<String>? queuedIds;

    Future<void> replaceSubscriptions(List<String> ids) async {
      if (controller.isClosed) return;

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

      // Guard after the first await: controller may have been cancelled while
      // we were awaiting the cancellations above.
      if (controller.isClosed) return;

      for (final id in nextIds.difference(existingIds)) {
        unreadSubscriptions[id] = watchUnreadCount(id).listen(
          (count) {
            unreadCounts[id] = count;
            emitTotal();
          },
          onError: (error) {
            debugPrint(
              '[MessageBadgeRepository] unread error id=$id error=$error',
            );
            unreadCounts[id] = 0;
            emitTotal();
          },
        );
      }

      emitTotal();
    }

    Future<void> runReplacement(List<String> ids) async {
      replacing = true;
      try {
        await replaceSubscriptions(ids);
      } finally {
        replacing = false;
        // If a new emission arrived while we were replacing, process it now.
        if (queuedIds != null && !controller.isClosed) {
          final next = queuedIds!;
          queuedIds = null;
          await runReplacement(next);
        }
      }
    }

    idsSubscription = idsStream.listen(
      (ids) {
        if (replacing) {
          // Drop intermediate values; only the latest matters.
          queuedIds = ids;
        } else {
          runReplacement(ids);
        }
      },
      onError: (error) {
        debugPrint('[MessageBadgeRepository] idsStream error: $error');
        if (!controller.isClosed) controller.add(0);
      },
    );

    controller.onCancel = () async {
      // Cancel IDs source first to stop new replaceSubscriptions from starting.
      await idsSubscription?.cancel();
      // Then cancel all active unread listeners.
      for (final sub in unreadSubscriptions.values) {
        await sub.cancel();
      }
      unreadSubscriptions.clear();
      unreadCounts.clear();
    };

    return controller.stream;
  }
}
