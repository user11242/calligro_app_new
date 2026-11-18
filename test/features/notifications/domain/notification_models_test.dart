import 'package:calligro_app/features/notifications/domain/notification_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('where a tap leads (THE BUG: taps opened nothing)', () {
    NotificationTarget t(Map<String, dynamic> d) => NotificationTarget.fromData(d);

    test('every route the server sends', () {
      expect(t({'route': '/postDetails', 'postId': 'p1', 'commentId': 'c1'}), const PostTarget('p1', commentId: 'c1'));
      expect(t({'route': '/courseChat', 'courseId': 'c1', 'courseName': 'Thuluth', 'teacherId': 't1'}),
          const CourseChatTarget('c1', courseName: 'Thuluth', teacherId: 't1'));
      expect(t({'route': '/courseDetails', 'courseId': 'c1'}), const CourseTarget('c1'),
          reason: 'announcements, assignments, reschedules: the app did not know this route');
      expect(t({'route': '/profile', 'userId': 'u1'}), const ProfileTarget('u1'));
      expect(t({'route': '/adminPendingTeachers'}), const PendingTeachersTarget());
      expect(t({'route': '/admin/teachers', 'userId': 'u9'}), const PendingTeachersTarget(), reason: 'older server name');
    });

    test('incomplete or unknown → the inbox (a tap always opens something)', () {
      expect(t({'route': '/courseDetails'}), const InboxTarget());
      expect(t({'route': '/postDetails', 'postId': ''}), const InboxTarget());
      expect(t({'route': '/somewhereNew', 'x': 1}), const InboxTarget());
      expect(t(const {}), const InboxTarget());
      expect(t({'type': 'broadcast', 'title': 'Hi'}), const InboxTarget());
    });

    test('older pushes with only a type and ids still open the right place', () {
      expect(t({'type': 'like', 'postId': 'p1'}), const PostTarget('p1'));
      expect(t({'type': 'new_follower', 'userId': 'u1'}), const ProfileTarget('u1'));
      expect(t({'type': 'reschedule', 'courseId': 'c1'}), const CourseTarget('c1'));
    });
  });

  group('inbox items', () {
    test('the server\'s shape, with its destination', () {
      final i = InboxItem.fromMap('n1', {
        'title': 'New Assignment', 'body': 'Alif drills', 'type': 'assignment', 'read': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 15)),
        'data': {'route': '/courseDetails', 'courseId': 'c1'},
      });
      expect([i.title, i.body, i.read, i.createdAt, i.target], ['New Assignment', 'Alif drills', false, DateTime(2026, 11, 15), const CourseTarget('c1')]);
    });

    test('older app-written reschedule notices (message / isRead) read correctly (they showed blank and always unread)', () {
      final i = InboxItem.fromMap('n2', {'title': 'Session moved', 'message': 'Now at 7 PM', 'isRead': true, 'type': 'reschedule', 'courseId': 'c1'});
      expect([i.body, i.read, i.target], ['Now at 7 PM', true, const CourseTarget('c1')]);
    });

    test('items without a destination open the inbox', () {
      expect(InboxItem.fromMap('n3', {'title': 'Payout Completed', 'body': 'Done', 'type': 'payout_status'}).target, const InboxTarget());
    });
  });

  group('moved-class notifications carry the exact times (shown in the phone\'s own time zone)', () {
    final data = {
      'route': '/courseDetails', 'courseId': 'c1', 'classChange': 'moved', 'courseName': 'Thuluth',
      'oldStart': '${DateTime.parse('2026-11-30T15:00:00Z').millisecondsSinceEpoch}',
      'newStart': '${DateTime.parse('2026-12-01T16:00:00Z').millisecondsSinceEpoch}',
      'newEnd': '${DateTime.parse('2026-12-01T17:30:00Z').millisecondsSinceEpoch}',
      'note': 'Travelling',
    };

    test('read from the server item', () {
      final item = InboxItem.fromMap('n1', {'title': 'Session Rescheduled', 'body': 'server text', 'type': 'reschedule', 'data': data});
      final c = item.classChange!;
      expect(c.isBack, isFalse);
      expect(c.oldStart, DateTime.parse('2026-11-30T15:00:00Z'));
      expect(c.newStart, DateTime.parse('2026-12-01T16:00:00Z'));
      expect(c.note, 'Travelling');
      expect(item.target, const CourseTarget('c1'));
    });

    test('"back on schedule" needs only the usual time', () {
      final c = ClassChange.fromData({...data, 'classChange': 'back', 'newStart': '', 'newEnd': ''})!;
      expect(c.isBack, isTrue);
      expect(c.newStart, isNull);
    });

    test('older notifications (no times) and other types: none', () {
      expect(InboxItem.fromMap('n2', {'type': 'reschedule', 'data': {'courseId': 'c1'}}).classChange, isNull);
      expect(ClassChange.fromData({...data, 'newStart': 'abc'}), isNull);
      expect(ClassChange.fromData({'classChange': 'other'}), isNull);
    });
  });
}
