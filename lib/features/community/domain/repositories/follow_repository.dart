/// Repository interface for user follow relationships.
abstract class FollowRepository {
  /// Returns a stream of follow state between current user and target user.
  Stream<bool> watchIsFollowing({required String currentUserId, required String targetUserId});

  /// Follows target user.
  Future<void> followUser({required String currentUserId, required String targetUserId});

  /// Unfollows target user.
  Future<void> unfollowUser({required String currentUserId, required String targetUserId});

  /// Fetches following user IDs for feed filtering.
  Future<List<String>> getFollowingIds(String currentUserId);

  /// Fetches follower IDs.
  Future<List<String>> getFollowerIds(String currentUserId);
}

