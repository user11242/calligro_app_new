// lib/features/community/services/community_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CommunityService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ------------------------------------------------------------------------
  // 1. User Data Helper
  // ------------------------------------------------------------------------
  Future<Map<String, dynamic>> getCurrentUserData(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return {
        'id': userDoc.id,
        'name': userDoc.data()?['name'] ?? 'Anonymous',
        'photoUrl': userDoc.data()?['photoUrl'] ?? '',
        'role': userDoc.data()?['role'] ?? 'student',
      };
    } else {
      throw Exception("User data not found for ID: $userId");
    }
  }

  // ------------------------------------------------------------------------
  // 2. Image Handling (Picker & Compression)
  // ------------------------------------------------------------------------
  Future<List<File>> pickAndCompressImages({
    required BuildContext context,
    required int currentImageCount,
    required int maxImages,
    String? errorAlreadySelectedMax,
    String? errorCanOnlySelectUpTo,
    String? errorSomeImagesNotAdded,
  }) async {
    final int remainingSlots = maxImages - currentImageCount;
    if (remainingSlots <= 0) {
      throw Exception(
        errorAlreadySelectedMax ?? "You have already selected the maximum of $maxImages images.",
      );
    }

    final List<AssetEntity>? pickedFiles = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: remainingSlots,
        requestType: RequestType.image,
      ),
    );

    if (pickedFiles == null || pickedFiles.isEmpty) return [];

    if (pickedFiles.length > remainingSlots) {
      throw Exception(
        errorCanOnlySelectUpTo ?? "You can only select up to $maxImages photos in total.",
      );
    }

    List<File> compressedFiles = [];
    int addedCount = 0;

    for (var entity in pickedFiles) {
      if (compressedFiles.length + currentImageCount >= maxImages) break;

      final File? file = await entity.file;
      if (file == null) continue;

      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$addedCount.jpg';

      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
            file.path,
            targetPath,
            minWidth: 1080,
            minHeight: 1080,
            quality: 75,
            autoCorrectionAngle: true, // Fix EXIF rotation for Android
            keepExif: false,            // Strip EXIF so Android can't mis-read it
          );

      if (compressedXFile != null) {
        compressedFiles.add(File(compressedXFile.path));
        addedCount++;
      }
    }

    if (addedCount < pickedFiles.length &&
        compressedFiles.length + currentImageCount < maxImages) {
      throw Exception(
        errorSomeImagesNotAdded ?? "Limit of $maxImages photos reached. Some images were not added.",
      );
    }

    return compressedFiles;
  }

  // ------------------------------------------------------------------------
  // 3. Create Post
  // ------------------------------------------------------------------------
  Future<void> createPost({
    required String caption,
    required List<File> images,
    required Map<String, dynamic> userData,
  }) async {
    if (caption.isEmpty && images.isEmpty) {
      throw Exception("You cannot create an empty post.");
    }

    final String uid = userData['id'];

    try {
      List<String> imageUrls = [];

      // Upload Images
      if (images.isNotEmpty) {
        final List<Future<String>> uploadFutures = images.map((file) async {
          String filePath =
              'community_posts/$uid/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
          final ref = _storage.ref().child(filePath);
          final uploadTask = ref.putFile(file);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        }).toList();

        imageUrls = await Future.wait(uploadFutures);
      }

      // Write to Firestore
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('community_posts').doc();
        final userRef = _firestore.collection('users').doc(uid);
        final userDoc = await transaction.get(userRef);

        transaction.set(postRef, {
          // CORRECTED: 'userId' matches your database screenshot (image_547f9d.png)
          'userId': uid,
          'userName': userData['name'],
          'userImageUrl': userData['photoUrl'],
          'userRole': userData['role'],
          'caption': caption,
          'imageUrls': imageUrls,
          'timestamp': FieldValue.serverTimestamp(),
          'likesCount': 0,
          'commentsCount': 0,
          'likes': {},
        });

        // Increment user's post count
        if (userDoc.exists) {
          transaction.update(userRef, {'postCount': FieldValue.increment(1)});
        }
      });
    } catch (e) {
      throw Exception("Failed to create post: $e");
    }
  }

  // ------------------------------------------------------------------------
  // 4. Read Posts (The Stream)
  // ------------------------------------------------------------------------
  Stream<QuerySnapshot> getCommunityPostsStream({
    String filter = 'All',
    String? currentUserId,
    List<String>? followingIds, // New optional parameter
    List<String>? savedPostIds, // New optional parameter for Saved filter
  }) {
    Query query = _firestore.collection('community_posts');

    switch (filter) {
      case 'My Posts':
        if (currentUserId != null) {
          query = query.where('userId', isEqualTo: currentUserId);
        }
        query = query.orderBy('timestamp', descending: true);
        break;

      case 'Popular':
        query = query.orderBy('likesCount', descending: true);
        break;

      case 'Friends':
        if (followingIds != null && followingIds.isNotEmpty) {
           List<String> limitedIds = followingIds.take(30).toList();
           query = query.where('userId', whereIn: limitedIds);
           query = query.orderBy('timestamp', descending: true);
        } else {
             query = query.where('userId', isEqualTo: 'NON_EXISTENT_ID'); 
        }
        break;

      case 'Saved':
        if (savedPostIds != null && savedPostIds.isNotEmpty) {
           List<String> limitedIds = savedPostIds.take(30).toList();
           query = query.where(FieldPath.documentId, whereIn: limitedIds);
           // Ordering by timestamp might fail if Firestore requires an index for 'documentId' + 'timestamp'
        } else {
             query = query.where('userId', isEqualTo: 'NON_EXISTENT_ID'); 
        }
        break;

      case 'Teachers':
        query = query.where('userRole', isEqualTo: 'teacher');
        query = query.orderBy('timestamp', descending: true);
        break;

      case 'All':
      default:
        query = query.orderBy('timestamp', descending: true);
        break;
    }

    return query.snapshots().handleError((e) {
      // Swallow permission errors
    });
  }

  // ------------------------------------------------------------------------
  // 5. Like / Unlike
  // ------------------------------------------------------------------------
  Future<void> toggleLike({
    required String postId,
    required String currentUserId,
    required bool isLiked,
  }) async {
    final DocumentReference postRef = _firestore
        .collection('community_posts')
        .doc(postId);

    if (isLiked) {
      await postRef.update({
        'likes.$currentUserId': FieldValue.delete(),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await postRef.update({
        'likes.$currentUserId': true,
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  // ------------------------------------------------------------------------
  // 6. Delete Post
  // ------------------------------------------------------------------------
  Future<void> deletePost({
    required String postId,
    required String postAuthorId,
    required List<String> imageUrls,
  }) async {
    try {
      // 1. Get all comments
      final commentsSnapshot = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('comments')
          .get();

      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      // 2. Delete each comment and its replies
      for (var commentDoc in commentsSnapshot.docs) {
        final repliesSnapshot =
            await commentDoc.reference.collection('replies').get();
        for (var replyDoc in repliesSnapshot.docs) {
          batch.delete(replyDoc.reference);
          operationCount++;
          if (operationCount >= 450) {
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
          }
        }
        batch.delete(commentDoc.reference);
        operationCount++;
        if (operationCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      // 3. Final cleanup in a transaction for data integrity
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection('community_posts').doc(postId);
        final userRef = _firestore.collection('users').doc(postAuthorId);
        final savedPostRef = userRef.collection('saved_posts').doc(postId);

        final userDoc = await transaction.get(userRef);

        transaction.delete(postRef);
        // Also remove it from saved_posts if the author saved their own post
        transaction.delete(savedPostRef);

        if (userDoc.exists) {
          final int currentCount = userDoc.data()?['postCount'] ?? 0;
          if (currentCount > 0) {
            transaction.update(userRef, {'postCount': FieldValue.increment(-1)});
          }
        }
      });

      // Commit any remaining operations in the last batch if there were many comments
      if (operationCount > 0) {
        await batch.commit();
      }

      // 4. Delete images from storage
      for (String url in imageUrls) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (e) {
          debugPrint("Failed to delete image $url from storage: $e");
        }
      }
    } catch (e) {
      throw Exception("Failed to delete post: $e");
    }
  }

  // ------------------------------------------------------------------------
  // 6b. Update Post (Edit Caption)
  // ------------------------------------------------------------------------
  Future<void> updatePost({
    required String postId,
    required String newCaption,
    List<File>? newImages,
    List<String>? keepImageUrls,
    String? userId,
  }) async {
    final DocumentReference postRef = _firestore
        .collection('community_posts')
        .doc(postId);

    List<String> finalImageUrls = keepImageUrls ?? [];

    if (newImages != null && newImages.isNotEmpty && userId != null) {
      final List<Future<String>> uploadFutures = newImages.map((file) async {
        String filePath =
            'community_posts/$userId/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final ref = _storage.ref().child(filePath);
        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      }).toList();

      final uploadedUrls = await Future.wait(uploadFutures);
      finalImageUrls.addAll(uploadedUrls);
    }

    await postRef.update({
      'caption': newCaption,
      'imageUrls': finalImageUrls,
      'isEdited': true,
    });
  }

  // ------------------------------------------------------------------------
  // 7. Likers List
  // ------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchLikersData(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return [];

    List<Future<DocumentSnapshot>> futures = userIds
        .map((id) => _firestore.collection('users').doc(id).get())
        .toList();

    final List<DocumentSnapshot> docs = await Future.wait(futures);

    List<Map<String, dynamic>> users = [];
    for (var doc in docs) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        users.add(data);
      }
    }
    return users;
  }

  // ------------------------------------------------------------------------
  // 8. Comments
  // ------------------------------------------------------------------------
  Stream<QuerySnapshot> getCommentsStream(String postId) {
    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((e) {});
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String userRole,
    required String text,
  }) async {
    final DocumentReference postRef = _firestore
        .collection('community_posts')
        .doc(postId);
    final CollectionReference commentsRef = postRef.collection('comments');

    WriteBatch batch = _firestore.batch();

    batch.set(commentsRef.doc(), {
      'userId': userId, // Corrected to lowercase 'd'
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'userRole': userRole,
    });

    batch.update(postRef, {'commentsCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> editComment({
    required String postId,
    required String commentId,
    required String newText,
  }) async {
    final DocumentReference commentRef = _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    await commentRef.update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final DocumentReference postRef = _firestore
        .collection('community_posts')
        .doc(postId);
    final DocumentReference commentRef = postRef
        .collection('comments')
        .doc(commentId);

    WriteBatch batch = _firestore.batch();
    batch.delete(commentRef);
    batch.update(postRef, {'commentsCount': FieldValue.increment(-1)});
    await batch.commit();
  }
  // --- SAVE / BOOKMARK LOGIC ---

  Future<void> toggleSavePost({
    required String postId,
    required String currentUserId,
    required bool isSaved,
  }) async {
    final docRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('saved_posts')
        .doc(postId);

    if (isSaved) {
      // Unsave
      await docRef.delete();
    } else {
      // Save
      await docRef.set({
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<List<String>> getSavedPostIds(String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print("Error fetching saved post IDs: $e");
      return [];
    }
  }
  // ------------------------------------------------------------------------
  // 9. Replies
  // ------------------------------------------------------------------------
  Stream<QuerySnapshot> getRepliesStream(String postId, String commentId) {
    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('timestamp', descending: false) // Oldest first for replies usually
        .snapshots()
        .handleError((e) {});
  }

  Future<void> addReply({
    required String postId,
    required String commentId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String userRole,
    required String text,
  }) async {
    final DocumentReference commentRef = _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    
    final CollectionReference repliesRef = commentRef.collection('replies');

    WriteBatch batch = _firestore.batch();

    batch.set(repliesRef.doc(), {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'userRole': userRole,
    });

    // Optional: Increment reply count on comment if you want to show "5 replies"
    batch.update(commentRef, {'replyCount': FieldValue.increment(1)});
    
    // Also increment global comment count on post? usually yes
    final postRef = _firestore.collection('community_posts').doc(postId);
    batch.update(postRef, {'commentsCount': FieldValue.increment(1)});

    await batch.commit();
  }

  Future<void> deleteReply({
    required String postId,
    required String commentId,
    required String replyId,
  }) async {
    final DocumentReference postRef = _firestore
        .collection('community_posts')
        .doc(postId);
    final DocumentReference commentRef = postRef
        .collection('comments')
        .doc(commentId);
    final DocumentReference replyRef = commentRef
        .collection('replies')
        .doc(replyId);

    WriteBatch batch = _firestore.batch();
    batch.delete(replyRef);
    batch.update(commentRef, {'replyCount': FieldValue.increment(-1)}); // Decrement reply count
    batch.update(postRef, {'commentsCount': FieldValue.increment(-1)}); // Decrement total comments
    await batch.commit();
  }

  Future<void> editReply({
    required String postId,
    required String commentId,
    required String replyId,
    required String newText,
  }) async {
    final DocumentReference replyRef = _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    await replyRef.update({
      'text': newText,
      'isEdited': true,
    });
  }
}
