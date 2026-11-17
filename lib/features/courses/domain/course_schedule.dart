/// The ONE rule for "when are this course's classes", rescheduled ones included.
///
/// Every screen asks this (countdown, Join button, course page, home screens),
/// and the server mirrors it (functions/schedule.js, same test cases in
/// test/fixtures/schedule_cases.json), so they can never disagree again.
///
/// Days are counted in the course's time zone ([utcOffset]) so a class is the
/// same moment for everyone; screens show it in the phone's local time.
library;

/// A class: [start]–[end]. When it was moved, [originalStart]/[originalEnd] hold
/// where it used to be and [note] the teacher's message.
class CourseSession {
  final DateTime start;
  final DateTime end;
  final DateTime? originalStart;
  final DateTime? originalEnd;
  final String note;

  const CourseSession({required this.start, required this.end, this.originalStart, this.originalEnd, this.note = ''});

  bool get isRescheduled => originalStart != null;

  /// The regular slot this class belongs to (its original time when moved).
  DateTime get slotStart => originalStart ?? start;
}

/// One moved class: the slot it came from (exact [originalStart], or just the
/// [originalDay] 'yyyy-mm-dd' for reschedules written by older app versions)
/// and its new time.
class SessionMove {
  final DateTime? originalStart;
  final String? originalDay;
  final DateTime newStart;
  final DateTime newEnd;
  final String note;

  const SessionMove({this.originalStart, this.originalDay, required this.newStart, required this.newEnd, this.note = ''});
}

/// When the next class may be moved to: from [earliest] (now, or the day after
/// the previous class) through the whole of [latestDay] (the day before the
/// following class; for the last class, 7 days after the end date).
class RescheduleWindow {
  final CourseSession session;
  final bool isFirst;
  final bool isLast;
  final DateTime earliest;

  /// 'yyyy-mm-dd' in the course's time zone.
  final String latestDay;

  /// The end of [latestDay] (exclusive).
  final DateTime latestEnd;

  const RescheduleWindow({
    required this.session,
    required this.isFirst,
    required this.isLast,
    required this.earliest,
    required this.latestDay,
    required this.latestEnd,
  });
}

enum RescheduleError { noNextSession, endBeforeStart, tooLong, crossesMidnight, beforeWindow, afterWindow }

/// The outcome of moving the next class: an [error], or the course dates after
/// the move (the start date follows a moved first class; the end date follows a
/// last class moved later — never earlier).
class MovePlan {
  final RescheduleError? error;
  final RescheduleWindow? window;
  final DateTime? startDate;
  final DateTime? endDate;
  const MovePlan({this.error, this.window, this.startDate, this.endDate});
  bool get ok => error == null;
}

class CourseSchedule {
  static const lastClassGraceDays = 7;
  static const maxClassLength = Duration(hours: 6);
  static const defaultLength = Duration(minutes: 90);
  static const _maxDays = 800; // safety: at most ~2 years of classes

  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// 1 = Monday … 7 = Sunday.
  final Set<int> weekdays;

  /// The course's public dates (selling, ratings, payouts). A moved first / last
  /// class moves them.
  final DateTime? startDate;
  final DateTime? endDate;

  /// The ORIGINAL date range the regular classes are counted in (the server keeps
  /// it as scheduleStartDate / scheduleEndDate once a move changed the public dates).
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final DateTime? startTime;
  final DateTime? endTime;
  final Duration utcOffset;
  final List<SessionMove> moves;

  const CourseSchedule({
    required this.weekdays,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.utcOffset,
    this.moves = const [],
    DateTime? rangeStart,
    DateTime? rangeEnd,
  })  : rangeStart = rangeStart ?? startDate,
        rangeEnd = rangeEnd ?? endDate;

  static Set<int> weekdaysFromNames(Iterable<String> names) =>
      {for (final n in names) if (_dayNames.contains(n)) _dayNames.indexOf(n) + 1};

  /// From the course document. The course's own time zone
  /// (scheduleUtcOffsetMinutes) wins; older courses use [fallbackOffset] (the phone's).
  factory CourseSchedule.fromMap(Map<String, dynamic> d, {required Duration fallbackOffset}) {
    final off = d['scheduleUtcOffsetMinutes'];
    final offset = off is num ? Duration(minutes: off.toInt()) : fallbackOffset;
    final moves = <SessionMove>[];
    final history = d['sessionMoves'];
    if (history is List) {
      for (final m in history) {
        if (m is Map) {
          final move = _move(m, offset);
          if (move != null) moves.add(move);
        }
      }
    }
    final current = d['rescheduledSession'];
    if (current is Map) {
      final move = _move(current, offset);
      if (move != null) moves.add(move);
    }
    return CourseSchedule(
      weekdays: weekdaysFromNames(d['selectedDays'] is List ? [for (final x in d['selectedDays'] as List) '$x'] : const []),
      startDate: _date(d['startDate']),
      endDate: _date(d['endDate']),
      rangeStart: _date(d['scheduleStartDate']),
      rangeEnd: _date(d['scheduleEndDate']),
      startTime: _date(d['startTime']) ?? _date(d['selectedTime']),
      endTime: _date(d['endTime']),
      utcOffset: offset,
      moves: moves,
    );
  }

  /// Reads both shapes: {originalStart, newStart, newEnd} (sessionMoves) and the
  /// course's rescheduledSession {originalStartTime?, originalDate, newStartTime, newEndTime}.
  static SessionMove? _move(Map m, Duration offset) {
    final newStart = _date(m['newStart']) ?? _date(m['newStartTime']);
    final newEnd = _date(m['newEnd']) ?? _date(m['newEndTime']);
    if (newStart == null || newEnd == null) return null;
    final exact = _date(m['originalStart']) ?? _date(m['originalStartTime']);
    final day = _date(m['originalDate']);
    if (exact == null && day == null) return null;
    final note = m['note'] is String ? m['note'] as String : '';
    return SessionMove(
      originalStart: exact,
      originalDay: exact == null ? _dayKey(_local(day!, offset)) : null,
      newStart: newStart,
      newEnd: newEnd,
      note: note,
    );
  }

  static DateTime? _date(Object? v) {
    if (v is DateTime) return v.toUtc();
    try {
      if (v != null && (v as dynamic).toDate is Function) return ((v as dynamic).toDate() as DateTime).toUtc();
    } catch (_) {}
    return v is String ? DateTime.tryParse(v)?.toUtc() : null;
  }

  // ── Time-zone helpers: a "local" DateTime here is UTC-typed with the course's wall-clock fields ──
  static DateTime _local(DateTime instant, Duration offset) => instant.toUtc().add(offset);
  DateTime _toLocal(DateTime instant) => _local(instant, utcOffset);
  DateTime _fromLocal(DateTime local) => local.subtract(utcOffset);
  static DateTime _day(DateTime local) => DateTime.utc(local.year, local.month, local.day);
  static String _dayKey(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  static DateTime _addDays(DateTime day, int n) => DateTime.utc(day.year, day.month, day.day + n);

  /// How long a class lasts (end time on the next day wraps; nonsense → 90 minutes).
  Duration get length {
    final s = startTime, e = endTime;
    if (s == null || e == null) return defaultLength;
    final ls = _toLocal(s), le = _toLocal(e);
    var d = Duration(hours: le.hour - ls.hour, minutes: le.minute - ls.minute);
    if (d.isNegative) d += const Duration(days: 1);
    if (d.inMinutes <= 0 || d > maxClassLength) return defaultLength;
    return d;
  }

  /// The regular slots (before any move), oldest first.
  List<CourseSession> _regular() {
    final s = startTime, from = rangeStart, to = rangeEnd;
    if (s == null || from == null || weekdays.isEmpty) return const [];
    final time = _toLocal(s);
    final first = _day(_toLocal(from));
    final last = to == null ? _addDays(first, _maxDays) : _day(_toLocal(to));
    final len = length;
    final out = <CourseSession>[];
    for (var day = first, i = 0; !day.isAfter(last) && i < _maxDays; day = _addDays(day, 1), i++) {
      if (!weekdays.contains(day.weekday)) continue;
      final start = _fromLocal(DateTime.utc(day.year, day.month, day.day, time.hour, time.minute));
      out.add(CourseSession(start: start, end: start.add(len)));
    }
    return out;
  }

  /// Every class, moves applied (a moved class keeps its original time), oldest first.
  List<CourseSession> sessions() {
    final out = <CourseSession>[];
    for (final slot in _regular()) {
      SessionMove? move;
      for (final m in moves) {
        final matches = m.originalStart != null
            ? m.originalStart!.isAtSameMomentAs(slot.start)
            : m.originalDay == _dayKey(_toLocal(slot.start));
        if (matches) move = m; // the latest move of a slot wins
      }
      out.add(move == null
          ? slot
          : CourseSession(
              start: move.newStart, end: move.newEnd, originalStart: slot.start, originalEnd: slot.end, note: move.note));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  /// The next class that has not started yet.
  CourseSession? next(DateTime now) {
    for (final s in sessions()) {
      if (s.start.isAfter(now)) return s;
    }
    return null;
  }

  /// The class going on right now.
  CourseSession? live(DateTime now) {
    for (final s in sessions()) {
      if (!now.isBefore(s.start) && now.isBefore(s.end)) return s;
    }
    return null;
  }

  CourseSession? get firstSession {
    final s = sessions();
    return s.isEmpty ? null : s.first;
  }

  CourseSession? get lastSession {
    final s = sessions();
    return s.isEmpty ? null : s.last;
  }

  /// Only the next class can be moved, and only until the following class.
  RescheduleWindow? rescheduleWindow(DateTime now) {
    final all = sessions();
    final i = all.indexWhere((s) => s.start.isAfter(now));
    if (i < 0) return null;
    final session = all[i];
    final prev = i > 0 ? all[i - 1] : null;
    final following = i + 1 < all.length ? all[i + 1] : null;

    var earliest = now.toUtc();
    if (prev != null) {
      final dayAfterPrev = _fromLocal(_addDays(_day(_toLocal(prev.start)), 1));
      if (dayAfterPrev.isAfter(earliest)) earliest = dayAfterPrev;
    }
    final DateTime latestDay;
    if (following != null) {
      latestDay = _addDays(_day(_toLocal(following.start)), -1);
    } else {
      final end = rangeEnd == null ? _day(_toLocal(session.slotStart)) : _day(_toLocal(rangeEnd!));
      latestDay = _addDays(end, lastClassGraceDays);
    }
    return RescheduleWindow(
      session: session,
      isFirst: i == 0,
      isLast: following == null,
      earliest: earliest,
      latestDay: _dayKey(latestDay),
      latestEnd: _fromLocal(_addDays(latestDay, 1)),
    );
  }

  /// Checks moving the next class to [newStart]–[newEnd], and the course dates after it.
  MovePlan planMove({required DateTime now, required DateTime newStart, required DateTime newEnd}) {
    final w = rescheduleWindow(now);
    if (w == null) return const MovePlan(error: RescheduleError.noNextSession);
    if (!newEnd.isAfter(newStart)) return MovePlan(error: RescheduleError.endBeforeStart, window: w);
    if (newEnd.difference(newStart) > maxClassLength) return MovePlan(error: RescheduleError.tooLong, window: w);
    final startDay = _day(_toLocal(newStart));
    final endDay = _day(_toLocal(newEnd.subtract(const Duration(microseconds: 1))));
    if (startDay != endDay) return MovePlan(error: RescheduleError.crossesMidnight, window: w);
    if (newStart.isBefore(w.earliest)) return MovePlan(error: RescheduleError.beforeWindow, window: w);
    if (!newStart.isBefore(w.latestEnd)) return MovePlan(error: RescheduleError.afterWindow, window: w);

    // Always worked out from the ORIGINAL range, so moving the same class again (or
    // undoing) never drifts: first class → start date follows; last class later → end date follows.
    var start = startDate;
    final rs = rangeStart;
    if (w.isFirst && rs != null) {
      final shift = startDay.difference(_day(_toLocal(w.session.slotStart))).inDays;
      start = DateTime.utc(rs.year, rs.month, rs.day + shift, rs.hour, rs.minute, rs.second);
    }
    var end = endDate;
    final re = rangeEnd;
    if (w.isLast && re != null) {
      final shift = startDay.difference(_day(_toLocal(re))).inDays;
      end = shift > 0 ? DateTime.utc(re.year, re.month, re.day + shift, re.hour, re.minute, re.second) : re;
    }
    return MovePlan(window: w, startDate: start?.toUtc(), endDate: end?.toUtc());
  }
}
