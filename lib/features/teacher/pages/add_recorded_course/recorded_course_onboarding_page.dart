import 'dart:math';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class RecordedCourseOnboardingPage extends StatefulWidget {
  const RecordedCourseOnboardingPage({super.key});

  @override
  State<RecordedCourseOnboardingPage> createState() =>
      _RecordedCourseOnboardingPageState();
}

class _RecordedCourseOnboardingPageState
    extends State<RecordedCourseOnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Timeline (14s loop):
  // 0.00-0.03: Phone mockup appears
  // 0.03-0.22: INTRO — file flies in, progress fills, checkmark pops
  // 0.22-0.24: Brief pause
  // 0.24-0.43: EXPLAINER — file flies in, progress fills, checkmark pops
  // 0.43-0.45: Brief pause
  // 0.45-0.72: CURRICULUM — 3 parts fly in one by one with progress
  // 0.72-0.82: All complete, celebration
  // 0.82-1.00: Hold + reset

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _r(double v, double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);
  double _easeOut(double t) => 1 - pow(1 - t, 3).toDouble();
  double _easeInOut(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3).toDouble() / 2;
  double _spring(double t) {
    if (t >= 1.0) return 1.0;
    return 1 - pow(2.71828, -6 * t) * cos(6 * t);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final p = _ctrl.value;
            return Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc.howItWorks,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          loc.skip,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Phone Mockup ──
                Expanded(
                  child: _buildPhoneMockup(p, loc),
                ),

                const SizedBox(height: 24),

                // Step label (Enhanced typography)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _getLabel(p, loc),
                      key: ValueKey(_getLabel(p, loc)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: AppColors.accentGold.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        loc.gotItLetsStart,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getLabel(double p, AppLocalizations loc) {
    if (p < 0.03) return loc.yourCourseStructure;
    if (p < 0.22) return loc.uploadIntroVideo;
    if (p < 0.43) return loc.uploadExplainerVideo;
    if (p < 0.72) return loc.addCurriculumParts;
    if (p < 0.82) return loc.courseIsComplete;
    return loc.thisWillRepeat;
  }

  Widget _buildPhoneMockup(double p, AppLocalizations loc) {
    final mockupAppear = _easeOut(_r(p, 0.0, 0.03));

    return Transform.scale(
      scale: 0.85 + (0.15 * mockupAppear),
      child: Opacity(
        opacity: mockupAppear,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardBackground.withValues(alpha: 0.9),
                AppColors.cardBackground.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Background content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mini header
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.school_rounded,
                                color: AppColors.accentGold, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            loc.courseBuilder,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Slot 1: Introduction ──
                      _buildSlot(
                        label: loc.introductionVideo,
                        tapToUploadText: loc.tapToUpload,
                        doneText: loc.done,
                        icon: Icons.videocam_rounded,
                        color: Colors.blueAccent,
                        isEmpty: p < 0.06,
                        fileFlying: _r(p, 0.06, 0.12),
                        uploadProgress: _easeInOut(_r(p, 0.12, 0.19)),
                        isComplete: p > 0.19,
                        checkPop: _spring(_r(p, 0.19, 0.22)),
                      ),

                      const SizedBox(height: 12),

                      // ── Slot 2: Explainer ──
                      _buildSlot(
                        label: loc.explainerVideo,
                        tapToUploadText: loc.tapToUpload,
                        doneText: loc.done,
                        icon: Icons.lightbulb_rounded,
                        color: Colors.greenAccent,
                        isEmpty: p < 0.27,
                        fileFlying: _r(p, 0.27, 0.33),
                        uploadProgress: _easeInOut(_r(p, 0.33, 0.40)),
                        isComplete: p > 0.40,
                        checkPop: _spring(_r(p, 0.40, 0.43)),
                      ),

                      const SizedBox(height: 16),

                      // ── Curriculum Header ──
                      Opacity(
                        opacity: _easeOut(_r(p, 0.45, 0.48)),
                        child: Row(
                          children: [
                            const Icon(Icons.list_alt_rounded,
                                color: AppColors.accentGold, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              loc.curriculum,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Curriculum Part 1 ──
                      _buildCurriculumPart(
                        label: loc.part1Basics,
                        color: Colors.orangeAccent,
                        fileFlying: _r(p, 0.49, 0.53),
                        uploadProgress: _easeInOut(_r(p, 0.53, 0.57)),
                        isComplete: p > 0.57,
                        checkPop: _spring(_r(p, 0.57, 0.59)),
                      ),

                      const SizedBox(height: 8),

                      // ── Curriculum Part 2 ──
                      _buildCurriculumPart(
                        label: loc.part2Techniques,
                        color: Colors.pinkAccent,
                        fileFlying: _r(p, 0.59, 0.63),
                        uploadProgress: _easeInOut(_r(p, 0.63, 0.67)),
                        isComplete: p > 0.67,
                        checkPop: _spring(_r(p, 0.67, 0.69)),
                      ),

                      const SizedBox(height: 8),

                      // ── Curriculum Part 3 ──
                      _buildCurriculumPart(
                        label: loc.part3Practice,
                        color: Colors.purpleAccent,
                        fileFlying: _r(p, 0.69, 0.73),
                        uploadProgress: _easeInOut(_r(p, 0.73, 0.77)),
                        isComplete: p > 0.77,
                        checkPop: _spring(_r(p, 0.77, 0.80)),
                      ),
                    ],
                  ),
                ),

                // ── Flying file icons ──
                // Intro file
                if (p >= 0.06 && p < 0.12)
                  _buildFlyingFile(Colors.blueAccent, _easeOut(_r(p, 0.06, 0.12)), 0),
                // Explainer file
                if (p >= 0.27 && p < 0.33)
                  _buildFlyingFile(Colors.greenAccent, _easeOut(_r(p, 0.27, 0.33)), 1),
                // Part 1 file
                if (p >= 0.49 && p < 0.53)
                  _buildFlyingFile(Colors.orangeAccent, _easeOut(_r(p, 0.49, 0.53)), 2),
                // Part 2 file
                if (p >= 0.59 && p < 0.63)
                  _buildFlyingFile(Colors.pinkAccent, _easeOut(_r(p, 0.59, 0.63)), 3),
                // Part 3 file
                if (p >= 0.69 && p < 0.73)
                  _buildFlyingFile(Colors.purpleAccent, _easeOut(_r(p, 0.69, 0.73)), 4),

                // ── Celebration overlay ──
                if (p > 0.80 && p < 0.85)
                  _buildCelebration(_easeOut(_r(p, 0.80, 0.85)), loc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlot({
    required String label,
    required String tapToUploadText,
    required String doneText,
    required IconData icon,
    required Color color,
    required bool isEmpty,
    required double fileFlying,
    required double uploadProgress,
    required bool isComplete,
    required double checkPop,
  }) {
    final borderColor = isComplete
        ? color.withValues(alpha: 0.5)
        : isEmpty
            ? Colors.white.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.3);

    final bgColor = isComplete
        ? color.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.03);

    final bool isUploading = uploadProgress > 0 && uploadProgress < 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isUploading ? 2 : 1.5,
        ),
        boxShadow: isUploading
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon area
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isComplete
                  ? color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isComplete
                ? Transform.scale(
                    scale: checkPop.clamp(0.0, 1.2),
                    child: Icon(Icons.check_rounded, color: color, size: 24),
                  )
                : isEmpty
                    ? Icon(Icons.add_rounded,
                        color: Colors.white.withValues(alpha: 0.2), size: 22)
                    : Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isEmpty
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isEmpty && !isComplete) ...[
                  const SizedBox(height: 6),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: uploadProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                ],
                if (isEmpty)
                  Text(
                    tapToUploadText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.15),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // Percentage or status
          const SizedBox(width: 12),
          if (!isEmpty && !isComplete)
            Text(
              '${(uploadProgress * 100).toInt()}%',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (isComplete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    doneText,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurriculumPart({
    required String label,
    required Color color,
    required double fileFlying,
    required double uploadProgress,
    required bool isComplete,
    required double checkPop,
  }) {
    final appear = fileFlying > 0 || isComplete ? 1.0 : 0.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: appear.clamp(0.0, 1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isComplete
              ? color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isComplete
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Check or play icon
            isComplete
                ? Transform.scale(
                    scale: checkPop.clamp(0.0, 1.2),
                    child: Icon(Icons.check_circle_rounded,
                        color: color, size: 20),
                  )
                : Icon(Icons.play_circle_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.25), size: 20),
            const SizedBox(width: 10),

            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isComplete
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Mini progress or done
            if (!isComplete && uploadProgress > 0)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: uploadProgress,
                  strokeWidth: 2,
                  color: color,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // A file icon that flies from bottom-center up to its slot
  Widget _buildFlyingFile(Color color, double progress, int slotIndex) {
    // Start: bottom center. End: near the slot position.
    final startY = 500.0;
    final endY = 70.0 + (slotIndex * 70.0);
    final currentY = startY + (endY - startY) * progress;

    // Arc: slight horizontal movement
    final arcX = sin(progress * pi) * 30;

    // Scale: starts big, shrinks as it arrives
    final scale = 1.2 - (0.5 * progress);

    // Opacity: fade out at the end
    final opacity = progress < 0.8 ? 1.0 : (1.0 - _r(progress, 0.8, 1.0));

    return Positioned(
      left: 0,
      right: 0,
      top: currentY,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(arcX, 0),
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(Icons.video_file_rounded, color: color, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebration(double progress, AppLocalizations loc) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4 * progress),
        child: Center(
          child: Transform.scale(
            scale: _spring(progress),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.rocket_launch_rounded,
                      color: AppColors.accentGold, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    loc.courseReady,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
