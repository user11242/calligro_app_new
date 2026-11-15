import 'package:calligro_app/features/classroom/data/firestore_assignment_repository.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreAssignmentRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreAssignmentRepository(firestore: db);
    await db.doc('users/s1').set({'name': 'Sara', 'photoUrl': 'sara.jpg'});
  });

  test('assignments: created with a Timestamp due date, listed soonest first', () async {
    await repo.createAssignment('c1', AssignmentDraft(title: 'Later', dueDate: DateTime(2026, 12, 20)));
    await repo.createAssignment('c1', AssignmentDraft(title: 'Sooner', dueDate: DateTime(2026, 12, 10), practiceSheet: 'paper1.jpg'));
    final list = await repo.watchAssignments('c1').first;
    expect(list.map((a) => a.title), ['Sooner', 'Later']);
    expect(list.first.dueDate, DateTime(2026, 12, 10));
    expect(list.first.practiceSheet, 'paper1.jpg');
    final raw = (await db.collection('courses/c1/assignments').get()).docs.first.data();
    expect(raw['dueDate'], isA<Timestamp>());
    expect(raw.containsKey('submissionCount'), isFalse);
  });

  test('a new submission is created; a change updates only student fields', () async {
    const path = 'courses/c1/assignments/a1/submissions/s1';
    await repo.saveSubmission('c1', 'a1', 's1', const SubmissionInput(note: 'v1', fileUrl: 'u1', fileName: 'f1', studentName: 'Sara'),
        isNew: true);
    expect((await db.doc(path).get()).data()!['studentId'], 's1');

    await repo.setSeen('c1', 'a1', 's1', true);
    await db.doc(path).update({'points': 0, 'status': 'submitted'}); // an older document's extra fields
    await repo.saveSubmission('c1', 'a1', 's1', const SubmissionInput(note: 'v2', fileUrl: 'u1', fileName: 'f1', studentName: 'Sara'),
        isNew: false);
    final d = (await db.doc(path).get()).data()!;
    expect([d['note'], d['seenByTeacher'], d['points'], d['status']], ['v2', true, 0, 'submitted']);

    final mine = await repo.watchSubmission('c1', 'a1', 's1').first;
    expect([mine!.note, mine.seenByTeacher], ['v2', true]);
    expect((await repo.watchSubmissions('c1', 'a1').first).single.studentName, 'Sara');

    await repo.deleteSubmission('c1', 'a1', 's1');
    expect(await repo.watchSubmission('c1', 'a1', 's1').first, isNull);
  });

  test('student profile', () async {
    expect(await repo.studentProfile('s1'), (name: 'Sara', photoUrl: 'sara.jpg'));
    expect(await repo.studentProfile('nobody'), (name: '', photoUrl: null));
  });
}
