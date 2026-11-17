import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../domain/course_board.dart';
import 'next_session_card.dart';

/// Localized reason a move is refused.
String rescheduleErrorText(AppLocalizations l10n, RescheduleError e, {required bool isLast}) => switch (e) {
      RescheduleError.noNextSession => l10n.rescheduleErrNoNext,
      RescheduleError.endBeforeStart => l10n.rescheduleErrEndBeforeStart,
      RescheduleError.tooLong => l10n.rescheduleErrTooLong,
      RescheduleError.crossesMidnight => l10n.rescheduleErrMidnight,
      RescheduleError.beforeWindow => l10n.rescheduleErrBefore,
      RescheduleError.afterWindow => isLast ? l10n.rescheduleErrAfterLast : l10n.rescheduleErrAfter,
    };

/// Teacher: move the NEXT class. Day (only the allowed days can be picked),
/// start and end time, an optional note; the same rule as the server checks it
/// live and the old → new time is previewed. Returns the change, or null.
Future<SessionChange?> showRescheduleSheet(BuildContext context, {required CourseSchedule schedule, required DateTime now}) {
  return showModalBottomSheet<SessionChange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF16181D),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => RescheduleSheet(schedule: schedule, now: now),
  );
}

class RescheduleSheet extends StatefulWidget {
  final CourseSchedule schedule;
  final DateTime now;

  /// Test seams: the platform date / time pickers.
  final Future<DateTime?> Function(BuildContext, DateTime initial, DateTime first, DateTime last)? pickDate;
  final Future<TimeOfDay?> Function(BuildContext, TimeOfDay initial)? pickTime;

  const RescheduleSheet({super.key, required this.schedule, required this.now, this.pickDate, this.pickTime});

  @override
  State<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<RescheduleSheet> {
  late final RescheduleWindow? _window = widget.schedule.rescheduleWindow(widget.now);
  late DateTime _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = _window?.session;
    final start = (s?.start ?? widget.now).toLocal();
    final end = (s?.end ?? widget.now).toLocal();
    _day = DateTime(start.year, start.month, start.day);
    _start = TimeOfDay.fromDateTime(start);
    _end = TimeOfDay.fromDateTime(end);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  MovePlan get _plan => widget.schedule.planMove(now: widget.now, newStart: _at(_start).toUtc(), newEnd: _at(_end).toUtc());

  Future<void> _chooseDay() async {
    final w = _window!;
    final first = w.earliest.toLocal();
    final lastEnd = w.latestEnd.toLocal().subtract(const Duration(minutes: 1));
    final firstDay = DateTime(first.year, first.month, first.day);
    final lastDay = DateTime(lastEnd.year, lastEnd.month, lastEnd.day);
    final initial = _day.isBefore(firstDay) ? firstDay : (_day.isAfter(lastDay) ? lastDay : _day);
    final picked = await (widget.pickDate ?? _platformDate)(context, initial, firstDay, lastDay);
    if (picked != null) setState(() => _day = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _chooseTime(bool start) async {
    final current = start ? _start : _end;
    final picked = await (widget.pickTime ?? _platformTime)(context, current);
    if (picked == null) return;
    setState(() {
      if (start) {
        // Keep the class length when the start moves.
        final length = (_end.hour * 60 + _end.minute) - (_start.hour * 60 + _start.minute);
        _start = picked;
        final endMinutes = picked.hour * 60 + picked.minute + (length > 0 ? length : 90);
        if (endMinutes < 24 * 60) _end = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
      } else {
        _end = picked;
      }
    });
  }

  static Future<DateTime?> _platformDate(BuildContext context, DateTime initial, DateTime first, DateTime last) =>
      showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last, builder: _dark);

  static Future<TimeOfDay?> _platformTime(BuildContext context, TimeOfDay initial) =>
      showTimePicker(context: context, initialTime: initial, builder: _dark);

  static Widget _dark(BuildContext context, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: AppColors.accentGold, onPrimary: Colors.black, surface: AppColors.primary, onSurface: Colors.white),
        ),
        child: child!,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final w = _window;
    final locale = Localizations.localeOf(context).toString();
    final media = MediaQuery.of(context);

    if (w == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(l10n.rescheduleErrNoNext, style: const TextStyle(color: Colors.white70)),
        ),
      );
    }
    final plan = _plan;
    final session = w.session;
    final dayFormat = DateFormat.yMMMEd(locale);
    final timeFormat = DateFormat.jm(locale);
    final latest = w.latestEnd.toLocal().subtract(const Duration(minutes: 1));

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                  width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(l10n.rescheduleNextClass, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(formatSessionTime(context, session.slotStart, session.originalEnd ?? session.end),
                style: const TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              l10n.rescheduleWindow(dayFormat.format(w.earliest.toLocal()), dayFormat.format(latest)),
              key: const Key('reschedule-window'),
              style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
            ),
            if (w.isFirst) _info(l10n.rescheduleStartDateMoves),
            if (w.isLast) _info(l10n.rescheduleEndDateMoves),
            const SizedBox(height: 18),
            _field(const Key('reschedule-day'), l10n.rescheduleDay, dayFormat.format(_day), Icons.calendar_today, _chooseDay),
            Row(children: [
              Expanded(
                  child: _field(const Key('reschedule-start'), l10n.rescheduleStarts, timeFormat.format(_at(_start)),
                      Icons.schedule, () => _chooseTime(true))),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(const Key('reschedule-end'), l10n.rescheduleEnds, timeFormat.format(_at(_end)),
                      Icons.schedule, () => _chooseTime(false))),
            ]),
            TextField(
              key: const Key('reschedule-note'),
              controller: _note,
              onChanged: (_) => setState(() {}),
              maxLength: 300,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.rescheduleNoteHint,
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                counterStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            if (plan.ok)
              Container(
                key: const Key('reschedule-preview'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(formatSessionTime(context, session.slotStart, session.originalEnd ?? session.end),
                      style: const TextStyle(color: Colors.white54, decoration: TextDecoration.lineThrough)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.orangeAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(formatSessionTime(context, _at(_start), _at(_end)),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ]),
              )
            else
              Text(
                rescheduleErrorText(l10n, plan.error!, isLast: w.isLast),
                key: const Key('reschedule-error'),
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('reschedule-confirm'),
                onPressed: plan.ok && !_unchanged(session)
                    ? () => Navigator.of(context).pop(
                        SessionChange(newStart: _at(_start).toUtc(), newEnd: _at(_end).toUtc(), note: _note.text.trim()))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white10,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(l10n.rescheduleConfirm, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Nothing to send yet: same time as now and no note.
  bool _unchanged(CourseSession session) =>
      _at(_start).toUtc().isAtSameMomentAs(session.start) &&
      _at(_end).toUtc().isAtSameMomentAs(session.end) &&
      _note.text.trim().isEmpty;

  Widget _info(String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.accentGold),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.accentGold, fontSize: 12, height: 1.4))),
        ]),
      );

  Widget _field(Key key, String label, String value, IconData icon, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(icon, size: 18, color: Colors.white54),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
      );
}
