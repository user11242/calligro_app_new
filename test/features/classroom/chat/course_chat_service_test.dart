import 'dart:io';

import 'package:calligro_app/features/classroom/domain/course_chat_message.dart';
import 'package:calligro_app/features/classroom/data/course_chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourseChatMessage model', () {
    test('fromMap parses all fields and role helpers cleanly', () {
      final now = DateTime(2026, 11, 12, 10, 30);
      final msg = CourseChatMessage.fromMap('m1', {
        'senderId': 'u_teacher',
        'senderName': 'Master Ali',
        'senderPhotoUrl': 'https://example.com/a.jpg',
        'senderRole': 'teacher',
        'text': 'Hello class',
        'imageUrl': 'https://example.com/img.jpg',
        'createdAt': Timestamp.fromDate(now),
      });

      expect(msg.id, 'm1');
      expect(msg.senderId, 'u_teacher');
      expect(msg.senderName, 'Master Ali');
      expect(msg.senderPhotoUrl, 'https://example.com/a.jpg');
      expect(msg.isTeacher, isTrue);
      expect(msg.isAdmin, isFalse);
      expect(msg.hasImage, isTrue);
      expect(msg.text, 'Hello class');
      expect(msg.createdAt, now);
    });

    test('fromMap handles missing/null fields with safe defaults', () {
      final msg = CourseChatMessage.fromMap('m2', {});

      expect(msg.senderId, '');
      expect(msg.senderName, 'Member');
      expect(msg.senderPhotoUrl, isNull);
      expect(msg.senderRole, 'student');
      expect(msg.isTeacher, isFalse);
      expect(msg.isAdmin, isFalse);
      expect(msg.hasImage, isFalse);
      expect(msg.text, '');
      expect(msg.createdAt, isNull);
    });
  });

  group('CourseChatService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseStorage mockStorage;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockStorage = MockFirebaseStorage();
    });

    test('sendMessage throws when user is not signed in', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      final service = CourseChatService(
        firestore: fakeFirestore,
        auth: auth,
        storage: mockStorage,
      );

      expect(
        () => service.sendMessage(courseId: 'c1', text: 'Hi'),
        throwsException,
      );
    });

    test('sendMessage ignores empty text when no image is attached', () async {
      final user = MockUser(uid: 's1', displayName: 'Sara');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      final service = CourseChatService(
        firestore: fakeFirestore,
        auth: auth,
        storage: mockStorage,
      );

      await service.sendMessage(courseId: 'c1', text: '   ');

      final snap = await fakeFirestore
          .collection('courses')
          .doc('c1')
          .collection('messages')
          .get();
      expect(snap.docs, isEmpty);
    });

    test('sendMessage assigns teacher role when uid matches courseTeacherId', () async {
      final user = MockUser(uid: 't1', displayName: 'Fallback Teacher');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      await fakeFirestore.collection('users').doc('t1').set({
        'name': 'Dr. Ibrahim',
        'photoUrl': 'https://example.com/teacher.png',
        'role': 'teacher',
      });

      final service = CourseChatService(
        firestore: fakeFirestore,
        auth: auth,
        storage: mockStorage,
      );

      await service.sendMessage(
        courseId: 'c1',
        text: '  Welcome everyone!  ',
        courseTeacherId: 't1',
      );

      final snap = await fakeFirestore
          .collection('courses')
          .doc('c1')
          .collection('messages')
          .get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['senderId'], 't1');
      expect(data['senderName'], 'Dr. Ibrahim');
      expect(data['senderPhotoUrl'], 'https://example.com/teacher.png');
      expect(data['senderRole'], 'teacher');
      expect(data['text'], 'Welcome everyone!');
    });

    test('sendMessage assigns admin role for admin user who is not courseTeacherId', () async {
      final user = MockUser(uid: 'admin1', displayName: 'Yazan');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      await fakeFirestore.collection('users').doc('admin1').set({
        'name': 'Yazan Admin',
        'role': 'admin',
      });

      final service = CourseChatService(
        firestore: fakeFirestore,
        auth: auth,
        storage: mockStorage,
      );

      await service.sendMessage(
        courseId: 'c1',
        text: 'Class starts in 10 mins',
        courseTeacherId: 't1',
      );

      final snap = await fakeFirestore
          .collection('courses')
          .doc('c1')
          .collection('messages')
          .get();
      expect(snap.docs.first.data()['senderRole'], 'admin');
    });

    test('sendMessage assigns student role and uploads image when imageFile is provided', () async {
      final user = MockUser(uid: 's1', displayName: 'Sara');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      await fakeFirestore.collection('users').doc('s1').set({
        'name': 'Sara',
        'role': 'student',
      });

      final tempDir = Directory.systemTemp.createTempSync('chat_test_');
      final tempFile = File('${tempDir.path}/sample.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);

      final service = CourseChatService(
        firestore: fakeFirestore,
        auth: auth,
        storage: mockStorage,
      );

      await service.sendMessage(
        courseId: 'c1',
        text: '',
        imageFile: tempFile,
        courseTeacherId: 't1',
      );

      tempDir.deleteSync(recursive: true);

      final snap = await fakeFirestore
          .collection('courses')
          .doc('c1')
          .collection('messages')
          .get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['senderRole'], 'student');
      expect(data['imageUrl'], isA<String>());
      expect((data['imageUrl'] as String).isNotEmpty, isTrue);
    });

    test('getMessagesStream emits messages ordered newest-first', () async {
      final auth = MockFirebaseAuth(signedIn: true);
      final service = CourseChatService(
        firestore: fakeFirestore,
        auth: auth,
        storage: mockStorage,
      );

      final col = fakeFirestore.collection('courses').doc('c1').collection('messages');
      await col.doc('old').set({
        'senderId': 's1',
        'senderName': 'Sara',
        'senderRole': 'student',
        'text': 'Older message',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 12, 9, 0)),
      });
      await col.doc('new').set({
        'senderId': 't1',
        'senderName': 'Master Ali',
        'senderRole': 'teacher',
        'text': 'Newer message',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 12, 9, 5)),
      });

      final messages = await service.getMessagesStream('c1').first;
      expect(messages.length, 2);
      expect(messages.first.id, 'new');
      expect(messages.last.id, 'old');
    });

    test('deleteMessage deletes the message document', () async {
      final auth = MockFirebaseAuth(signedIn: true);
      final service = CourseChatService(
        firestore: fakeFirestore,
        auth: auth,
        storage: mockStorage,
      );

      final docRef = fakeFirestore
          .collection('courses')
          .doc('c1')
          .collection('messages')
          .doc('m1');
      await docRef.set({'text': 'To remove', 'senderId': 's1'});

      await service.deleteMessage(courseId: 'c1', messageId: 'm1');
      expect((await docRef.get()).exists, isFalse);
    });

    test('reportMessage records moderation entry in reports collection', () async {
      final user = MockUser(uid: 's2', displayName: 'Omar');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      final service = CourseChatService(
        firestore: fakeFirestore,
        auth: auth,
        storage: mockStorage,
      );

      await service.reportMessage(
        courseId: 'c1',
        messageId: 'm1',
        reportedUserId: 's1',
        reason: 'Inappropriate content',
        messageText: 'Bad text',
      );

      final reports = await fakeFirestore.collection('reports').get();
      expect(reports.docs.length, 1);
      final data = reports.docs.first.data();
      expect(data['type'], 'course_chat_message');
      expect(data['courseId'], 'c1');
      expect(data['messageId'], 'm1');
      expect(data['reportedUserId'], 's1');
      // THE BUG: it was 'reportedBy', which firestore.rules refuse (they need
      // reportedByUserId, like community reports), so every chat report failed.
      expect(data['reportedByUserId'], 's2');
      expect(data.containsKey('reportedBy'), isFalse);
      expect(data['reason'], 'Inappropriate content');
      expect(data['messageText'], 'Bad text');
    });
  });

  test('a message longer than the rules allow (4000) is refused here with a clear error', () async {
    final service = CourseChatService(
      firestore: FakeFirebaseFirestore(),
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 's1', displayName: 'Sara')),
      storage: MockFirebaseStorage(),
    );
    expect(ChatPolicy.maxTextLength, 4000);
    await expectLater(
      service.sendMessage(courseId: 'c1', text: 'x' * 4001),
      throwsA(isA<ChatMessageTooLong>()),
    );
  });
}

