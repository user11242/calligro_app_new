import 'package:calligro_app/features/classroom/presentation/chat/course_chat_page.dart';
import 'package:calligro_app/features/classroom/data/course_chat_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestablePage({
    required FakeFirebaseFirestore firestore,
    required MockFirebaseAuth auth,
    bool isTeacher = false,
    bool isAdmin = false,
    String courseTeacherId = 't1',
  }) {
    final service = CourseChatService(
      firestore: firestore,
      auth: auth,
      storage: MockFirebaseStorage(),
    );

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('tr')],
      home: CourseChatPage(
        courseId: 'c1',
        courseName: 'Naskh Beginners',
        courseTeacherId: courseTeacherId,
        isTeacher: isTeacher,
        isAdmin: isAdmin,
        chatService: service,
        currentUserId: auth.currentUser?.uid,
      ),
    );
  }

  group('CourseChatPage Widget Tests', () {
    testWidgets('shows empty state when no messages exist', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 's1', displayName: 'Sara'),
      );

      await tester.pumpWidget(buildTestablePage(
        firestore: firestore,
        auth: auth,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Naskh Beginners'), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('renders messages and displays Teacher badge for teacher messages',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 's1', displayName: 'Sara'),
      );

      await firestore.collection('courses').doc('c1').collection('messages').add({
        'senderId': 't1',
        'senderName': 'Dr. Ibrahim',
        'senderRole': 'teacher',
        'text': 'Welcome to the group chat!',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 12, 10, 0)),
      });

      await tester.pumpWidget(buildTestablePage(
        firestore: firestore,
        auth: auth,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Ibrahim'), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('Welcome to the group chat!'), findsOneWidget);
    });

    testWidgets('sending a message persists to Firestore and clears input',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final user = MockUser(uid: 's1', displayName: 'Sara');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      await firestore.collection('users').doc('s1').set({
        'name': 'Sara',
        'role': 'student',
      });

      await tester.pumpWidget(buildTestablePage(
        firestore: firestore,
        auth: auth,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello teacher!');
      await tester.tap(find.byKey(const Key('course_chat_send_button')));
      await tester.pumpAndSettle();

      final snap = await firestore
          .collection('courses')
          .doc('c1')
          .collection('messages')
          .get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['text'], 'Hello teacher!');
      expect(find.text('Hello teacher!'), findsOneWidget);

      final TextField field = tester.widget(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('whitespace-only message is not sent', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 's1', displayName: 'Sara'),
      );

      await tester.pumpWidget(buildTestablePage(
        firestore: firestore,
        auth: auth,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '    ');
      await tester.tap(find.byKey(const Key('course_chat_send_button')));
      await tester.pumpAndSettle();

      final snap = await firestore
          .collection('courses')
          .doc('c1')
          .collection('messages')
          .get();
      expect(snap.docs, isEmpty);
    });

    testWidgets(
        'long-pressing another user message shows Report and Delete for teacher',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 't1', displayName: 'Dr. Ibrahim'),
      );

      await firestore
          .collection('courses')
          .doc('c1')
          .collection('messages')
          .doc('m_student')
          .set({
        'senderId': 's1',
        'senderName': 'Sara',
        'senderRole': 'student',
        'text': 'Student question',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 12, 10, 5)),
      });

      await tester.pumpWidget(buildTestablePage(
        firestore: firestore,
        auth: auth,
        isTeacher: true,
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Student question'));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report Message'), findsOneWidget);
      expect(find.text('Delete Message'), findsOneWidget);
    });
  });
}

