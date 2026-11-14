import '../models/community_user.dart';

/// Repository interface for user lookups, likers, and user search.
abstract class UserRepository {
  /// Fetches a user's community profile.
  Future<CommunityUser> getUser(String userId);

  /// Fetches multiple users by ID (e.g. for likers list).
  Future<List<CommunityUser>> getUsers(List<String> userIds);

  /// Searches users by name or query string.
  Future<List<CommunityUser>> searchUsers(String query, {int limit = 20});
}

