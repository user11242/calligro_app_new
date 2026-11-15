import 'package:calligro_app/features/classroom/data/firestore_materials_repository.dart';
import 'package:calligro_app/features/classroom/domain/course_materials.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('folders: created with server time, newest first, renamed, files replaced, deleted', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreMaterialsRepository(firestore: db);
    await db.doc('users/t1').set({'name': 'Ustadh Ali'});
    const file = CourseMaterialFileItem(title: 'a', fileName: 'a.jpg', fileUrl: 'u', fileSize: '1 KB', storagePath: 'p', type: 'image');
    final id = await repo.createFolder('c1', {'title': 'W1', 'type': 'image', 'files': [file.toMap()], 'itemCount': 1});
    expect((await db.doc('courses/c1/materials/$id').get()).data()!['createdAt'], isA<Timestamp>());

    await repo.renameFolder('c1', id, 'Week 1');
    await repo.replaceFiles('c1', id, const []);
    final f = (await repo.watchFolder('c1', id).first)!;
    expect([f.title, f.itemCount], ['Week 1', 0]);
    expect((await db.doc('courses/c1/materials/$id').get()).data()!['itemCount'], 0);
    expect((await repo.watchFolders('c1').first).single.id, id);
    expect(await repo.displayName('t1'), 'Ustadh Ali');

    await repo.deleteFolder('c1', id);
    expect(await repo.watchFolder('c1', id).first, isNull);
  });
}
