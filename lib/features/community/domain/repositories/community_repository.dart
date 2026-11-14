import 'dart:io';

import '../models/community_comment.dart';
import '../models/community_filter.dart';
import '../models/community_post.dart';

/// Core repository interface for posts, likes, comments, and reports.
abstract class CommunityRepository {
  /// Stream of community posts matching the selected filter.
  Stream<List<CommunityPost>> watchFeed({
    required CommunityFilter filter,
    required String currentUserId,
    List<String>? followingIds,
    List<String>? savedPostIds,
    int limit = 20,
  });

  /// Stream of pinned posts displayed at top of feed.
  Stream<List<CommunityPost>> watchPinnedPosts();

  /// Stream of posts created by a specific user.
  Stream<List<CommunityPost>> watchUserPosts(String userId, {String? currentUserId});

  /// Fetches a single post by ID.
  Future<CommunityPost?> getPost(String postId, {String? currentUserId});

  /// Creates a new post.
  Future<void> createPost({
    required CommunityPost post,
    List<File> images = const [],
  });

  /// Updates an existing post caption and image list.
  Future<void> updatePost({
    required String postId,
    required String newCaption,
    List<String>? keepImageUrls,
    List<File>? newImages,
    String? userId,
  });

  /// Deletes a post along with its images, comments, and counter updates.
  Future<void> deletePost({
    required String postId,
    required String authorId,
    required List<String> imageUrls,
  });

  /// Toggles like status on a post.
  Future<void> toggleLike({
    required String postId,
    required String currentUserId,
    required bool isLiked,
  });

  /// Real-time stream of comments under a post.
  Stream<List<CommunityComment>> watchComments(String postId);

  /// Adds a comment to a post.
  Future<void> addComment({
    required String postId,
    required CommunityComment comment,
  });

  /// Deletes a comment from a post.
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  });

  /// Reports a post.
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  });

  /// Blocks a user.
  Future<void> blockUser({
    required String currentUserId,
    required String blockedUserId,
  });

  /// Toggles saved post status for current user.
  Future<void> toggleSavePost({
    required String currentUserId,
    required String postId,
    required bool isSaved,
  });

  /// Fetches saved post IDs for current user.
  Future<List<String>> getSavedPostIds(String currentUserId);
}

