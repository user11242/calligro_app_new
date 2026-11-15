import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/community_models.dart';
import '../domain/models/community_post.dart';
import '../domain/policies/community_policy.dart';
import '../domain/repositories/community_repositories.dart';

/// Firestore ⇄ domain mapping. The field names here ARE the database schema
/// (shared with firestore.rules, the web portal and Cloud Functions) — the data
/// tests pin every one of them.
class CommunityFirestoreMapper {
  CommunityFirestoreMapper._();

  static DateTime? date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  static String str(Object? v, [String fallback = '']) => v is String ? v : fallback;

  static int count(Object? v) => v is num ? v.toInt() : 0;

  static CommunityPost post(String id, Map<String, dynamic> d) {
    final likes = d['likes'];
    final images = d['imageUrls'];
    return CommunityPost(
      id: id,
      authorId: str(d['userId']),
      authorName: str(d['userName']),
      authorPhotoUrl: str(d['userImageUrl']),
      authorRole: str(d['userRole'], 'student'),
      caption: str(d['caption']),
      imageUrls: images is List ? images.whereType<String>().toList() : const [],
      createdAt: date(d['timestamp']),
      likesCount: count(d['likesCount']),
      likerIds: likes is Map ? likes.keys.map((k) => k.toString()).toSet() : const {},
      commentsCount: count(d['commentsCount']),
      isEdited: d['isEdited'] == true,
      isPinned: d['isPinned'] == true,
      isHidden: d['isHidden'] == true,
      linkUrl: d['linkUrl'] is String ? d['linkUrl'] as String : null,
      linkTitle: d['linkTitle'] is String ? d['linkTitle'] as String : null,
    );
  }

  static CommunityComment comment(String id, Map<String, dynamic> d) => CommunityComment(
        id: id,
        authorId: str(d['userId']),
        authorName: str(d['userName']),
        authorPhotoUrl: str(d['userPhotoUrl']),
        authorRole: str(d['userRole'], 'student'),
        text: str(d['text']),
        createdAt: date(d['timestamp']),
        isEdited: d['isEdited'] == true,
        replyCount: count(d['replyCount']),
      );

  static Map<String, dynamic> newComment(CommunitySession author, String text) => {
        'userId': author.userId,
        'userName': author.name,
        'userPhotoUrl': author.photoUrl,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'userRole': author.role,
      };
}

class FirestoreCommunityRepository implements CommunityRepository {
  FirestoreCommunityRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('community_posts');
  DocumentReference<Map<String, dynamic>> _post(String id) => _posts.doc(id);
  DocumentReference<Map<String, dynamic>> _comment(String postId, String commentId) =>
      _post(postId).collection('comments').doc(commentId);
  DocumentReference<Map<String, dynamic>> _user(String id) => _db.collection('users').doc(id);

  static List<CommunityPost> _toPosts(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => CommunityFirestoreMapper.post(d.id, d.data())).toList();

  /// Permission errors (e.g. signed out mid-stream) end the stream quietly.
  Stream<T> _quiet<T>(Stream<T> s, String what) =>
      s.handleError((Object e) => debugPrint('Community $what stream error: $e'));

  // ── Feed ───────────────────────────────────────────────────────────────
  @override
  Stream<List<CommunityPost>> watchFeed(
    CommunityFilter filter, {
    required String currentUserId,
    List<String> followingIds = const [],
    List<String> savedPostIds = const [],
  }) {
    Query<Map<String, dynamic>> q = _posts;
    switch (filter) {
      case CommunityFilter.myPosts:
        if (currentUserId.isEmpty) return Stream.value(const []);
        q = q.where('userId', isEqualTo: currentUserId).orderBy('timestamp', descending: true);
      case CommunityFilter.popular:
        q = q.orderBy('likesCount', descending: true);
      case CommunityFilter.friends:
        if (followingIds.isEmpty) return Stream.value(const []);
        q = q
            .where('userId', whereIn: followingIds.take(CommunityPolicy.maxWhereInIds).toList())
            .orderBy('timestamp', descending: true);
      case CommunityFilter.saved:
        if (savedPostIds.isEmpty) return Stream.value(const []);
        q = q.where(FieldPath.documentId, whereIn: savedPostIds.take(CommunityPolicy.maxWhereInIds).toList());
      case CommunityFilter.teachers:
        q = q.where('userRole', isEqualTo: 'teacher').orderBy('timestamp', descending: true);
      case CommunityFilter.all:
        q = q.orderBy('timestamp', descending: true);
    }
    return _quiet(q.limit(CommunityPolicy.feedPageSize).snapshots().map(_toPosts), 'feed');
  }

  @override
  Stream<List<CommunityPost>> watchPinnedPosts() =>
      _quiet(_posts.where('isPinned', isEqualTo: true).limit(5).snapshots().map(_toPosts), 'pinned');

  @override
  Stream<List<CommunityPost>> watchUserPosts(String userId) => _quiet(
      _posts.where('userId', isEqualTo: userId).orderBy('timestamp', descending: true).snapshots().map(_toPosts),
      'user posts');

  @override
  Stream<List<CommunityPost>> watchLikedPosts(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _quiet(_posts.where('likes.$userId', isEqualTo: true).snapshots().map(_toPosts), 'liked posts');
  }

  @override
  Stream<List<CommunityPost>> watchPostsByIds(List<String> postIds) {
    if (postIds.isEmpty) return Stream.value(const []);
    return _quiet(
        _posts
            .where(FieldPath.documentId, whereIn: postIds.take(CommunityPolicy.maxWhereInIds).toList())
            .snapshots()
            .map(_toPosts),
        'posts by id');
  }

  @override
  Stream<CommunityPost?> watchPost(String postId) => _quiet(
      _post(postId).snapshots().map((d) => d.exists ? CommunityFirestoreMapper.post(d.id, d.data()!) : null), 'post');

  // ── Create / edit / delete ─────────────────────────────────────────────
  @override
  Future<void> createPost(NewPost post, {required CommunitySession author, required List<String> imageUrls}) async {
    final clean = CommunityPolicy.sanitizeForAuthor(post, author);
    await _db.runTransaction((tx) async {
      final postRef = _posts.doc();
      final userRef = _user(author.userId);
      final userDoc = await tx.get(userRef);
      tx.set(postRef, {
        'userId': author.userId,
        'userName': author.name,
        'userImageUrl': author.photoUrl,
        'userRole': author.role,
        'caption': clean.caption,
        'imageUrls': imageUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'likes': <String, dynamic>{},
        if (clean.linkUrl != null) 'linkUrl': clean.linkUrl,
        if (clean.linkTitle != null) 'linkTitle': clean.linkTitle,
        if (clean.isPinned) 'isPinned': true,
        if (clean.isHidden) 'isHidden': true,
      });
      if (userDoc.exists) {
        tx.update(userRef, {'postCount': FieldValue.increment(1)});
        final role = userDoc.data()?['role'];
        if (role == 'teacher' || role == 'student') {
          tx.update(_db.collection(role == 'teacher' ? 'teachers' : 'students').doc(author.userId),
              {'postCount': FieldValue.increment(1)});
        }
      }
    });
  }

  @override
  Future<void> updatePost(String postId, {required String caption, required List<String> imageUrls}) =>
      _post(postId).update({'caption': caption, 'imageUrls': imageUrls, 'isEdited': true});

  @override
  Future<List<String>> deletePost(CommunityPost post) async {
    // Comments + replies first, in batches below Firestore's 500-write limit.
    var batch = _db.batch();
    var ops = 0;
    Future<void> add(DocumentReference ref) async {
      batch.delete(ref);
      if (++ops >= 450) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }

    final comments = await _post(post.id).collection('comments').get();
    for (final c in comments.docs) {
      final replies = await c.reference.collection('replies').get();
      for (final r in replies.docs) {
        await add(r.reference);
      }
      await add(c.reference);
    }
    if (ops > 0) await batch.commit();

    await _db.runTransaction((tx) async {
      final userRef = _user(post.authorId);
      final userDoc = await tx.get(userRef);
      tx.delete(_post(post.id));
      tx.delete(userRef.collection('saved_posts').doc(post.id));
      if (userDoc.exists && count(userDoc.data()?['postCount']) > 0) {
        tx.update(userRef, {'postCount': FieldValue.increment(-1)});
        final role = userDoc.data()?['role'];
        if (role == 'teacher' || role == 'student') {
          tx.update(_db.collection(role == 'teacher' ? 'teachers' : 'students').doc(post.authorId),
              {'postCount': FieldValue.increment(-1)});
        }
      }
    });
    return post.imageUrls;
  }

  static int count(Object? v) => CommunityFirestoreMapper.count(v);

  // ── Likes / pin / hide ─────────────────────────────────────────────────
  @override
  Future<void> setLiked(String postId, {required String userId, required bool like}) => _post(postId).update({
        'likes.$userId': like ? true : FieldValue.delete(),
        'likesCount': FieldValue.increment(like ? 1 : -1),
      });

  @override
  Future<void> setPinned(String postId, bool pinned) => _post(postId).update({'isPinned': pinned});

  @override
  Future<void> setHidden(String postId, bool hidden) => _post(postId).update({'isHidden': hidden});

  // ── Comments ───────────────────────────────────────────────────────────
  @override
  Stream<List<CommunityComment>> watchComments(String postId) => _quiet(
      _post(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => CommunityFirestoreMapper.comment(d.id, d.data())).toList()),
      'comments');

  @override
  Future<void> addComment(String postId, {required CommunitySession author, required String text}) async {
    final batch = _db.batch()
      ..set(_post(postId).collection('comments').doc(), CommunityFirestoreMapper.newComment(author, text))
      ..update(_post(postId), {'commentsCount': FieldValue.increment(1)});
    await batch.commit();
  }

  @override
  Future<void> editComment(String postId, String commentId, String text) =>
      _comment(postId, commentId).update({'text': text, 'isEdited': true});

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    // commentsCount moves by exactly 1 (firestore.rules only allow ±1 from non-authors).
    final batch = _db.batch()
      ..delete(_comment(postId, commentId))
      ..update(_post(postId), {'commentsCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  // ── Replies ────────────────────────────────────────────────────────────
  @override
  Stream<List<CommunityComment>> watchReplies(String postId, String commentId) => _quiet(
      _comment(postId, commentId)
          .collection('replies')
          .orderBy('timestamp')
          .snapshots()
          .map((s) => s.docs.map((d) => CommunityFirestoreMapper.comment(d.id, d.data())).toList()),
      'replies');

  @override
  Future<void> addReply(String postId, String commentId,
      {required CommunitySession author, required String text}) async {
    final comment = _comment(postId, commentId);
    final batch = _db.batch()
      ..set(comment.collection('replies').doc(), CommunityFirestoreMapper.newComment(author, text))
      ..update(comment, {'replyCount': FieldValue.increment(1)})
      ..update(_post(postId), {'commentsCount': FieldValue.increment(1)});
    await batch.commit();
  }

  @override
  Future<void> editReply(String postId, String commentId, String replyId, String text) =>
      _comment(postId, commentId).collection('replies').doc(replyId).update({'text': text, 'isEdited': true});

  @override
  Future<void> deleteReply(String postId, String commentId, String replyId) async {
    final comment = _comment(postId, commentId);
    final batch = _db.batch()
      ..delete(comment.collection('replies').doc(replyId))
      ..update(comment, {'replyCount': FieldValue.increment(-1)})
      ..update(_post(postId), {'commentsCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  // ── Saved ──────────────────────────────────────────────────────────────
  @override
  Future<List<String>> getSavedPostIds(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final s = await _user(userId).collection('saved_posts').get();
      return s.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('Saved posts could not be loaded: $e');
      return const [];
    }
  }

  @override
  Stream<List<String>> watchSavedPostIds(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _quiet(_user(userId).collection('saved_posts').limit(1000).snapshots().map((s) => s.docs.map((d) => d.id).toList()),
        'saved posts');
  }

  @override
  Future<void> setSaved(String postId, {required String userId, required bool saved}) {
    final ref = _user(userId).collection('saved_posts').doc(postId);
    return saved ? ref.set({'timestamp': FieldValue.serverTimestamp()}) : ref.delete();
  }

  // ── Moderation ─────────────────────────────────────────────────────────
  @override
  Future<void> reportPost(CommunityPost post, {required String reporterId}) => _db.collection('reports').add({
        'postId': post.id,
        'reportedUserId': post.authorId,
        'reportedByUserId': reporterId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

  @override
  Future<void> blockUser(String userId, {required String blockedUserId}) =>
      _user(userId).update({'blockedUsers': FieldValue.arrayUnion([blockedUserId])});

  @override
  Future<void> unblockUser(String userId, {required String blockedUserId}) =>
      _user(userId).update({'blockedUsers': FieldValue.arrayRemove([blockedUserId])});

  @override
  Stream<List<String>> watchBlockedUserIds(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _quiet(
        _user(userId).snapshots().map((d) => List<String>.from((d.data()?['blockedUsers'] as List?) ?? const [])),
        'blocked users');
  }
}
