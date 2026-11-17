import 'dart:convert';
import 'dart:io';

import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ONE rule for "when are this course's classes" (rescheduled ones included).
/// The shared cases in test/fixtures/schedule_cases.json are ALSO run by the
/// server (functions/test/schedule.test.js): both sides must agree.
void main() {
  final cases = jsonDecode(File('test/fixtures/schedule_cases.json').readAsStringSync()) as Map<String, dynamic>;
  final c = cases['course'] as Map<String, dynamic>;
  DateTime t(String s) => DateTime.parse(s);
  DateTime? tn(Object? s) => s == null ? null : DateTime.parse(s as String);

  CourseSchedule schedule({List<SessionMove> moves = const []}) => CourseSchedule(
        weekdays: CourseSchedule.weekdaysFromNames(List<String>.from(c['selectedDays'] as List)),
        startDate: t(c['startDate'] as String),
        endDate: t(c['endDate'] as String),
        startTime: t(c['startTime'] as String),
        endTime: t(c['endTime'] as String),
        utcOffset: Duration(minutes: c['offsetMinutes'] as int),
        moves: moves,
      );

  group('shared cases (same answers as the server)', () {
    test('the regular classes', () {
      final starts = schedule().sessions().map((s) => s.start.toUtc().toIso8601String()).toList();
      expect(starts, [for (final s in (cases['sessions']['regular'] as List)) t(s as String).toIso8601String()]);
      expect(schedule().sessions().every((s) => s.end.difference(s.start) == const Duration(minutes: 90)), isTrue);
    });

    for (final w in (cases['windows'] as List).cast<Map<String, dynamic>>()) {
      test('window: ${w['name']}', () {
        final win = schedule().rescheduleWindow(t(w['now'] as String));
        if (w['next'] == null) {
          expect(win, isNull);
          return;
        }
        expect(win!.session.start, t(w['next'] as String));
        expect(win.isFirst, w['isFirst']);
        expect(win.isLast, w['isLast']);
        expect(win.earliest, t(w['earliest'] as String));
        expect(win.latestDay, w['latestDay']);
      });
    }

    for (final m in (cases['moves'] as List).cast<Map<String, dynamic>>()) {
      test('move: ${m['name']}', () {
        final result = schedule().planMove(now: t(m['now'] as String), newStart: t(m['newStart'] as String), newEnd: t(m['newEnd'] as String));
        if (m['ok'] == true) {
          expect(result.error, isNull, reason: '${result.error}');
          expect(result.startDate, tn(m['startDate']));
          expect(result.endDate, tn(m['endDate']));
        } else {
          expect(result.error?.name, m['error']);
        }
      });
    }
  });

  group('moved classes show up everywhere with the tag', () {
    final moveFirst = SessionMove(
      originalStart: t('2026-11-30T15:00:00Z'),
      newStart: t('2026-12-01T16:00:00Z'),
      newEnd: t('2026-12-01T17:30:00Z'),
      note: 'Travelling, sorry!',
    );

    test('the moved class replaces the original slot, keeps the original time, and is marked rescheduled', () {
      final s = schedule(moves: [moveFirst]).sessions();
      expect(s.first.start, t('2026-12-01T16:00:00Z'));
      expect(s.first.isRescheduled, isTrue);
      expect(s.first.originalStart, t('2026-11-30T15:00:00Z'));
      expect(s.first.note, 'Travelling, sorry!');
      expect(s.where((x) => x.start == t('2026-11-30T15:00:00Z')), isEmpty);
      expect(s.length, 6);
      expect(s.skip(1).every((x) => !x.isRescheduled), isTrue);
    });

    test('next / live: the countdown and the Join button use the moved time', () {
      final sch = schedule(moves: [moveFirst]);
      expect(sch.next(t('2026-11-30T15:10:00Z'))!.start, t('2026-12-01T16:00:00Z'));
      expect(sch.live(t('2026-11-30T15:10:00Z')), isNull, reason: 'nothing at the original time any more');
      expect(sch.live(t('2026-12-01T16:30:00Z'))!.isRescheduled, isTrue);
    });

    test('an earlier move stays applied after a later class is moved (a second move does not bring back the first)', () {
      final moveSecond = SessionMove(
          originalStart: t('2026-12-02T15:00:00Z'), newStart: t('2026-12-02T17:00:00Z'), newEnd: t('2026-12-02T18:00:00Z'));
      final s = schedule(moves: [moveFirst, moveSecond]).sessions();
      expect(s.where((x) => x.isRescheduled).length, 2);
      expect(s.where((x) => x.start == t('2026-11-30T15:00:00Z')), isEmpty);
    });

    test('a new move of the SAME class replaces its previous move', () {
      final again = SessionMove(
          originalStart: t('2026-11-30T15:00:00Z'), newStart: t('2026-11-30T17:00:00Z'), newEnd: t('2026-11-30T18:00:00Z'));
      final s = schedule(moves: [moveFirst, again]).sessions();
      expect(s.first.start, t('2026-11-30T17:00:00Z'));
      expect(s.length, 6);
    });

    test('rescheduling again uses the ORIGINAL slot (the window is the same)', () {
      final win = schedule(moves: [moveFirst]).rescheduleWindow(t('2026-11-25T09:00:00Z'))!;
      expect(win.session.originalStart, t('2026-11-30T15:00:00Z'));
      expect(win.latestDay, '2026-12-01');
    });

    test('the course end shows the moved last class (rating / payout timing follow it)', () {
      final moveLast = SessionMove(
          originalStart: t('2026-12-16T15:00:00Z'), newStart: t('2026-12-19T15:00:00Z'), newEnd: t('2026-12-19T16:30:00Z'));
      expect(schedule(moves: [moveLast]).lastSession!.end, t('2026-12-19T16:30:00Z'));
    });
  });

  group('reading the course document', () {
    test('old app versions: a reschedule with only originalDate (that day) is matched by day', () {
      final sch = CourseSchedule.fromMap({
        ...c,
        'rescheduledSession': {
          'originalDate': DateTime.parse('2026-12-07T06:00:00Z'), // some time on Mon 7 Dec (local)
          'newStartTime': DateTime.parse('2026-12-07T17:00:00Z'),
          'newEndTime': DateTime.parse('2026-12-07T18:00:00Z'),
        },
      }, fallbackOffset: Duration.zero);
      final mon7 = sch.sessions().firstWhere((s) => s.isRescheduled);
      expect(mon7.start, t('2026-12-07T17:00:00Z'));
      expect(mon7.originalStart, t('2026-12-07T15:00:00Z'));
    });

    test('the course time zone wins over the phone\'s (everyone sees the same classes)', () {
      final sch = CourseSchedule.fromMap({...c, 'scheduleUtcOffsetMinutes': 180}, fallbackOffset: const Duration(hours: -5));
      expect(sch.sessions().first.start, t('2026-11-30T15:00:00Z'));
    });

    test('history list + current reschedule: both applied, no duplicates', () {
      final sch = CourseSchedule.fromMap({
        ...c,
        'scheduleUtcOffsetMinutes': 180,
        'sessionMoves': [
          {'originalStart': DateTime.parse('2026-11-30T15:00:00Z'), 'newStart': DateTime.parse('2026-12-01T15:00:00Z'), 'newEnd': DateTime.parse('2026-12-01T16:30:00Z')},
        ],
        'rescheduledSession': {
          'originalStartTime': DateTime.parse('2026-11-30T15:00:00Z'),
          'originalDate': DateTime.parse('2026-11-30T15:00:00Z'),
          'newStartTime': DateTime.parse('2026-12-01T15:00:00Z'),
          'newEndTime': DateTime.parse('2026-12-01T16:30:00Z'),
        },
      }, fallbackOffset: Duration.zero);
      expect(sch.sessions().where((s) => s.isRescheduled).length, 1);
      expect(sch.sessions().length, 6);
    });

    test('first class moved later + start date followed: the moved class still exists (original range is used)', () {
      final sch = CourseSchedule.fromMap({
        ...c,
        'scheduleUtcOffsetMinutes': 180,
        'startDate': DateTime.parse('2026-11-30T21:00:00Z'), // public start: Tue 1 Dec
        'scheduleStartDate': DateTime.parse(c['startDate'] as String), // original: Mon 30 Nov
        'sessionMoves': [
          {'originalStart': DateTime.parse('2026-11-30T15:00:00Z'), 'newStart': DateTime.parse('2026-12-01T15:00:00Z'), 'newEnd': DateTime.parse('2026-12-01T16:30:00Z')},
        ],
      }, fallbackOffset: Duration.zero);
      expect(sch.sessions(), hasLength(6));
      expect(sch.firstSession!.start, t('2026-12-01T15:00:00Z'));
      expect(sch.firstSession!.isRescheduled, isTrue);
    });

    test('missing data: no classes, no crash', () {
      expect(CourseSchedule.fromMap(const {}, fallbackOffset: Duration.zero).sessions(), isEmpty);
      expect(CourseSchedule.fromMap({'selectedDays': ['Monday']}, fallbackOffset: Duration.zero).next(DateTime.now()), isNull);
    });

    test('class length: end time on the next day wraps; nonsense falls back to 90 minutes', () {
      final late = CourseSchedule.fromMap({
        ...c,
        'startTime': DateTime.parse('2026-11-20T20:30:00Z'),
        'endTime': DateTime.parse('2026-11-20T21:30:00Z'),
      }, fallbackOffset: const Duration(hours: 3));
      expect(late.length, const Duration(hours: 1));
      final none = CourseSchedule.fromMap({...c, 'endTime': null}, fallbackOffset: const Duration(hours: 3));
      expect(none.length, const Duration(minutes: 90));
    });

    test('a course that has ended has no next class (the old countdown kept counting past the end)', () {
      expect(schedule().next(t('2026-12-17T00:00:00Z')), isNull);
    });
  });
}
