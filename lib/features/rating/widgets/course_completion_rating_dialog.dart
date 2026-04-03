// lib/features/rating/widgets/course_completion_rating_dialog.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/message/app_messenger.dart';
import '../services/rating_service.dart';

class CourseCompletionRatingDialog extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String teacherId;

  const CourseCompletionRatingDialog({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.teacherId,
  });

  @override
  State<CourseCompletionRatingDialog> createState() =>
      _CourseCompletionRatingDialogState();
}

class _CourseCompletionRatingDialogState
    extends State<CourseCompletionRatingDialog> {
  final RatingService _ratingService = RatingService();
  final TextEditingController _reviewController = TextEditingController();

  int? _selectedRating;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == null) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: AppLocalizations.of(context)!.selectRating,
        type: MessengerType.error,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      await _ratingService.submitRating(
        studentId: currentUser.uid,
        studentName: currentUser.displayName ?? 'Student',
        teacherId: widget.teacherId,
        courseId: widget.courseId,
        courseName: widget.courseName,
        rating: _selectedRating!,
        reviewText: _reviewController.text.trim().isNotEmpty
            ? _reviewController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.thankYouRating,
          message: AppLocalizations.of(context)!.ratingSubmitted,
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Celebration Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentGold.withOpacity(0.2),
                    AppColors.accentGold.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                color: AppColors.accentGold,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // Congratulations Message
            Text(
              AppLocalizations.of(context)!
                  .congratsCourseComplete(widget.courseName),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Prompt
            Text(
              AppLocalizations.of(context)!.rateTeacherPrompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Star Rating Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final isSelected = _selectedRating != null &&
                    starValue <= _selectedRating!;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starValue;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: isSelected
                          ? AppColors.accentGold
                          : AppColors.textLight.withOpacity(0.3),
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Review Text Field
            TextField(
              controller: _reviewController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.writeReview,
                hintStyle: TextStyle(
                  color: AppColors.textLight.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textLight,
                      side: BorderSide(
                        color: AppColors.textLight.withOpacity(0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.skipRating),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            AppLocalizations.of(context)!.submitRating,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Helper function to show the rating dialog
Future<void> showCourseCompletionRatingDialog({
  required BuildContext context,
  required String courseId,
  required String courseName,
  required String teacherId,
}) async {
  // Check if student already rated this course
  final ratingService = RatingService();
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) return;

  final hasRated = await ratingService.hasStudentRatedCourse(
    studentId: currentUser.uid,
    courseId: courseId,
  );

  if (hasRated) {
    // Student already rated this course, don't show dialog
    return;
  }

  if (context.mounted) {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CourseCompletionRatingDialog(
        courseId: courseId,
        courseName: courseName,
        teacherId: teacherId,
      ),
    );
  }
}
