import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

/// "Mon 30 Nov · 18:00 – 19:30" in the phone's language and local time.
String formatSessionTime(BuildContext context, DateTime start, DateTime end) {
  final locale = Localizations.localeOf(context).toString();
  final day = DateFormat.MMMEd(locale).format(start.toLocal());
  final time = DateFormat.jm(locale);
  return '$day · ${time.format(start.toLocal())} – ${time.format(end.toLocal())}';
}

/// A small orange "Rescheduled" tag (used everywhere a moved class appears).
class RescheduledTag extends StatelessWidget {
  final bool compact;
  const RescheduledTag({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('rescheduled-tag'),
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 2 : 4),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.update, size: compact ? 11 : 14, color: Colors.orangeAccent),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.rescheduledTag,
            style: TextStyle(color: Colors.orangeAccent, fontSize: compact ? 10 : 12, fontWeight: FontWeight.w800),
          ),
        ]),
      );
}

/// The course page's "Next class" card: when it is, whether it was moved (old
/// time crossed out + the teacher's note), and for the teacher the buttons to
/// move it (only the next class) or put it back.
class NextSessionCard extends StatelessWidget {
  final CourseSchedule schedule;
  final bool isTeacher;
  final bool busy;
  final DateTime now;
  final VoidCallback onReschedule;
  final VoidCallback onBackToUsual;

  const NextSessionCard({
    super.key,
    required this.schedule,
    required this.isTeacher,
    required this.busy,
    required this.now,
    required this.onReschedule,
    required this.onBackToUsual,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final window = schedule.rescheduleWindow(now);
    final next = window?.session;
    final moved = next?.isRescheduled ?? false;
    final canGoBack = moved && next!.originalStart!.isAfter(now);
    final accent = moved ? Colors.orangeAccent : AppColors.accentGold;

    return Container(
      key: const Key('next-session-card'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: moved ? Colors.orangeAccent.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: moved ? Colors.orangeAccent.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Icon(Icons.event_rounded, color: accent, size: 20),
          Text(l10n.nextClass, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
          if (moved) const RescheduledTag(),
          if (window != null && window.isFirst) _chip(l10n.firstClassTag),
          if (window != null && window.isLast && !window.isFirst) _chip(l10n.lastClassTag),
        ]),
        const SizedBox(height: 14),
        if (next == null)
          Text(l10n.noUpcomingClasses, style: const TextStyle(color: Colors.white70, fontSize: 15))
        else ...[
          Text(
            formatSessionTime(context, next.start, next.end),
            key: const Key('next-session-time'),
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          if (moved) ...[
            const SizedBox(height: 6),
            Text(
              l10n.movedFromTime(formatSessionTime(context, next.originalStart!, next.originalEnd!)),
              key: const Key('next-session-original'),
              style: const TextStyle(color: Colors.white54, fontSize: 13, decoration: TextDecoration.lineThrough),
            ),
            if (next.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.sticky_note_2_outlined, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(next.note, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
              ]),
            ],
          ],
        ],
        if (isTeacher) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('reschedule-next'),
              onPressed: next == null || busy ? null : onReschedule,
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Icon(moved ? Icons.edit_calendar : Icons.more_time, size: 18),
              label: Text(moved ? l10n.rescheduleChangeAgain : l10n.rescheduleNextClass),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                disabledForegroundColor: Colors.white30,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          if (canGoBack)
            Center(
              child: TextButton(
                key: const Key('reschedule-back'),
                onPressed: busy ? null : onBackToUsual,
                child: Text(l10n.rescheduleBackToUsual, style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
        ],
      ]),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

/// On a course card: shown ONLY when the next class of [course] (the course
/// document) was moved — the tag, the new day/time, and the old one crossed out.
class MovedClassBanner extends StatelessWidget {
  final Map<String, dynamic> course;

  /// Test seam (default: now).
  final DateTime? now;
  const MovedClassBanner({super.key, required this.course, this.now});

  @override
  Widget build(BuildContext context) {
    final next = CourseSchedule.fromMap(course, fallbackOffset: DateTime.now().timeZoneOffset).next(now ?? DateTime.now());
    if (next == null || !next.isRescheduled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('moved-class-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const RescheduledTag(compact: true),
          Text(l10n.nextClass, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text(formatSessionTime(context, next.start, next.end),
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(l10n.movedFromTime(formatSessionTime(context, next.originalStart!, next.originalEnd!)),
            style: const TextStyle(color: Colors.white54, fontSize: 12, decoration: TextDecoration.lineThrough)),
      ]),
    );
  }
}
