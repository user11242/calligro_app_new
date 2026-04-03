// lib/core/widgets/rating_display.dart

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/rating_utils.dart';
import '../../l10n/app_localizations.dart';

/// A reusable widget to display teacher ratings with stars and review count.
/// 
/// Supports two display modes:
/// - Compact: Small stars with review count
/// - Expanded: Larger stars with rating number and review count
class RatingDisplay extends StatelessWidget {
  final double averageRating;
  final int reviewCount;
  final bool isCompact;
  final Color? starColor;
  final double? starSize;

  const RatingDisplay({
    super.key,
    required this.averageRating,
    required this.reviewCount,
    this.isCompact = true,
    this.starColor,
    this.starSize,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return _buildNoReviews(context);
    }

    final starData = RatingUtils.getRatingStarData(averageRating);
    final effectiveStarColor = starColor ?? AppColors.accentGold;
    final effectiveStarSize = starSize ?? (isCompact ? 14.0 : 18.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display rating number (only in expanded mode)
        if (!isCompact) ...[
          Text(
            RatingUtils.formatRating(averageRating),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
        ],

        // Star icons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full stars
            ...List.generate(
              starData['fullStars'] as int,
              (index) => Icon(
                Icons.star,
                color: effectiveStarColor,
                size: effectiveStarSize,
              ),
            ),
            // Half star
            if (starData['hasHalfStar'] as bool)
              Icon(
                Icons.star_half,
                color: effectiveStarColor,
                size: effectiveStarSize,
              ),
            // Empty stars
            ...List.generate(
              starData['emptyStars'] as int,
              (index) => Icon(
                Icons.star_border,
                color: effectiveStarColor.withOpacity(0.3),
                size: effectiveStarSize,
              ),
            ),
          ],
        ),

        const SizedBox(width: 6),

        // Review count
        Flexible(
          child: Text(
            '($reviewCount)',
            style: TextStyle(
              color: AppColors.textLight.withOpacity(0.7),
              fontSize: isCompact ? 12 : 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildNoReviews(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_border,
          color: AppColors.textLight.withOpacity(0.3),
          size: starSize ?? (isCompact ? 14.0 : 18.0),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.noReviewsYet,
            style: TextStyle(
              color: AppColors.textLight.withOpacity(0.5),
              fontSize: isCompact ? 11 : 13,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A more detailed rating display with description
class RatingDisplayDetailed extends StatelessWidget {
  final double averageRating;
  final int reviewCount;

  const RatingDisplayDetailed({
    super.key,
    required this.averageRating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textLight.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_border,
              color: AppColors.textLight.withOpacity(0.3),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.noReviewsYet,
              style: TextStyle(
                color: AppColors.textLight.withOpacity(0.6),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentGold.withOpacity(0.15),
            AppColors.accentGold.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentGold.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large rating number
          Text(
            RatingUtils.formatRating(averageRating),
            style: const TextStyle(
              color: AppColors.accentGold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stars
              RatingDisplay(
                averageRating: averageRating,
                reviewCount: reviewCount,
                isCompact: false,
              ),
              const SizedBox(height: 2),
              // Description
              Text(
                RatingUtils.getRatingDescription(averageRating, AppLocalizations.of(context)!),
                style: TextStyle(
                  color: AppColors.textLight.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
