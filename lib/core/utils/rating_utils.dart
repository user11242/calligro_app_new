// lib/core/utils/rating_utils.dart

/// Utility functions for teacher rating calculations and display.
class RatingUtils {
  /// Calculate average rating from total stars and review count.
  /// Returns 0.0 if reviewCount is 0 to avoid division by zero.
  static double calculateAverageRating(num totalStars, num reviewCount) {
    if (reviewCount == 0) return 0.0;
    return totalStars / reviewCount;
  }

  /// Get rating star data for UI rendering.
  /// Returns a map with:
  /// - 'fullStars': number of completely filled stars (int)
  /// - 'hasHalfStar': whether to show a half star (bool)
  /// - 'emptyStars': number of empty stars (int)
  static Map<String, dynamic> getRatingStarData(double averageRating) {
    // Clamp rating between 0 and 5
    final clampedRating = averageRating.clamp(0.0, 5.0);
    
    final fullStars = clampedRating.floor();
    final hasHalfStar = (clampedRating - fullStars) >= 0.5;
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return {
      'fullStars': fullStars,
      'hasHalfStar': hasHalfStar,
      'emptyStars': emptyStars,
    };
  }

  /// Format rating for display (e.g., "4.5" or "5.0")
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  /// Get a descriptive text for the rating
  static String getRatingDescription(double rating, dynamic l10n) {
    if (rating >= 4.5) return l10n.excellent;
    if (rating >= 4.0) return l10n.veryGood;
    if (rating >= 3.5) return l10n.good;
    if (rating >= 3.0) return l10n.average;
    if (rating >= 2.0) return l10n.belowAverage;
    return l10n.poor;
  }

  /// Validate a star rating input (1-5)
  static bool isValidRating(int stars) {
    return stars >= 1 && stars <= 5;
  }
}
