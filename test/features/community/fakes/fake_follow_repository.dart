import 'dart:async';

import 'package:calligro_app/features/community/domain/repositories/follow_repository.dart';

class FakeFollowRepository implements FollowRepository {
  final Map<String, Set<String>> followingMap = {};
  final Map<String, Set<String>> followersMap = {};

  final _streamController = StreamController<bool>.broadcast();

  @override
  Stream<bool> watchIsFollowing({required String currentUserId, required String targetUserId}) {
    final isFollowing = followingMap[currentUserId]?.contains(targetUserId) ?? false;
    return Stream.value(isFollowing);
  }

  @override
  Future<void> followUser({required String currentUserId, required String targetUserId}) async {
    followingMap.putIfAbsent(currentUserId, () => {}).add(targetUserId);
    followersMap.putIfAbsent(targetUserId, () => {}).add(currentUserId);
    _streamController.add(true);
  }

  @override
  Future<void> unfollowUser({required String currentUserId, required String targetUserId}) async {
    followingMap[currentUserId]?.remove(targetUserId);
    followersMap[targetUserId]?.remove(currentUserId);
    _streamController.add(false);
  }

  @override
  Future<List<String>> getFollowingIds(String currentUserId) async {
    return followingMap[currentUserId]?.toList() ?? [];
  }

  @override
  Future<List<String>> getFollowerIds(String currentUserId) async {
    return followersMap[currentUserId]?.toList() ?? [];
  }
}

