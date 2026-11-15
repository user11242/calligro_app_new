import '../domain/classroom_models.dart';
import '../domain/classroom_repositories.dart';
import '../domain/course_materials.dart';
import 'classroom_assignments.dart' show ClassroomOutcome, ClassroomResult;

/// Course materials: only the course's teacher (or an admin) uploads, renames
/// and deletes; members read (firestore.rules / storage.rules agree).
class ClassroomMaterials {
  ClassroomMaterials({
    required MaterialsRepository repository,
    required MaterialFiles files,
    required String Function() currentUid,
  })  : _repo = repository,
        _files = files,
        _uid = currentUid;

  final MaterialsRepository _repo;
  final MaterialFiles _files;
  final String Function() _uid;
  bool _busy = false;

  MaterialsRepository get repository => _repo;

  /// Uploads [items] one by one ([onProgress] gets 0-based index) and saves
  /// them as ONE folder document. Nothing is saved if an upload fails; files
  /// already uploaded for it are removed again.
  Future<ClassroomResult> uploadFolder(
    String courseId,
    CourseRole role, {
    required String title,
    required String type,
    required List<MaterialUpload> items,
    void Function(int index, MaterialUpload item)? onProgress,
  }) async {
    if (!role.canManage) return const ClassroomResult(ClassroomOutcome.notAllowed);
    if (title.trim().isEmpty || items.isEmpty) return const ClassroomResult(ClassroomOutcome.empty);
    if (_busy) return const ClassroomResult(ClassroomOutcome.busy);
    _busy = true;
    final uploaded = <CourseMaterialFileItem>[];
    try {
      var totalBytes = 0;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        onProgress?.call(i, item);
        final stored = await _files.upload(courseId, item.localPath, item.fileName);
        totalBytes += item.bytes;
        uploaded.add(CourseMaterialFileItem(
          title: item.title,
          fileName: item.fileName,
          fileUrl: stored.url,
          fileSize: item.fileSize,
          storagePath: stored.storagePath,
          type: type,
        ));
      }
      final uid = _uid();
      final name = await _repo.displayName(uid);
      final id = await _repo.createFolder(courseId, {
        'title': title.trim(),
        'type': type,
        'itemCount': uploaded.length,
        'totalSize': formatBytes(totalBytes),
        'previewUrl': type == 'image' ? uploaded.first.fileUrl : null,
        'files': [for (final f in uploaded) f.toMap()],
        'uploadedBy': uid,
        'uploadedByName': name.isEmpty ? 'Instructor' : name,
      });
      return ClassroomResult(ClassroomOutcome.done, id: id);
    } catch (e) {
      await _deleteQuietly(uploaded);
      return ClassroomResult(ClassroomOutcome.failed, message: '$e');
    } finally {
      _busy = false;
    }
  }

  Future<ClassroomResult> rename(String courseId, CourseRole role, String folderId, String title) => _run(role, () async {
        if (title.trim().isEmpty) return const ClassroomResult(ClassroomOutcome.empty);
        await _repo.renameFolder(courseId, folderId, title.trim());
        return const ClassroomResult(ClassroomOutcome.done);
      });

  Future<ClassroomResult> deleteFolder(String courseId, CourseRole role, CourseMaterialFolder folder) =>
      _run(role, () async {
        await _repo.deleteFolder(courseId, folder.id);
        await _deleteQuietly(folder.files);
        return const ClassroomResult(ClassroomOutcome.done);
      });

  /// Removes one file; an emptied folder is deleted ([ClassroomResult.id] = 'folder-deleted').
  Future<ClassroomResult> removeFile(String courseId, CourseRole role, CourseMaterialFolder folder, CourseMaterialFileItem file) =>
      _run(role, () async {
        final rest = folder.files.where((f) => f.fileUrl != file.fileUrl).toList();
        if (rest.isEmpty) {
          await _repo.deleteFolder(courseId, folder.id);
        } else {
          await _repo.replaceFiles(courseId, folder.id, rest);
        }
        await _deleteQuietly([file]);
        return ClassroomResult(ClassroomOutcome.done, id: rest.isEmpty ? 'folder-deleted' : null);
      });

  Future<ClassroomResult> _run(CourseRole role, Future<ClassroomResult> Function() body) async {
    if (!role.canManage) return const ClassroomResult(ClassroomOutcome.notAllowed);
    try {
      return await body();
    } catch (e) {
      return ClassroomResult(ClassroomOutcome.failed, message: '$e');
    }
  }

  Future<void> _deleteQuietly(List<CourseMaterialFileItem> files) async {
    for (final f in files) {
      if (f.storagePath.isEmpty) continue;
      try {
        await _files.delete(f.storagePath);
      } catch (_) {}
    }
  }
}
