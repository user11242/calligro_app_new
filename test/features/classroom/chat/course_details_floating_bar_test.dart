import 'package:calligro_app/features/classroom/presentation/chat/course_details_floating_bar.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableBar({
    required bool isTeacher,
    required VoidCallback onLiveSessionPressed,
    required VoidCallback onChatPressed,
    Locale locale = const Locale('en'),
    double width = 360,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('tr')],
      home: Scaffold(
        body: SizedBox(width: width, height: 600),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: CourseDetailsFloatingBar(
          isTeacher: isTeacher,
          onLiveSessionPressed: onLiveSessionPressed,
          onChatPressed: onChatPressed,
        ),
      ),
    );
  }

  group('CourseDetailsFloatingBar', () {
    testWidgets('renders Start Live Session and floating Chat button for teacher',
        (tester) async {
      bool liveTapped = false;
      bool chatTapped = false;

      await tester.pumpWidget(buildTestableBar(
        isTeacher: true,
        onLiveSessionPressed: () => liveTapped = true,
        onChatPressed: () => chatTapped = true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('START LIVE SESSION'), findsOneWidget);
      final chatBtn = find.byKey(const Key('floating_course_chat_button'));
      expect(chatBtn, findsOneWidget);

      await tester.tap(chatBtn);
      await tester.pump();
      expect(chatTapped, isTrue);

      await tester.tap(find.text('START LIVE SESSION'));
      await tester.pump();
      expect(liveTapped, isTrue);
    });

    testWidgets('renders Join Live Session on narrow Arabic layout without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableBar(
        isTeacher: false,
        locale: const Locale('ar'),
        width: 320,
        onLiveSessionPressed: () {},
        onChatPressed: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('floating_course_chat_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('locked outside the class window (students)', () {
    // Mon & Wed 15:00-16:30 UTC, 30 Nov – 16 Dec 2026; Mon 7 Dec moved to Tue 8 Dec 17:00-18:00.
    final schedule = CourseSchedule(
      weekdays: const {1, 3},
      startDate: DateTime.parse('2026-11-29T21:00:00Z'),
      endDate: DateTime.parse('2026-12-15T21:00:00Z'),
      startTime: DateTime.parse('2026-11-20T15:00:00Z'),
      endTime: DateTime.parse('2026-11-20T16:30:00Z'),
      utcOffset: const Duration(hours: 3),
      moves: [
        SessionMove(
            originalStart: DateTime.parse('2026-12-07T15:00:00Z'),
            newStart: DateTime.parse('2026-12-08T17:00:00Z'),
            newEnd: DateTime.parse('2026-12-08T18:00:00Z')),
      ],
    );
    late DateTime now;
    late int lockedTaps, liveTaps;

    Widget bar({bool student = true}) => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en'), Locale('ar'), Locale('tr')],
          home: Scaffold(
            body: const SizedBox(width: 400, height: 600),
            floatingActionButton: CourseDetailsFloatingBar(
              isTeacher: !student,
              onLiveSessionPressed: () => liveTaps++,
              onChatPressed: () {},
              joinCheck: student ? () => schedule.joinCheck(now) : null,
              onLockedPressed: () => lockedTaps++,
            ),
          ),
        );

    setUp(() {
      lockedTaps = 0;
      liveTaps = 0;
    });

    testWidgets('too early: locked with "Opens …"; a tap explains instead of joining', (tester) async {
      now = DateTime.parse('2026-12-02T14:49:00Z');
      await tester.pumpWidget(bar());
      expect(find.byKey(const Key('live-session-button')), findsNothing);
      expect(find.textContaining('Opens'), findsOneWidget);
      await tester.tap(find.byKey(const Key('live-session-locked')));
      expect(lockedTaps, 1);
      expect(liveTaps, 0);
    });

    testWidgets('unlocks ON ITS OWN at 10 minutes before (no reopening the page), locks again 30 minutes after', (tester) async {
      now = DateTime.parse('2026-12-02T14:49:58Z');
      await tester.pumpWidget(bar());
      expect(find.byKey(const Key('live-session-locked')), findsOneWidget);
      now = DateTime.parse('2026-12-02T14:50:00Z');
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('live-session-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('live-session-button')));
      expect(liveTaps, 1);
      now = DateTime.parse('2026-12-02T17:00:00Z');
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('live-session-locked')), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // stop the timer
    });

    testWidgets('a RESCHEDULED class: locked at the usual time, open at the new time', (tester) async {
      now = DateTime.parse('2026-12-07T15:05:00Z');
      await tester.pumpWidget(bar());
      expect(find.byKey(const Key('live-session-locked')), findsOneWidget);
      now = DateTime.parse('2026-12-08T16:51:00Z');
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('live-session-button')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('after the last class: "no more classes"', (tester) async {
      now = DateTime.parse('2026-12-20T10:00:00Z');
      await tester.pumpWidget(bar());
      expect(find.text('This course has no more classes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the teacher (and admins) are never locked', (tester) async {
      now = DateTime.parse('2026-12-03T03:00:00Z');
      await tester.pumpWidget(bar(student: false));
      expect(find.byKey(const Key('live-session-button')), findsOneWidget);
    });
  });
}
