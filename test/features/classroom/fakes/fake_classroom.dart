import 'dart:async';

import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/domain/classroom_repositories.dart';
import 'package:calligro_app/features/classroom/domain/course_materials.dart';
import 'package:calligro_app/features/classroom/domain/course_recordings.dart';

class FakeAssignmentRepository implements AssignmentRepository {
  final assignments = <String, Map<String, Assignment>>{};
  final submissions = <String, Map<String, Submission>>{}; // key "course/assignment"
  final profiles = <String, ({String name, String? photoUrl})>{};
  final saves = <({String studentId, SubmissionInput input, bool isNew})>[];
  final seenCalls = <({String studentId, bool seen})>[];
  final _changes = StreamController<void>.broadcast(sync: true);
  Object? failWrites;

  void putAssignment(String courseId, Assignment a) {
    (assignments[courseId] ??= {})[a.id] = a;
    _changes.add(null);
  }

  void putSubmission(String courseId, String assignmentId, Submission s) {
    (submissions['$courseId/$assignmentId'] ??= {})[s.studentId] = s;
    _changes.add(null);
  }

  Stream<T> _live<T>(T Function() read) {
    late final StreamController<T> c;
    StreamSubscription<void>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(read());
        sub = _changes.stream.listen((_) => c.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<List<Assignment>> watchAssignments(String courseId) => _live(() => (assignments[courseId]?.values.toList() ?? [])
    ..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999))));

  @override
  Future<String> createAssignment(String courseId, AssignmentDraft draft) async {
    if (failWrites != null) throw failWrites!;
    final id = 'a${(assignments[courseId]?.length ?? 0) + 1}';
    putAssignment(courseId,
        Assignment(id: id, title: draft.title.trim(), instructions: draft.instructions, dueDate: draft.dueDate, practiceSheet: draft.practiceSheet));
    return id;
  }

  @override
  Stream<List<Submission>> watchSubmissions(String courseId, String assignmentId) =>
      _live(() => submissions['$courseId/$assignmentId']?.values.toList() ?? []);

  @override
  Stream<Submission?> watchSubmission(String courseId, String assignmentId, String studentId) =>
      _live(() => submissions['$courseId/$assignmentId']?[studentId]);

  @override
  Future<void> saveSubmission(String courseId, String assignmentId, String studentId, SubmissionInput input,
      {required bool isNew}) async {
    if (failWrites != null) throw failWrites!;
    saves.add((studentId: studentId, input: input, isNew: isNew));
    final old = submissions['$courseId/$assignmentId']?[studentId];
    putSubmission(
        courseId,
        assignmentId,
        Submission(
          studentId: studentId,
          studentName: input.studentName,
          studentImage: input.studentImage,
          note: input.note.trim(),
          fileUrl: input.fileUrl,
          fileName: input.fileName,
          submittedAt: DateTime(2026, 11, 20),
          seenByTeacher: old?.seenByTeacher ?? false, // like update(): teacher's mark kept
        ));
  }

  @override
  Future<void> deleteSubmission(String courseId, String assignmentId, String studentId) async {
    if (failWrites != null) throw failWrites!;
    submissions['$courseId/$assignmentId']?.remove(studentId);
    _changes.add(null);
  }

  @override
  Future<void> setSeen(String courseId, String assignmentId, String studentId, bool seen) async {
    seenCalls.add((studentId: studentId, seen: seen));
    final s = submissions['$courseId/$assignmentId']![studentId]!;
    putSubmission(
        courseId,
        assignmentId,
        Submission(
            studentId: s.studentId,
            studentName: s.studentName,
            note: s.note,
            fileUrl: s.fileUrl,
            fileName: s.fileName,
            submittedAt: s.submittedAt,
            seenByTeacher: seen));
  }

  @override
  Future<({String name, String? photoUrl})> studentProfile(String uid) async => profiles[uid] ?? (name: '', photoUrl: null);
}

class FakeSubmissionFiles implements SubmissionFiles {
  final uploads = <String>[];
  Completer<void>? hold;

  @override
  Future<String> upload({
    required String courseId,
    required String assignmentId,
    required String studentId,
    required String localPath,
    required String fileName,
  }) async {
    if (hold != null) await hold!.future;
    uploads.add('$courseId/$assignmentId/${studentId}_$fileName');
    return 'https://files/${studentId}_$fileName';
  }
}

class FakeMaterialsRepository implements MaterialsRepository {
  final folders = <String, Map<String, CourseMaterialFolder>>{};
  final created = <Map<String, dynamic>>[];
  final _changes = StreamController<void>.broadcast(sync: true);
  String name = 'Ustadh Ali';

  void put(String courseId, CourseMaterialFolder f) {
    (folders[courseId] ??= {})[f.id] = f;
    _changes.add(null);
  }

  Stream<T> _live<T>(T Function() read) {
    late final StreamController<T> c;
    StreamSubscription<void>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(read());
        sub = _changes.stream.listen((_) => c.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<List<CourseMaterialFolder>> watchFolders(String courseId) => _live(() => folders[courseId]?.values.toList() ?? []);
  @override
  Stream<CourseMaterialFolder?> watchFolder(String courseId, String folderId) => _live(() => folders[courseId]?[folderId]);
  @override
  Future<String> createFolder(String courseId, Map<String, dynamic> folder) async {
    created.add(folder);
    final id = 'f${created.length}';
    put(courseId, CourseMaterialFolder.fromMap(id, folder));
    return id;
  }

  @override
  Future<void> renameFolder(String courseId, String folderId, String title) async {
    final f = folders[courseId]![folderId]!;
    put(courseId, CourseMaterialFolder(id: f.id, title: title, type: f.type, totalSize: f.totalSize, uploadedByName: f.uploadedByName, files: f.files));
  }

  @override
  Future<void> deleteFolder(String courseId, String folderId) async {
    folders[courseId]?.remove(folderId);
    _changes.add(null);
  }

  @override
  Future<void> replaceFiles(String courseId, String folderId, List<CourseMaterialFileItem> files) async {
    final f = folders[courseId]![folderId]!;
    put(courseId, CourseMaterialFolder(id: f.id, title: f.title, type: f.type, totalSize: f.totalSize, uploadedByName: f.uploadedByName, files: files));
  }

  @override
  Future<String> displayName(String uid) async => name;
}

class FakeMaterialFiles implements MaterialFiles {
  final uploaded = <String>[];
  final deleted = <String>[];
  String? failOn;

  @override
  Future<({String url, String storagePath})> upload(String courseId, String localPath, String fileName) async {
    if (fileName == failOn) throw Exception('upload failed');
    final path = 'course_materials/$courseId/$fileName';
    uploaded.add(path);
    return (url: 'https://files/$fileName', storagePath: path);
  }

  @override
  Future<void> delete(String storagePath) async => deleted.add(storagePath);
}

class FakeRecordingsRepository implements RecordingsRepository {
  final recordings = <CourseRecording>[];
  final renames = <({String id, String? title})>[];
  final recoverCalls = <String>[];
  Object? failRecover;

  @override
  Future<void> recoverMissing(String courseId) async {
    recoverCalls.add(courseId);
    if (failRecover != null) throw failRecover!;
  }
  final _changes = StreamController<void>.broadcast(sync: true);

  void put(CourseRecording r) {
    recordings.add(r);
    _changes.add(null);
  }

  @override
  Stream<List<CourseRecording>> watchRecordings(String courseId) {
    late final StreamController<List<CourseRecording>> c;
    StreamSubscription<void>? sub;
    c = StreamController(
      onListen: () {
        c.add(List.of(recordings));
        sub = _changes.stream.listen((_) => c.add(List.of(recordings)));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Future<void> rename(String courseId, String recordingId, String? title) async => renames.add((id: recordingId, title: title));
}

class FakeCourseDetailsRepository implements CourseDetailsRepository {
  Map<String, dynamic>? course;
  final roles = <String, String>{};
  final profiles = <String, EnrolledStudent>{};
  int listeners = 0;
  final studentReads = <List<String>>[];
  final _changes = StreamController<void>.broadcast(sync: true);

  void setCourse(Map<String, dynamic>? c) {
    course = c;
    _changes.add(null);
  }

  @override
  Stream<Map<String, dynamic>?> watchCourse(String courseId) {
    late final StreamController<Map<String, dynamic>?> c;
    StreamSubscription<void>? sub;
    c = StreamController(
      onListen: () {
        listeners++;
        c.add(course);
        sub = _changes.stream.listen((_) => c.add(course));
      },
      onCancel: () {
        listeners--;
        sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  Future<Map<String, dynamic>?> getCourse(String courseId) async => course;

  @override
  Future<String?> userRole(String uid) async => roles[uid];

  @override
  Future<List<EnrolledStudent>> students(List<String> uids) async {
    studentReads.add(List.of(uids));
    return [for (final id in uids) if (profiles[id] != null) profiles[id]!];
  }
}
