import 'dart:async';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Persistent bottom floating bar shown across all tabs of CourseDetailsPage,
/// pairing the primary Live Session button with the Course Group Chat FAB.
///
/// Students: the live button is LOCKED outside the class window (10 minutes
/// before a class until 30 minutes after it ends — moved classes at their new
/// time), and unlocks on its own at the right moment. [joinCheck] is null for
/// the teacher and admins (they can always open the room).
class CourseDetailsFloatingBar extends StatefulWidget {
  final bool isTeacher;
  final VoidCallback onLiveSessionPressed;
  final VoidCallback onChatPressed;
  final JoinCheck Function()? joinCheck;

  /// Tapped while locked (e.g. explain when it opens).
  final VoidCallback? onLockedPressed;

  const CourseDetailsFloatingBar({
    super.key,
    required this.isTeacher,
    required this.onLiveSessionPressed,
    required this.onChatPressed,
    this.joinCheck,
    this.onLockedPressed,
  });

  @override
  State<CourseDetailsFloatingBar> createState() => _CourseDetailsFloatingBarState();
}

class _CourseDetailsFloatingBarState extends State<CourseDetailsFloatingBar> {
  Timer? _tick;

  bool get isTeacher => widget.isTeacher;
  VoidCallback get onChatPressed => widget.onChatPressed;

  @override
  void initState() {
    super.initState();
    _restartTick();
  }

  @override
  void didUpdateWidget(CourseDetailsFloatingBar old) {
    super.didUpdateWidget(old);
    if ((old.joinCheck == null) != (widget.joinCheck == null)) _restartTick();
  }

  // Re-check every few seconds so the button opens / locks exactly on time.
  void _restartTick() {
    _tick?.cancel();
    _tick = widget.joinCheck == null
        ? null
        : Timer.periodic(const Duration(seconds: 5), (_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildLiveSessionButton(l10n)),
          const SizedBox(width: 12),
          _buildFloatingChatButton(l10n),
        ],
      ),
    );
  }

  Widget _buildLiveSessionButton(AppLocalizations l10n) {
    final check = widget.joinCheck?.call();
    if (check != null && !check.canJoin) return _buildLockedButton(l10n, check);
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        key: const Key('live-session-button'),
        onPressed: widget.onLiveSessionPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ).copyWith(elevation: WidgetStateProperty.all(0)),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.greenAccent, Colors.green.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.video_camera_front,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isTeacher ? l10n.startLiveSession : l10n.joinLiveSession,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Urbanist',
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Locked: grey, a lock, and when it opens ("Opens Wed, Dec 2 5:50 PM") or that the course is over.
  Widget _buildLockedButton(AppLocalizations l10n, JoinCheck check) {
    final locale = Localizations.localeOf(context).toString();
    final opens = check.opensAt?.toLocal();
    final label = check.status == JoinStatus.ended || opens == null
        ? l10n.joinCourseEnded
        : l10n.joinOpensAt('${DateFormat.MMMEd(locale).format(opens)} ${DateFormat.jm(locale).format(opens)}');
    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('live-session-locked'),
          onTap: widget.onLockedPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_clock, size: 22, color: Colors.white54),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    key: const Key('live-session-locked-label'),
                    style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingChatButton(AppLocalizations l10n) {
    return Tooltip(
      message: l10n.courseGroupChat,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.goldGradientStart, AppColors.goldGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentGold.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('floating_course_chat_button'),
            onTap: onChatPressed,
            customBorder: const CircleBorder(),
            child: const Center(
              child: Icon(
                Icons.forum_rounded,
                color: Colors.black,
                size: 25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

