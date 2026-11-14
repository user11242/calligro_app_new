import 'dart:io';

import 'package:calligro_app/features/community/domain/repositories/media_uploader.dart';

class FakeMediaUploader implements MediaUploader {
  final List<String> uploadedUrls = [];
  final List<String> deletedUrls = [];
  bool simulateError = false;

  @override
  Future<List<String>> uploadPostImages({
    required String userId,
    required List<File> imageFiles,
  }) async {
    if (simulateError) {
      throw Exception('FakeMediaUploader upload failed');
    }
    final urls = imageFiles.map((f) => 'https://storage.calligro.com/$userId/${f.path.split('/').last}').toList();
    uploadedUrls.addAll(urls);
    return urls;
  }

  @override
  Future<void> deleteMediaByUrl(String url) async {
    deletedUrls.add(url);
  }
}

