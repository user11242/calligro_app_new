import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/community_comment.dart';
import '../domain/models/community_filter.dart';
import '../domain/models/community_post.dart';
import '../domain/repositories/community_repository.dart';
import '../domain/repositories/media_uploader.dart';
import 'community_media_uploader_impl.dart';

/// Concrete Firestore implementation of CommunityRepository.
class FirestoreCommunityRepository implements CommunityRepository {
  final FirebaseFirestore? _firestoreMock;
  final MediaUploader _uploader;

  FirestoreCommunityRepository({
    FirebaseFirestore? firestore,
    MediaUploader? uploader,
  })  : _firestoreMock = firestore,
        _uploader = uploader ?? CommunityMediaUploaderImpl();

  FirebaseFirestore get _firestore => _firestoreMock ?? FirebaseFirestore.instance;

  @override
  Stream<List<CommunityPost>> watchFeed({
    required CommunityFilter filter,
    required String currentUserId,
    List<String>? followingIds,
    List<String>? savedPostIds,
    int limit = 20,
  }) {
    Query query = _firestore.collection('community_posts');

    switch (filter) {
      case CommunityFilter.myPosts:
        query = query.where('userId', isEqualTo: currentUserId).orderBy('timestamp', descending: true);
        break;
      case CommunityFilter.popular:
        query = query.orderBy('likesCount', descending: true);
        break;
      case CommunityFilter.friends:
        if (followingIds != null && followingIds.isNotEmpty) {
          final limited = followingIds.take(30).toList();
          query = query.where('userId', whereIn: limited).orderBy('timestamp', descending: true);
        } else {
          return Stream.value(const []);
        }
        break;
      case CommunityFilter.saved:
        if (savedPostIds != null && savedPostIds.isNotEmpty) {
          final limited = savedPostIds.take(30).toList();
          query = query.where(FieldPath.documentId, whereIn: limited);
        } else {
          return Stream.value(const []);
        }
        break;
      case CommunityFilter.teachers:
        query = query.where('userRole', isEqualTo: 'teacher').orderBy('timestamp', descending: true);
        break;
      case CommunityFilter.all:
        query = query.orderBy('timestamp', descending: true);
        break;
    }

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommunityPost.fromMap(
          id: doc.id,
          map: doc.data() as Map<String, dynamic>,
          currentUserId: currentUserId,
        );
      }).toList();
    }).handleError((e) {
      debugPrint('⚠️ watchFeed error: $e');
      return <CommunityPost>[];
    });
  }

  @override
  Stream<List<CommunityPost>> watchPinnedPosts() {
    return _firestore
        .collection('community_posts')
        .where('isPinned', isEqualTo: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommunityPost.fromMap(
          id: doc.id,
          map: doc.data(),
        );
      }).toList();
    }).handleError((_) => <CommunityPost>[]);
  }

  @override
  Stream<List<CommunityPost>> watchUserPosts(String userId, {String? currentUserId}) {
    return _firestore
        .collection('community_posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommunityPost.fromMap(
          id: doc.id,
          map: doc.data(),
          currentUserId: currentUserId,
        );
      }).toList();
    }).handleError((_) => <CommunityPost>[]);
  }

  @override
  Future<CommunityPost?> getPost(String postId, {String? currentUserId}) async {
    final doc = await _firestore.collection('community_posts').doc(postId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CommunityPost.fromMap(
      id: doc.id,
      map: doc.data()!,
      currentUserId: currentUserId,
    );
  }

  @override
  Future<void> createPost({
    required CommunityPost post,
    List<File> images = const [],
  }) async {
    List<String> finalImageUrls = List.of(post.imageUrls);

    if (images.isNotEmpty) {
      final uploaded = await _uploader.uploadPostImages(
        userId: post.authorId,
        imageFiles: images,
      );
      finalImageUrls.addAll(uploaded);
    }

    await _firestore.runTransaction((transaction) async {
      final postRef = _firestore.collection('community_posts').doc();
      final userRef = _firestore.collection('users').doc(post.authorId);
      
      // All reads first
      final userDoc = await transaction.get(userRef);
      final role = userDoc.data()?['role'] as String? ?? 'student';
      final roleRef = (role == 'teacher' || role == 'student')
          ? _firestore.collection(role == 'teacher' ? 'teachers' : 'students').doc(post.authorId)
          : null;
      final roleDoc = roleRef != null ? await transaction.get(roleRef) : null;

      // All writes after reads
      final Map<String, dynamic> postData = {
        'userId': post.authorId,
        'userName': post.authorName,
        'userImageUrl': post.authorPhotoUrl,
        'userRole': post.authorRole,
        'caption': post.caption,
        'imageUrls': finalImageUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'likes': {},
      };

      if (post.isAdmin) {
        if (post.linkUrl != null && post.linkUrl!.trim().isNotEmpty) {
          postData['linkUrl'] = post.linkUrl!.trim();
          if (post.linkTitle != null) postData['linkTitle'] = post.linkTitle!.trim();
        }
        if (post.isPinned) postData['isPinned'] = true;
        if (post.isHidden) postData['isHidden'] = true;
      }

      transaction.set(postRef, postData);

      if (userDoc.exists) {
        transaction.update(userRef, {'postCount': FieldValue.increment(1)});
        if (roleDoc != null && roleDoc.exists) {
          transaction.update(roleRef!, {'postCount': FieldValue.increment(1)});
        }
      }
    });
  }

  @override
  Future<void> updatePost({
    required String postId,
    required String newCaption,
    List<String>? keepImageUrls,
    List<File>? newImages,
    String? userId,
  }) async {
    final List<String> finalUrls = keepImageUrls != null ? List.of(keepImageUrls) : [];

    if (newImages != null && newImages.isNotEmpty && userId != null) {
      final uploaded = await _uploader.uploadPostImages(userId: userId, imageFiles: newImages);
      finalUrls.addAll(uploaded);
    }

    await _firestore.collection('community_posts').doc(postId).update({
      'caption': newCaption,
      'imageUrls': finalUrls,
      'isEdited': true,
    });
  }

  @override
  Future<void> deletePost({
    required String postId,
    required String authorId,
    required List<String> imageUrls,
  }) async {
    final commentsSnapshot = await _firestore.collection('community_posts').doc(postId).collection('comments').get();

    WriteBatch batch = _firestore.batch();
    int opCount = 0;

    for (var commentDoc in commentsSnapshot.docs) {
      final replies = await commentDoc.reference.collection('replies').get();
      for (var reply in replies.docs) {
        batch.delete(reply.reference);
        opCount++;
        if (opCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          opCount = 0;
        }
      }
      batch.delete(commentDoc.reference);
      opCount++;
      if (opCount >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }

    await _firestore.runTransaction((transaction) async {
      final postRef = _firestore.collection('community_posts').doc(postId);
      final userRef = _firestore.collection('users').doc(authorId);

      // All reads first
      final userDoc = await transaction.get(userRef);
      final role = userDoc.data()?['role'] as String? ?? 'student';
      final roleRef = (role == 'teacher' || role == 'student')
          ? _firestore.collection(role == 'teacher' ? 'teachers' : 'students').doc(authorId)
          : null;
      final roleDoc = roleRef != null ? await transaction.get(roleRef) : null;

      // All writes after reads
      transaction.delete(postRef);

      if (userDoc.exists) {
        final currentCount = userDoc.data()?['postCount'] ?? 0;
        if (currentCount > 0) {
          transaction.update(userRef, {'postCount': FieldValue.increment(-1)});
          if (roleDoc != null && roleDoc.exists) {
            transaction.update(roleRef!, {'postCount': FieldValue.increment(-1)});
          }
        }
      }
    });

    for (String url in imageUrls) {
      await _uploader.deleteMediaByUrl(url);
    }
  }

  @override
  Future<void> toggleLike({
    required String postId,
    required String currentUserId,
    required bool isLiked,
  }) async {
    final docRef = _firestore.collection('community_posts').doc(postId);

    if (isLiked) {
      await docRef.update({
        'likes.$currentUserId': FieldValue.delete(),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await docRef.update({
        'likes.$currentUserId': true,
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  @override
  Stream<List<CommunityComment>> watchComments(String postId) {
    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommunityComment.fromMap(
          id: doc.id,
          postId: postId,
          map: doc.data(),
        );
      }).toList();
    }).handleError((_) => <CommunityComment>[]);
  }

  @override
  Future<void> addComment({
    required String postId,
    required CommunityComment comment,
  }) async {
    final postRef = _firestore.collection('community_posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();

    final batch = _firestore.batch();
    batch.set(commentRef, {
      'userId': comment.authorId,
      'userName': comment.authorName,
      'userImageUrl': comment.authorPhotoUrl,
      'userRole': comment.authorRole,
      'comment': comment.text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.update(postRef, {'commentsCount': FieldValue.increment(1)});
    await batch.commit();
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final postRef = _firestore.collection('community_posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    final batch = _firestore.batch();
    batch.delete(commentRef);
    batch.update(postRef, {'commentsCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  @override
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  }) async {
    await _firestore.collection('community_reports').add({
      'postId': postId,
      'reporterId': reporterId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> blockUser({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    await _firestore.collection('users').doc(currentUserId).collection('blocked_users').doc(blockedUserId).set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> toggleSavePost({
    required String currentUserId,
    required String postId,
    required bool isSaved,
  }) async {
    final savedRef = _firestore.collection('users').doc(currentUserId).collection('saved_posts').doc(postId);
    if (isSaved) {
      await savedRef.delete();
    } else {
      await savedRef.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  @override
  Future<List<String>> getSavedPostIds(String currentUserId) async {
    if (currentUserId.isEmpty) return [];
    final snap = await _firestore.collection('users').doc(currentUserId).collection('saved_posts').get();
    return snap.docs.map((d) => d.id).toList();
  }
}
