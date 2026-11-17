import 'package:calligro_app/features/classroom/domain/course_board.dart';
import 'package:calligro_app/features/classroom/presentation/widgets/next_session_card.dart';
import 'package:calligro_app/features/classroom/presentation/widgets/reschedule_sheet.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "Next class" card and the reschedule sheet (the teacher moves only the next class).
void main() {
  // Mon & Wed 18:00-19:30 (UTC+3), 30 Nov – 16 Dec 2026.
  CourseSchedule schedule({List<SessionMove> moves = const []}) => CourseSchedule(
        weekdays: const {1, 3},
        startDate: DateTime.parse('2026-11-29T21:00:00Z'),
        endDate: DateTime.parse('2026-12-15T21:00:00Z'),
        startTime: DateTime.parse('2026-11-20T15:00:00Z'),
        endTime: DateTime.parse('2026-11-20T16:30:00Z'),
        utcOffset: const Duration(hours: 3),
        moves: moves,
      );
  final now = DateTime.parse('2026-12-03T09:00:00Z'); // next: Mon 7 Dec
  final moved = SessionMove(
    originalStart: DateTime.parse('2026-12-07T15:00:00Z'),
    newStart: DateTime.parse('2026-12-08T15:00:00Z'),
    newEnd: DateTime.parse('2026-12-08T16:30:00Z'),
    note: 'Travelling, sorry!',
  );

  Widget app(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(backgroundColor: Colors.black, body: SingleChildScrollView(child: child)),
      );

  group('Next class card', () {
    Widget card(CourseSchedule s, {bool teacher = true, VoidCallback? onReschedule, VoidCallback? onBack}) => app(NextSessionCard(
          schedule: s,
          isTeacher: teacher,
          busy: false,
          now: now,
          onReschedule: onReschedule ?? () {},
          onBackToUsual: onBack ?? () {},
        ));

    testWidgets('shows the next class and, for the teacher, "Reschedule next class"', (tester) async {
      var tapped = false;
      await tester.pumpWidget(card(schedule(), onReschedule: () => tapped = true));
      expect(find.text('Next class'), findsOneWidget);
      expect(find.byKey(const Key('rescheduled-tag')), findsNothing);
      await tester.tap(find.byKey(const Key('reschedule-next')));
      expect(tapped, isTrue);
    });

    testWidgets('a moved class: the tag, the old time crossed out, the note, and "back to the usual time"', (tester) async {
      var back = false;
      await tester.pumpWidget(card(schedule(moves: [moved]), onBack: () => back = true));
      expect(find.byKey(const Key('rescheduled-tag')), findsOneWidget);
      expect(find.byKey(const Key('next-session-original')), findsOneWidget);
      expect(find.text('Travelling, sorry!'), findsOneWidget);
      expect(find.text('Change the new time'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reschedule-back')));
      expect(back, isTrue);
    });

    testWidgets('students see the class and the tag, but no buttons', (tester) async {
      await tester.pumpWidget(card(schedule(moves: [moved]), teacher: false));
      expect(find.byKey(const Key('rescheduled-tag')), findsOneWidget);
      expect(find.byKey(const Key('reschedule-next')), findsNothing);
      expect(find.byKey(const Key('reschedule-back')), findsNothing);
    });

    testWidgets('first / last class are labelled; after the course: no upcoming classes', (tester) async {
      await tester.pumpWidget(app(NextSessionCard(
          schedule: schedule(), isTeacher: true, busy: false, now: DateTime.parse('2026-11-25T09:00:00Z'),
          onReschedule: () {}, onBackToUsual: () {})));
      expect(find.text('First class'), findsOneWidget);
      await tester.pumpWidget(app(NextSessionCard(
          schedule: schedule(), isTeacher: true, busy: false, now: DateTime.parse('2026-12-15T09:00:00Z'),
          onReschedule: () {}, onBackToUsual: () {})));
      expect(find.text('Last class'), findsOneWidget);
      await tester.pumpWidget(app(NextSessionCard(
          schedule: schedule(), isTeacher: true, busy: false, now: DateTime.parse('2026-12-20T09:00:00Z'),
          onReschedule: () {}, onBackToUsual: () {})));
      expect(find.text('No upcoming classes'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    });
  });

  group('Reschedule sheet', () {
    SessionChange? result;
    DateTime? nextDate;
    TimeOfDay? nextTime;

    Future<void> open(WidgetTester tester, {DateTime? at}) async {
      result = null;
      await tester.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<SessionChange>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RescheduleSheet(
                      schedule: schedule(),
                      now: at ?? now,
                      pickDate: (_, initial, first, last) async => nextDate,
                      pickTime: (_, initial) async => nextTime,
                    ),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
    }

    bool confirmEnabled(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byKey(const Key('reschedule-confirm'))).onPressed != null;

    testWidgets('nothing changed yet: Confirm is off', (tester) async {
      await open(tester);
      expect(confirmEnabled(tester), isFalse);
    });

    testWidgets('another day + note → preview old → new, and Confirm returns the change', (tester) async {
      await open(tester);
      // Tue 8 Dec at the same local time as the class.
      final local = DateTime.parse('2026-12-07T15:00:00Z').toLocal();
      nextDate = DateTime(local.year, local.month, local.day + 1);
      await tester.tap(find.byKey(const Key('reschedule-day')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('reschedule-note')), 'Travelling');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reschedule-preview')), findsOneWidget);
      expect(confirmEnabled(tester), isTrue);
      await tester.tap(find.byKey(const Key('reschedule-confirm')));
      await tester.pumpAndSettle();
      expect(result!.newStart, DateTime.parse('2026-12-08T15:00:00Z'));
      expect(result!.newEnd, DateTime.parse('2026-12-08T16:30:00Z'));
      expect(result!.note, 'Travelling');
    });

    testWidgets('changing the start keeps the class length', (tester) async {
      await open(tester);
      final local = DateTime.parse('2026-12-07T15:00:00Z').toLocal();
      nextTime = TimeOfDay(hour: (local.hour + 1) % 24, minute: local.minute);
      await tester.tap(find.byKey(const Key('reschedule-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reschedule-confirm')));
      await tester.pumpAndSettle();
      expect(result!.newEnd.difference(result!.newStart), const Duration(minutes: 90));
      expect(result!.newStart, DateTime.parse('2026-12-07T16:00:00Z'));
    });

    testWidgets('the last class: told the end date follows it', (tester) async {
      await open(tester, at: DateTime.parse('2026-12-15T09:00:00Z'));
      expect(find.text('This is the last class: if it moves later, the course end date moves with it.'), findsOneWidget);
    });

    testWidgets('the first class: told the start date follows it', (tester) async {
      await open(tester, at: DateTime.parse('2026-11-25T09:00:00Z'));
      expect(find.text('This is the first class: the course start date will move with it.'), findsOneWidget);
    });

    testWidgets('an end before the start: the reason is shown and Confirm is off', (tester) async {
      await open(tester);
      final local = DateTime.parse('2026-12-07T15:00:00Z').toLocal();
      nextTime = TimeOfDay(hour: (local.hour - 1 + 24) % 24, minute: 0);
      await tester.tap(find.byKey(const Key('reschedule-end')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reschedule-error')), findsOneWidget);
      expect(confirmEnabled(tester), isFalse);
    });
  });

  group('Course cards (My courses, catalog): moved-class banner', () {
    final course = <String, dynamic>{
      'selectedDays': ['Monday', 'Wednesday'],
      'startDate': DateTime.parse('2026-11-29T21:00:00Z'),
      'endDate': DateTime.parse('2026-12-15T21:00:00Z'),
      'startTime': DateTime.parse('2026-11-20T15:00:00Z'),
      'endTime': DateTime.parse('2026-11-20T16:30:00Z'),
      'scheduleUtcOffsetMinutes': 180,
    };

    testWidgets('the next class was moved: tag, new time, old time crossed out', (tester) async {
      await tester.pumpWidget(app(MovedClassBanner(course: {
        ...course,
        'sessionMoves': [
          {'originalStart': DateTime.parse('2026-12-07T15:00:00Z'), 'newStart': DateTime.parse('2026-12-08T15:00:00Z'), 'newEnd': DateTime.parse('2026-12-08T16:30:00Z')},
        ],
      }, now: now)));
      expect(find.byKey(const Key('moved-class-banner')), findsOneWidget);
      expect(find.byKey(const Key('rescheduled-tag')), findsOneWidget);
      expect(find.textContaining('Moved from'), findsOneWidget);
    });

    testWidgets('nothing moved (or only a past class was): nothing shown', (tester) async {
      await tester.pumpWidget(app(MovedClassBanner(course: course, now: now)));
      expect(find.byKey(const Key('moved-class-banner')), findsNothing);
      await tester.pumpWidget(app(MovedClassBanner(course: {
        ...course,
        'sessionMoves': [
          {'originalStart': DateTime.parse('2026-11-30T15:00:00Z'), 'newStart': DateTime.parse('2026-12-01T15:00:00Z'), 'newEnd': DateTime.parse('2026-12-01T16:30:00Z')},
        ],
      }, now: now)));
      expect(find.byKey(const Key('moved-class-banner')), findsNothing);
    });
  });
}
