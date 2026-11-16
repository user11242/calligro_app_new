import 'package:calligro_app/features/admin/data/admin_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class _Functions extends Mock implements FirebaseFunctions {
  final called = <String>[];
  Object? failWith;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) => _Callable(this, name);
}

class _Callable extends Mock implements HttpsCallable {
  _Callable(this.f, this.name);
  final _Functions f;
  final String name;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    f.called.add('$name:${(parameters as Map?)?['targetUserId'] ?? (parameters as Map?)?['uid'] ?? ''}');
    if (f.failWith != null && (parameters as Map?)?['targetUserId'] == 'ghost') throw f.failWith!;
    return _Result<T>();
  }
}

class _Result<T> extends Mock implements HttpsCallableResult<T> {
  @override
  T get data => <String, dynamic>{} as T;
}

void main() {
  late FakeFirebaseFirestore db;
  late _Functions functions;
  late AdminService admin;

  setUp(() async {
    db = FakeFirebaseFirestore();
    functions = _Functions();
    admin = AdminService(firestore: db, auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'boss')), functions: functions);
    await db.doc('users/t1').set({'role': 'teacher', 'status': 'approved', 'approved': true, 'name': 'Ali', 'email': 'ali@x.com', 'phone': '+٩٦٢ 79 1'});
    await db.doc('teachers/t1').set({'role': 'teacher', 'status': 'approved'});
    await db.doc('users/s1').set({'role': 'student', 'name': 'Sara', 'email': 'sara@x.com'});
    await db.doc('students/s1').set({'role': 'student'});
  });

  test('suspend: back to pending and not approved (THE BUG: it blocked nothing); approve restores', () async {
    await admin.suspendTeacher('t1');
    final u = (await db.doc('users/t1').get()).data()!;
    expect([u['status'], u['approved'], u['suspendedAt'] != null], ['pending', false, true]);
    expect((await db.doc('teachers/t1').get()).data()!['status'], 'pending');
    await admin.approveTeacher('t1');
    expect((await db.doc('users/t1').get()).data()!['status'], 'approved');
  });

  test('promote by email (any capitals) leaves no student entry behind', () async {
    await admin.promoteToAdminByEmail(' Sara@X.com ');
    expect((await db.doc('users/s1').get()).data()!['role'], 'admin');
    expect((await db.doc('students/s1').get()).exists, isFalse);
    await db.doc('users/m1').set({'role': 'student', 'email': 'Mixed@X.com'});
    await admin.promoteToAdminByEmail('Mixed@X.com');
    expect((await db.doc('users/m1').get()).data()!['role'], 'admin', reason: 'saved with capitals: found when typed the same');
    expect(() => admin.promoteToAdminByEmail('nobody@x.com'), throwsException);
  });

  test('revoke admin: student again, with a students entry', () async {
    await admin.promoteToAdminByEmail('sara@x.com');
    await admin.revokeAdminStatus('s1');
    expect((await db.doc('users/s1').get()).data()!['role'], 'student');
    expect((await db.doc('students/s1').get()).data()!['role'], 'student');
    expect(() => admin.revokeAdminStatus('boss'), throwsException, reason: 'not yourself');
  });

  test('delete: sign-in (server), profile, role entry and ALL reservations (Arabic-digit phone too)', () async {
    for (final r in ['locked_emails/ali@x.com', 'locked_usernames/ali', 'locked_phones/+962791']) {
      await db.doc(r).set({'uid': 't1'});
    }
    await admin.deleteUser('t1');
    expect(functions.called, ['deleteUserAccount:t1']);
    for (final r in ['users/t1', 'teachers/t1', 'locked_emails/ali@x.com', 'locked_usernames/ali', 'locked_phones/+962791']) {
      expect((await db.doc(r).get()).exists, isFalse, reason: r);
    }
  });

  test('commission: 0-100 % stored as 0-1 on users and teachers', () async {
    await admin.setCommissionRate('t1', 70);
    expect((await db.doc('users/t1').get()).data()!['commissionRate'], 0.7);
    expect((await db.doc('teachers/t1').get()).data()!['commissionRate'], 0.7);
    expect(() => admin.setCommissionRate('t1', 120), throwsArgumentError);
  });

  test('course notice: one failed recipient does not fail the whole send', () async {
    functions.failWith = Exception('user deleted');
    final sent = await admin.sendCourseNotification(
        courseId: 'c1', courseName: 'Thuluth', teacherName: 'Ali', teacherId: 't1', studentIds: ['ghost', 's1'], message: 'Hi');
    expect(sent, 3);
    expect(functions.called.where((c) => c.startsWith('sendAdminDirectMessage')), hasLength(3));
    expect((await db.collection('courses/c1/announcements').get()).size, 1);
  });

  test('recent activity shows community posts (ordered by their real field, timestamp)', () async {
    await db.collection('community_posts').add({'content': 'Hello world', 'timestamp': DateTime(2026, 11, 15)});
    final items = await admin.getRecentActivity().first;
    expect(items.any((i) => i['type'] == 'post' && i['subtitle'] == 'Hello world'), isTrue);
  });
}
