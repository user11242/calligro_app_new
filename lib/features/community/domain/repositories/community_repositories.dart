import '../models/community_models.dart';
import '../models/community_post.dart';

/// Posts, likes, comments, replies, saves, moderation.
/// Real: data/firestore_community_repository.dart · Tests: fakes/fake_community.dart
abstract interface class CommunityRepository {
  /// Feed for a tab. [followingIds] / [savedPostIds] are needed by the Friends / Saved tabs.
  Stream<List<CommunityPost>> watchFeed(
    CommunityFilter filter, {
    required String currentUserId,
    List<String> followingIds = const [],
    List<String> savedPostIds = const [],
  });
  Stream<List<CommunityPost>> watchPinnedPosts();
  Stream<List<CommunityPost>> watchUserPosts(String userId);

  /// Posts [userId] liked.
  Stream<List<CommunityPost>> watchLikedPosts(String userId);

  /// Posts with these ids (first 30 — Firestore whereIn limit); missing ones are simply absent.
  Stream<List<CommunityPost>> watchPostsByIds(List<String> postIds);

  /// Null when the post doesn't exist (deleted).
  Stream<CommunityPost?> watchPost(String postId);

  /// Uploads nothing: [imageUrls] are already uploaded. Also bumps the author's post count.
  Future<void> createPost(NewPost post, {required CommunitySession author, required List<String> imageUrls});
  Future<void> updatePost(String postId, {required String caption, required List<String> imageUrls});

  /// Deletes the post, its comments and replies, and fixes the author's post count.
  /// Returns the image URLs that should now be removed from storage.
  Future<List<String>> deletePost(CommunityPost post);

  /// Adds/removes [userId] in the post's likes and moves likesCount by exactly 1.
  Future<void> setLiked(String postId, {required String userId, required bool like});
  Future<void> setPinned(String postId, bool pinned);
  Future<void> setHidden(String postId, bool hidden);

  Stream<List<CommunityComment>> watchComments(String postId);
  Future<void> addComment(String postId, {required CommunitySession author, required String text});
  Future<void> editComment(String postId, String commentId, String text);
  Future<void> deleteComment(String postId, String commentId);

  Stream<List<CommunityComment>> watchReplies(String postId, String commentId);
  Future<void> addReply(String postId, String commentId, {required CommunitySession author, required String text});
  Future<void> editReply(String postId, String commentId, String replyId, String text);
  Future<void> deleteReply(String postId, String commentId, String replyId);

  Future<List<String>> getSavedPostIds(String userId);
  Stream<List<String>> watchSavedPostIds(String userId);
  Future<void> setSaved(String postId, {required String userId, required bool saved});

  Future<void> reportPost(CommunityPost post, {required String reporterId});
  Future<void> blockUser(String userId, {required String blockedUserId});
  Future<void> unblockUser(String userId, {required String blockedUserId});
  Stream<List<String>> watchBlockedUserIds(String userId);
}

/// Who follows whom.
abstract interface class FollowRepository {
  Stream<bool> watchIsFollowing({required String userId, required String targetUserId});
  Future<void> setFollowing({required String userId, required String targetUserId, required bool follow});
  Future<List<String>> getFollowingIds(String userId);
}

/// User lookups.
abstract interface class CommunityUserRepository {
  Future<List<CommunityUser>> getUsers(List<String> userIds);
  Future<List<CommunityUser>> searchByName(String query);
}

/// The signed-in user (role, name, photo) — read once per screen, not once per card.
abstract interface class CommunitySessionSource {
  Future<CommunitySession> currentSession();
}

/// Picks (and compresses) images from the device. Returns local file paths.
abstract interface class CommunityImagePicker {
  Future<List<String>> pickImages({required int maxCount});
}

/// Uploads post images / deletes them from storage.
abstract interface class CommunityMediaStorage {
  Future<List<String>> uploadPostImages(String userId, List<String> localPaths);
  Future<void> deleteByUrl(String url);
}

/// Machine translation of captions/comments.
abstract interface class CommunityTranslator {
  /// Language code of [text] ('ar', 'en', 'tr'…), or 'und' when unknown.
  Future<String> identifyLanguage(String text);
  Future<String> translate(String text, {required String targetLanguage});
}
