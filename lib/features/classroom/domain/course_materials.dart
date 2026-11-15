/// Course materials: folders of PDFs or images (pure Dart).
library;

class CourseMaterialFileItem {
  final String title;
  final String fileName;
  final String fileUrl;
  final String fileSize;
  final String storagePath;
  final String type; // 'pdf' or 'image'

  const CourseMaterialFileItem({
    required this.title,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.storagePath,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'storagePath': storagePath,
      'type': type,
    };
  }

  factory CourseMaterialFileItem.fromMap(Map<String, dynamic> map, {String fallbackType = 'image'}) {
    return CourseMaterialFileItem(
      title: map['title'] ?? map['fileName'] ?? '',
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      fileSize: map['fileSize'] ?? '',
      storagePath: map['storagePath'] ?? '',
      type: map['type'] ?? fallbackType,
    );
  }
}

class CourseMaterialFolder {
  final String id;
  final String title;
  final String type; // 'pdf', 'image', or 'folder'
  final String totalSize;
  final String? previewUrl;
  final DateTime? createdAt;
  final String uploadedByName;
  final List<CourseMaterialFileItem> files;

  const CourseMaterialFolder({
    required this.id,
    required this.title,
    required this.type,
    required this.totalSize,
    this.previewUrl,
    this.createdAt,
    required this.uploadedByName,
    required this.files,
  });

  bool get isPdf => type == 'pdf' || (files.isNotEmpty && files.every((f) => f.type == 'pdf'));
  int get itemCount => files.length;

  factory CourseMaterialFolder.fromMap(String id, Map<String, dynamic> data) {
    final String type = data['type'] ?? 'image';
    final List<CourseMaterialFileItem> parsedFiles = [];

    // 1. If it has a modern 'files' list
    if (data['files'] is List && (data['files'] as List).isNotEmpty) {
      for (final f in data['files'] as List) {
        if (f is Map) {
          parsedFiles.add(CourseMaterialFileItem.fromMap(
            Map<String, dynamic>.from(f),
            fallbackType: type,
          ));
        }
      }
    } else if (data['fileUrl'] != null && (data['fileUrl'] as String).isNotEmpty) {
      // 2. Legacy single-item document
      parsedFiles.add(CourseMaterialFileItem(
        title: data['title'] ?? '',
        fileName: data['fileName'] ?? '',
        fileUrl: data['fileUrl'] ?? '',
        fileSize: data['fileSize'] ?? '',
        storagePath: data['storagePath'] ?? '',
        type: type,
      ));
    }

    DateTime? created;
    try {
      final dynamic t = data['createdAt'];
      if (t is DateTime) {
        created = t;
      } else if (t != null) {
        created = t.toDate() as DateTime; // Firestore Timestamp
      }
    } catch (_) {}

    String preview = data['previewUrl'] ?? '';
    if (preview.isEmpty && parsedFiles.isNotEmpty) {
      final img = parsedFiles.firstWhere(
        (f) => f.type == 'image',
        orElse: () => parsedFiles.first,
      );
      if (img.type == 'image') preview = img.fileUrl;
    }

    return CourseMaterialFolder(
      id: id,
      title: data['title'] ?? 'مجلد الملحقات',
      type: type,
      totalSize: data['totalSize'] ?? data['fileSize'] ?? '',
      previewUrl: preview.isNotEmpty ? preview : null,
      createdAt: created,
      uploadedByName: data['uploadedByName'] ?? 'Instructor',
      files: parsedFiles,
    );
  }
}

/// A file picked on the phone, waiting to be uploaded into a new folder.
class MaterialUpload {
  final String localPath;
  final String fileName;
  final String title;
  final String fileSize;
  final int bytes;
  const MaterialUpload({required this.localPath, required this.fileName, required this.title, required this.fileSize, required this.bytes});
}

/// Same wording as before ("812 B", "1.4 KB", "3.2 MB").
String formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
}
