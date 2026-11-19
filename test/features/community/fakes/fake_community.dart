import 'dart:async';

import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:calligro_app/features/community/domain/repositories/community_repositories.dart';

/// Stateful in-memory community. Every watch* stream emits the current value
/// immediately and again after every change, like Firestore snapshots.
/// Put a method name in [failing] to make it throw (failure injection).
/// Emits [read]() on listen and after every [changes] event; cancels cleanly.
Stream<T> _live<T>(Stream<void> changes, T Function() read) {
  StreamSubscription<void>? sub;
  late final StreamController<T> c;
  c = StreamController<T>(
    onListen: () {
      c.add(read());
      sub = changes.listen((_) => c.add(read()));
    },
    onCancel: () => sub?.cancel(),
  );
  return c.stream;
}

class FakeCommunityRepository implements CommunityRepository {
  final posts = <String, CommunityPost>{};
  final comments = <String, List<CommunityComment>>{}; // postId → comments
  final replies = <String, List<CommunityComment>>{}; // commentId → replies
  final saved = <String, Set<String>>{}; // userId → postIds
  final blocked = <String, List<String>>{}; // userId → blocked ids
  final reports = <({String postId, String reporterId})>[];
  final calls = <String>[];
  final failing = <String>{};
  int _ids = 0;

  /// When set, setLiked / setSaved wait for it (to test in-flight taps).
  Completer<void>? gate;

  final _changes = StreamController<void>.broadcast(sync: true);
  void _changed() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) => _live(_changes.stream, read);

  Future<void> _call(String name) async {
    calls.add(name);
    if (gate != null) await gate!.future;
    if (failing.contains(name)) throw Exception('$name failed');
  }

  void addPost(CommunityPost p) {
    posts[p.id] = p;
    _changed();
  }

  List<CommunityPost> get _byNewest =>
      posts.values.toList()..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  @override
  Stream<List<CommunityPost>> watchFeed(CommunityFilter filter,
      {required String currentUserId, List<String> followingIds = const [], List<String> savedPostIds = const []}) {
    calls.add('watchFeed:${filter.name}');
    if (failing.contains('watchFeed')) return Stream.error(Exception('feed failed'));
    return _watch(() => switch (filter) {
          CommunityFilter.all => _byNewest,
          CommunityFilter.popular => posts.values.toList()..sort((a, b) => b.likesCount.compareTo(a.likesCount)),
          CommunityFilter.teachers => _byNewest.where((p) => p.authorRole == 'teacher').toList(),
          CommunityFilter.myPosts => _byNewest.where((p) => p.authorId == currentUserId).toList(),
          CommunityFilter.friends => _byNewest.where((p) => followingIds.contains(p.authorId)).toList(),
          CommunityFilter.saved => _byNewest.where((p) => savedPostIds.contains(p.id)).toList(),
        });
  }

  @override
  Stream<List<CommunityPost>> watchPinnedPosts() => _watch(() => posts.values.where((p) => p.isPinned).toList());

  @override
  Stream<List<CommunityPost>> watchUserPosts(String userId) =>
      _watch(() => _byNewest.where((p) => p.authorId == userId).toList());

  @override
  Stream<CommunityPost?> watchPost(String postId) =>
      failing.contains('watchPost') ? Stream.error(Exception('watchPost failed')) : _watch(() => posts[postId]);

  @override
  Stream<List<CommunityPost>> watchLikedPosts(String userId) =>
      _watch(() => _byNewest.where((p) => p.likerIds.contains(userId)).toList());

  @override
  Stream<List<CommunityPost>> watchPostsByIds(List<String> postIds) =>
      _watch(() => [for (final id in postIds.take(30)) if (posts[id] != null) posts[id]!]);

  @override
  Future<void> createPost(NewPost post, {required CommunitySession author, required List<String> imageUrls}) async {
    await _call('createPost');
    final id = 'new${++_ids}';
    posts[id] = CommunityPost(
      id: id,
      authorId: author.userId,
      authorName: author.name,
      authorRole: author.role,
      caption: post.caption,
      imageUrls: imageUrls,
      createdAt: DateTime.now(),
      linkUrl: post.linkUrl,
      isPinned: post.isPinned,
      isHidden: post.isHidden,
    );
    _changed();
  }

  @override
  Future<void> updatePost(String postId, {required String caption, required List<String> imageUrls}) async {
    await _call('updatePost');
    posts[postId] = posts[postId]!.copyWith(caption: caption, imageUrls: imageUrls, isEdited: true);
    _changed();
  }

  @override
  Future<List<String>> deletePost(CommunityPost post) async {
    await _call('deletePost');
    posts.remove(post.id);
    comments.remove(post.id);
    _changed();
    return post.imageUrls;
  }

  @override
  Future<void> setLiked(String postId, {required String userId, required bool like}) async {
    await _call('setLiked');
    final p = posts[postId]!;
    final likers = {...p.likerIds};
    like ? likers.add(userId) : likers.remove(userId);
    posts[postId] = p.copyWith(likerIds: likers, likesCount: p.likesCount + (like ? 1 : -1));
    _changed();
  }

  @override
  Future<void> setPinned(String postId, bool pinned) async {
    await _call('setPinned');
    posts[postId] = posts[postId]!.copyWith(isPinned: pinned);
    _changed();
  }

  @override
  Future<void> setHidden(String postId, bool hidden) async {
    await _call('setHidden');
    posts[postId] = posts[postId]!.copyWith(isHidden: hidden);
    _changed();
  }

  CommunityComment _newComment(CommunitySession a, String text) => CommunityComment(
      id: 'c${++_ids}', authorId: a.userId, authorName: a.name, authorRole: a.role, text: text, createdAt: DateTime.now());

  @override
  Stream<List<CommunityComment>> watchComments(String postId) => _watch(() => List.of(comments[postId] ?? const []));

  @override
  Future<void> addComment(String postId, {required CommunitySession author, required String text}) async {
    await _call('addComment');
    (comments[postId] ??= []).insert(0, _newComment(author, text));
    _changed();
  }

  @override
  Future<void> editComment(String postId, String commentId, String text) async {
    await _call('editComment');
    final list = comments[postId]!;
    final i = list.indexWhere((c) => c.id == commentId);
    final c = list[i];
    list[i] = CommunityComment(
        id: c.id, authorId: c.authorId, authorName: c.authorName, text: text, isEdited: true, createdAt: c.createdAt);
    _changed();
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    await _call('deleteComment');
    comments[postId]?.removeWhere((c) => c.id == commentId);
    _changed();
  }

  @override
  Stream<List<CommunityComment>> watchReplies(String postId, String commentId) =>
      _watch(() => List.of(replies[commentId] ?? const []));

  @override
  Future<void> addReply(String postId, String commentId, {required CommunitySession author, required String text}) async {
    await _call('addReply');
    (replies[commentId] ??= []).add(_newComment(author, text));
    _changed();
  }

  @override
  Future<void> editReply(String postId, String commentId, String replyId, String text) async {
    await _call('editReply');
    _changed();
  }

  @override
  Future<void> deleteReply(String postId, String commentId, String replyId) async {
    await _call('deleteReply');
    replies[commentId]?.removeWhere((r) => r.id == replyId);
    _changed();
  }

  @override
  Future<List<String>> getSavedPostIds(String userId) async => (saved[userId] ?? {}).toList();

  @override
  Stream<List<String>> watchSavedPostIds(String userId) => _watch(() => (saved[userId] ?? {}).toList());

  @override
  Future<void> setSaved(String postId, {required String userId, required bool saved}) async {
    await _call('setSaved');
    final set = this.saved[userId] ??= {};
    saved ? set.add(postId) : set.remove(postId);
    _changed();
  }

  @override
  Future<void> reportPost(CommunityPost post, {required String reporterId}) async {
    await _call('reportPost');
    reports.add((postId: post.id, reporterId: reporterId));
  }

  @override
  Future<void> blockUser(String userId, {required String blockedUserId}) async {
    await _call('blockUser');
    (blocked[userId] ??= []).add(blockedUserId);
    _changed();
  }

  @override
  Future<void> unblockUser(String userId, {required String blockedUserId}) async {
    await _call('unblockUser');
    blocked[userId]?.remove(blockedUserId);
    _changed();
  }

  @override
  Stream<List<String>> watchBlockedUserIds(String userId) => _watch(() => List.of(blocked[userId] ?? const []));
}

class FakeFollowRepository implements FollowRepository {
  final following = <String, Set<String>>{};
  final failing = <String>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<bool> watchIsFollowing({required String userId, required String targetUserId}) =>
      _live(_changes.stream, () => following[userId]?.contains(targetUserId) ?? false);

  @override
  Future<void> setFollowing({required String userId, required String targetUserId, required bool follow}) async {
    if (failing.contains('setFollowing')) throw Exception('follow failed');
    final set = following[userId] ??= {};
    follow ? set.add(targetUserId) : set.remove(targetUserId);
    _changes.add(null);
  }

  /// When set, getFollowingIds waits for it (a slow network, to test quick tab switches).
  Completer<void>? followingGate;

  @override
  Future<List<String>> getFollowingIds(String userId) async {
    if (followingGate != null) await followingGate!.future;
    return (following[userId] ?? {}).toList();
  }
}

class FakeUserRepository implements CommunityUserRepository {
  final users = <String, CommunityUser>{};
  final lookups = <List<String>>[];
  final searches = <String>[];

  /// Per-query delay to test out-of-order search responses.
  final delays = <String, Duration>{};

  /// 'getUsers' / 'searchByName' to make them throw.
  final failing = <String>{};

  @override
  Future<List<CommunityUser>> getUsers(List<String> userIds) async {
    lookups.add(List.of(userIds));
    if (failing.contains('getUsers')) throw Exception('getUsers failed');
    return [for (final id in userIds) if (users[id] != null) users[id]!];
  }

  @override
  Future<List<CommunityUser>> searchByName(String query) async {
    searches.add(query);
    final d = delays[query];
    if (d != null) await Future<void>.delayed(d);
    if (failing.contains('searchByName')) throw Exception('search failed');
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    return users.values.where((u) => u.name.toLowerCase().startsWith(q)).toList();
  }
}

class FakeSessionSource implements CommunitySessionSource {
  FakeSessionSource(this.session);
  CommunitySession session;
  @override
  Future<CommunitySession> currentSession() async => session;
}

class FakeMediaStorage implements CommunityMediaStorage {
  final uploaded = <String>[];
  final deleted = <String>[];
  bool fail = false;

  @override
  Future<List<String>> uploadPostImages(String userId, List<String> localPaths) async {
    if (fail) throw Exception('upload failed');
    final urls = [for (final p in localPaths) 'https://cdn/$userId/${p.split('/').last}'];
    uploaded.addAll(urls);
    return urls;
  }

  @override
  Future<void> deleteByUrl(String url) async => deleted.add(url);
}

class FakeImagePicker implements CommunityImagePicker {
  List<String> next = const [];
  final requests = <int>[];
  @override
  Future<List<String>> pickImages({required int maxCount}) async {
    requests.add(maxCount);
    return next.take(maxCount).toList();
  }
}

class FakeTranslator implements CommunityTranslator {
  String language = 'ar';
  int identifyCalls = 0;
  bool fail = false;
  @override
  Future<String> identifyLanguage(String text) async {
    identifyCalls++;
    return language;
  }

  @override
  Future<String> translate(String text, {required String targetLanguage}) async {
    if (fail) throw Exception('translate failed');
    return '[$targetLanguage] $text';
  }
}

// ── Ready-made people and posts ──────────────────────────────────────────
const studentSession = CommunitySession(userId: 's1', name: 'Student One', role: 'student');
const teacherSession = CommunitySession(userId: 't1', name: 'Teacher One', role: 'teacher');
const adminSession = CommunitySession(userId: 'a1', name: 'Admin', role: 'admin');
const guestSession = CommunitySession.guest;

CommunityPost postBy(String authorId,
        {String id = 'p1',
        String role = 'student',
        String caption = 'Naskh practice',
        int likes = 0,
        Set<String> likers = const {},
        List<String> images = const [],
        bool pinned = false,
        bool hidden = false,
        int day = 1}) =>
    CommunityPost(
      id: id,
      authorId: authorId,
      authorName: 'Author $authorId',
      authorRole: role,
      caption: caption,
      likesCount: likes,
      likerIds: likers,
      imageUrls: images,
      isPinned: pinned,
      isHidden: hidden,
      createdAt: DateTime(2026, 1, day),
    );
