import 'package:calligro_app/features/classroom/domain/course_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const msg = CourseChatMessage(id: 'm', senderId: 's1', senderName: 'Sara', senderRole: 'student', text: 'hi');

  test('delete: own message, the course teacher, an admin (unchanged)', () {
    expect(ChatPolicy.canDelete(msg, 's1', isTeacher: false, isAdmin: false), isTrue);
    expect(ChatPolicy.canDelete(msg, 's2', isTeacher: false, isAdmin: false), isFalse);
    expect(ChatPolicy.canDelete(msg, 't1', isTeacher: true, isAdmin: false), isTrue);
    expect(ChatPolicy.canDelete(msg, 'a1', isTeacher: false, isAdmin: true), isTrue);
    expect(ChatPolicy.canDelete(msg, null, isTeacher: false, isAdmin: false), isFalse);
  });

  test('badge: matches what the rules accept', () {
    expect(ChatPolicy.senderRole(uid: 't1', profileRole: 'teacher', courseTeacherId: 't1'), 'teacher');
    expect(ChatPolicy.senderRole(uid: 't2', profileRole: 'teacher', courseTeacherId: 't1'), 'student',
        reason: 'a teacher of another course is a student here');
    expect(ChatPolicy.senderRole(uid: 'a1', profileRole: 'admin', courseTeacherId: 't1'), 'admin');
    expect(ChatPolicy.senderRole(uid: 's1', profileRole: 'student'), 'student');
  });

  test('reads stored messages (Timestamp or DateTime, blanks → Member)', () {
    final m = CourseChatMessage.fromMap('m', {'senderId': 's1', 'senderName': ' ', 'text': 'x', 'createdAt': DateTime(2026, 11, 16)});
    expect([m.senderName, m.createdAt, m.senderRole, m.hasImage], ['Member', DateTime(2026, 11, 16), 'student', false]);
  });
}
