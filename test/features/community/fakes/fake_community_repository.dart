import 'dart:async';
import 'dart:io';

import 'package:calligro_app/features/community/domain/models/community_comment.dart';
import 'package:calligro_app/features/community/domain/models/community_filter.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:calligro_app/features/community/domain/repositories/community_repository.dart';

/// Fast, in-memory fake implementation of CommunityRepository for unit and widget tests.
class FakeCommunityRepository implements CommunityRepository {
  final List<CommunityPost> posts = [];
  final Map<String, List<CommunityComment>> commentsByPost = {};
  final Set<String> savedPosts = {};
  final Set<String> blockedUsers = {};
  final List<Map<String, String>> reports = [];

  bool simulateNetworkErrorOnLike = false;
  bool simulateNetworkErrorOnCreate = false;

  final _feedController = StreamController<List<CommunityPost>>.broadcast();
  final Map<String, StreamController<List<CommunityComment>>> _commentControllers = {};

  void _notifyFeed() {
    if (!_feedController.isClosed) {
      _feedController.add(List.unmodifiable(posts));
    }
  }

  void _notifyComments(String postId) {
    final list = commentsByPost[postId] ?? [];
    if (_commentControllers.containsKey(postId) && !_commentControllers[postId]!.isClosed) {
      _commentControllers[postId]!.add(List.unmodifiable(list));
    }
  }

  @override
  Stream<List<CommunityPost>> watchFeed({
    required CommunityFilter filter,
    required String currentUserId,
    List<String>? followingIds,
    List<String>? savedPostIds,
    int limit = 20,
  }) {
    List<CommunityPost> computeFiltered() {
      List<CommunityPost> filtered = List.of(posts);
      switch (filter) {
        case CommunityFilter.myPosts:
          return filtered.where((p) => p.authorId == currentUserId).toList();
        case CommunityFilter.teachers:
          return filtered.where((p) => p.isTeacher).toList();
        case CommunityFilter.friends:
          if (followingIds != null && followingIds.isNotEmpty) {
            return filtered.where((p) => followingIds.contains(p.authorId)).toList();
          }
          return [];
        case CommunityFilter.saved:
          return filtered.where((p) => savedPosts.contains(p.id)).toList();
        case CommunityFilter.popular:
          filtered.sort((a, b) => b.likesCount.compareTo(a.likesCount));
          return filtered;
        case CommunityFilter.all:
        default:
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return filtered;
      }
    }

    return Stream.value(computeFiltered()).concatWith([
      _feedController.stream.map((_) => computeFiltered()),
    ]);
  }

  @override
  Stream<List<CommunityPost>> watchPinnedPosts() {
    final pinned = posts.where((p) => p.isPinned).toList();
    return Stream.value(pinned);
  }

  @override
  Stream<List<CommunityPost>> watchUserPosts(String userId, {String? currentUserId}) {
    final userPosts = posts.where((p) => p.authorId == userId).toList();
    return Stream.value(userPosts);
  }

  @override
  Future<CommunityPost?> getPost(String postId, {String? currentUserId}) async {
    try {
      return posts.firstWhere((p) => p.id == postId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> createPost({
    required CommunityPost post,
    List<File> images = const [],
  }) async {
    if (simulateNetworkErrorOnCreate) {
      throw Exception('Network error on createPost');
    }
    posts.insert(0, post);
    _notifyFeed();
  }

  @override
  Future<void> updatePost({
    required String postId,
    required String newCaption,
    List<String>? keepImageUrls,
    List<File>? newImages,
    String? userId,
  }) async {
    final index = posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final old = posts[index];
      posts[index] = old.copyWith(
        caption: newCaption,
        imageUrls: keepImageUrls ?? old.imageUrls,
        isEdited: true,
      );
      _notifyFeed();
    }
  }

  @override
  Future<void> deletePost({
    required String postId,
    required String authorId,
    required List<String> imageUrls,
  }) async {
    posts.removeWhere((p) => p.id == postId);
    commentsByPost.remove(postId);
    _notifyFeed();
  }

  @override
  Future<void> toggleLike({
    required String postId,
    required String currentUserId,
    required bool isLiked,
  }) async {
    if (simulateNetworkErrorOnLike) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      throw Exception('Network error: toggleLike failed');
    }
    final index = posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final old = posts[index];
      final newCount = isLiked ? old.likesCount - 1 : old.likesCount + 1;
      posts[index] = old.copyWith(
        likesCount: newCount < 0 ? 0 : newCount,
        isLikedByMe: !isLiked,
      );
      _notifyFeed();
    }
  }

  @override
  Stream<List<CommunityComment>> watchComments(String postId) {
    _commentControllers.putIfAbsent(postId, () => StreamController<List<CommunityComment>>.broadcast());
    final current = commentsByPost[postId] ?? [];
    return Stream.value(current).concatWith([_commentControllers[postId]!.stream]);
  }

  @override
  Future<void> addComment({
    required String postId,
    required CommunityComment comment,
  }) async {
    final list = commentsByPost.putIfAbsent(postId, () => []);
    list.add(comment);
    final postIndex = posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      posts[postIndex] = posts[postIndex].copyWith(commentsCount: posts[postIndex].commentsCount + 1);
    }
    _notifyComments(postId);
    _notifyFeed();
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final list = commentsByPost[postId];
    if (list != null) {
      list.removeWhere((c) => c.id == commentId);
      final postIndex = posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final count = posts[postIndex].commentsCount - 1;
        posts[postIndex] = posts[postIndex].copyWith(commentsCount: count < 0 ? 0 : count);
      }
      _notifyComments(postId);
      _notifyFeed();
    }
  }

  @override
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  }) async {
    reports.add({'postId': postId, 'reporterId': reporterId, 'reason': reason});
  }

  @override
  Future<void> blockUser({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    blockedUsers.add(blockedUserId);
  }

  @override
  Future<void> toggleSavePost({
    required String currentUserId,
    required String postId,
    required bool isSaved,
  }) async {
    if (isSaved) {
      savedPosts.remove(postId);
    } else {
      savedPosts.add(postId);
    }
  }

  @override
  Future<List<String>> getSavedPostIds(String currentUserId) async {
    return savedPosts.toList();
  }
}

extension<T> on Stream<T> {
  Stream<T> concatWith(Iterable<Stream<T>> others) {
    final controller = StreamController<T>.broadcast();
    final streams = [this, ...others];
    int current = 0;
    StreamSubscription<T>? sub;

    void next() {
      if (current >= streams.length) {
        controller.close();
        return;
      }
      sub = streams[current++].listen(
        controller.add,
        onError: controller.addError,
        onDone: next,
      );
    }

    controller.onListen = next;
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }
}
