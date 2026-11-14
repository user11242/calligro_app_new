import 'dart:io';

/// Interface for compressing and uploading media files to storage.
abstract class MediaUploader {
  /// Uploads post images and returns their public or download URLs.
  Future<List<String>> uploadPostImages({
    required String userId,
    required List<File> imageFiles,
  });

  /// Deletes a file from storage by its download URL.
  Future<void> deleteMediaByUrl(String url);
}

