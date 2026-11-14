import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/repositories/media_uploader.dart';

/// Concrete implementation of MediaUploader using FlutterImageCompress and FirebaseStorage.
class CommunityMediaUploaderImpl implements MediaUploader {
  final FirebaseStorage? _storageMock;

  CommunityMediaUploaderImpl({FirebaseStorage? storage}) : _storageMock = storage;

  FirebaseStorage get _storage => _storageMock ?? FirebaseStorage.instance;

  @override
  Future<List<String>> uploadPostImages({
    required String userId,
    required List<File> imageFiles,
  }) async {
    if (imageFiles.isEmpty) return [];

    final List<Future<String>> uploadTasks = imageFiles.map((file) async {
      File fileToUpload = file;

      try {
        final tempDir = await getTemporaryDirectory();
        final targetPath =
            '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

        final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          minWidth: 1080,
          minHeight: 1080,
          quality: 75,
          autoCorrectionAngle: true,
          keepExif: false,
        );

        if (compressed != null) {
          fileToUpload = File(compressed.path);
        }
      } catch (e) {
        debugPrint('⚠️ Image compression skipped/failed: $e');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${fileToUpload.path.split('/').last}';
      final storagePath = 'community_posts/$userId/$fileName';
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(fileToUpload);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    }).toList();

    return await Future.wait(uploadTasks);
  }

  @override
  Future<void> deleteMediaByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('⚠️ Failed to delete image from storage ($url): $e');
    }
  }
}

