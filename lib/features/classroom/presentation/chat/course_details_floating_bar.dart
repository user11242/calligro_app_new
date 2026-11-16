import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Persistent bottom floating bar shown across all tabs of CourseDetailsPage,
/// pairing the primary Live Session button with the Course Group Chat FAB.
class CourseDetailsFloatingBar extends StatelessWidget {
  final bool isTeacher;
  final VoidCallback onLiveSessionPressed;
  final VoidCallback onChatPressed;

  const CourseDetailsFloatingBar({
    super.key,
    required this.isTeacher,
    required this.onLiveSessionPressed,
    required this.onChatPressed,
  });

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
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onLiveSessionPressed,
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

