import 'package:calligro_app/features/classroom/application/classroom_assignments.dart';
import 'package:calligro_app/features/classroom/application/classroom_materials.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/domain/course_materials.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_classroom.dart';

MaterialUpload pick(String name, {int bytes = 2048}) =>
    MaterialUpload(localPath: '/tmp/$name', fileName: name, title: name, fileSize: '2 KB', bytes: bytes);

void main() {
  late FakeMaterialsRepository repo;
  late FakeMaterialFiles files;
  late ClassroomMaterials materials;

  setUp(() {
    repo = FakeMaterialsRepository();
    files = FakeMaterialFiles();
    materials = ClassroomMaterials(repository: repo, files: files, currentUid: () => 't1');
  });

  test('the teacher uploads a folder: files first, then ONE folder document', () async {
    final progress = <int>[];
    final r = await materials.uploadFolder('c1', CourseRole.owner,
        title: ' Week 1 ', type: 'image', items: [pick('a.jpg'), pick('b.jpg', bytes: 1024 * 1024)], onProgress: (i, _) => progress.add(i));
    expect(r.ok, isTrue);
    expect(progress, [0, 1]);
    final doc = repo.created.single;
    expect(doc['title'], 'Week 1');
    expect(doc['itemCount'], 2);
    expect(doc['totalSize'], '1.0 MB');
    expect(doc['previewUrl'], 'https://files/a.jpg');
    expect(doc['uploadedBy'], 't1');
    expect(doc['uploadedByName'], 'Ustadh Ali');
    expect((doc['files'] as List).map((f) => (f as Map)['storagePath']), ['course_materials/c1/a.jpg', 'course_materials/c1/b.jpg']);
  });

  test('PDF folders have no preview image', () async {
    await materials.uploadFolder('c1', CourseRole.admin, title: 'Sheets', type: 'pdf', items: [pick('s.pdf')]);
    expect(repo.created.single['previewUrl'], isNull);
  });

  test('a failed upload saves nothing and removes the files already uploaded for it', () async {
    files.failOn = 'b.jpg';
    final r = await materials.uploadFolder('c1', CourseRole.owner, title: 'W', type: 'image', items: [pick('a.jpg'), pick('b.jpg')]);
    expect(r.outcome, ClassroomOutcome.failed);
    expect(repo.created, isEmpty);
    expect(files.deleted, ['course_materials/c1/a.jpg']);
  });

  test('students and visitors cannot upload, rename or delete', () async {
    for (final role in [CourseRole.student, CourseRole.visitor]) {
      expect((await materials.uploadFolder('c1', role, title: 'x', type: 'pdf', items: [pick('x.pdf')])).outcome,
          ClassroomOutcome.notAllowed);
    }
    expect(files.uploaded, isEmpty);
  });

  test('rename, remove a file, and an emptied folder disappears', () async {
    await materials.uploadFolder('c1', CourseRole.owner, title: 'W', type: 'image', items: [pick('a.jpg'), pick('b.jpg')]);
    expect((await materials.rename('c1', CourseRole.owner, 'f1', 'Week 1')).ok, isTrue);
    var folder = repo.folders['c1']!['f1']!;
    expect(folder.title, 'Week 1');

    var r = await materials.removeFile('c1', CourseRole.owner, folder, folder.files.first);
    expect([r.ok, r.id], [true, null]);
    folder = repo.folders['c1']!['f1']!;
    expect(folder.files.map((f) => f.fileName), ['b.jpg']);

    r = await materials.removeFile('c1', CourseRole.owner, folder, folder.files.single);
    expect(r.id, 'folder-deleted');
    expect(repo.folders['c1'], isEmpty);
    expect(files.deleted, ['course_materials/c1/a.jpg', 'course_materials/c1/b.jpg']);
  });

  test('deleting a folder removes its files too', () async {
    await materials.uploadFolder('c1', CourseRole.owner, title: 'W', type: 'pdf', items: [pick('a.pdf')]);
    expect((await materials.deleteFolder('c1', CourseRole.owner, repo.folders['c1']!['f1']!)).ok, isTrue);
    expect(repo.folders['c1'], isEmpty);
    expect(files.deleted, ['course_materials/c1/a.pdf']);
    expect((await materials.deleteFolder('c1', CourseRole.student, const CourseMaterialFolder(id: 'x', title: '', type: '', totalSize: '', uploadedByName: '', files: []))).outcome,
        ClassroomOutcome.notAllowed);
  });

  test('older single-file documents still read as a one-file folder', () {
    final f = CourseMaterialFolder.fromMap('old', {'title': 'Old sheet', 'type': 'pdf', 'fileUrl': 'https://x/s.pdf', 'fileName': 's.pdf'});
    expect([f.itemCount, f.isPdf, f.files.single.fileUrl], [1, true, 'https://x/s.pdf']);
  });
}
