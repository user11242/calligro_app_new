// lib/features/rating/presentation/course_completion_rating_dialog.dart

import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/message/app_messenger.dart';
import '../../../core/services/translation_service.dart';
import '../application/course_ratings.dart';
import '../domain/rating_models.dart';
import 'rating_scope.dart';

class CourseCompletionRatingDialog extends StatefulWidget {
  final RateableCourse course;
  final String courseName;

  const CourseCompletionRatingDialog({
    super.key,
    required this.course,
    required this.courseName,
  });

  @override
  State<CourseCompletionRatingDialog> createState() =>
      _CourseCompletionRatingDialogState();
}

class _CourseCompletionRatingDialogState
    extends State<CourseCompletionRatingDialog> {
  final TextEditingController _reviewController = TextEditingController();

  int? _selectedRating;
  bool _isSubmitting = false;
  
  String? _translatedCourseName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_translatedCourseName == null) {
      _translateCourseName();
    }
  }

  Future<void> _translateCourseName() async {
    final lang = Localizations.localeOf(context).languageCode;
    final translated = await TranslationService().translate(
      text: widget.courseName,
      target: lang,
    );
    if (mounted) {
      setState(() {
        _translatedCourseName = translated;
      });
    }
  }

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

    setState(() => _isSubmitting = true);
    final result = await RatingScope.of(context).submit(
      widget.course,
      stars: _selectedRating!,
      reviewText: _reviewController.text,
      courseName: widget.courseName,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    final l10n = AppLocalizations.of(context)!;
    if (result.isRated) {
      // Saved now, or already saved (a retry / another device): either way, done.
      Navigator.of(context).pop();
      AppMessenger.showSnackBar(context, title: l10n.thankYouRating, message: l10n.ratingSubmitted, type: MessengerType.success);
    } else if (result.outcome != RatingOutcome.busy) {
      AppMessenger.showSnackBar(
        context,
        title: l10n.error,
        message: result.outcome == RatingOutcome.invalid ? l10n.selectRating : (result.message ?? l10n.error),
        type: MessengerType.error,
      );
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
                  .congratsCourseComplete(_translatedCourseName ?? widget.courseName),
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

/// Shows the rating pop-up for [course] (chosen by CourseRatings.courseToRate,
/// which already recorded that it was shown).
Future<void> showCourseCompletionRatingDialog({
  required BuildContext context,
  required RateableCourse course,
  required String courseName,
}) =>
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CourseCompletionRatingDialog(course: course, courseName: courseName),
    );
