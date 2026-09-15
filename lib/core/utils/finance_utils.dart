class FinanceUtils {
  /// Calculates the teacher's earnings and the Calligro buffer
  /// [coursePrice] The total price the student paid (e.g. 54.0)
  /// [commissionRate] The teacher's commission percentage (e.g. 0.60 for 60%)
  /// Returns a map with 'teacherPayout' and 'calligroBuffer'
  static Map<String, double> calculateCommissionSplit(double coursePrice, double commissionRate) {
    if (coursePrice < 0 || commissionRate < 0 || commissionRate > 1.0) {
      throw ArgumentError('Invalid price or commission rate');
    }

    final double teacherPayout = coursePrice * commissionRate;
    final double calligroBuffer = coursePrice - teacherPayout;

    return {
      'teacherPayout': double.parse(teacherPayout.toStringAsFixed(2)),
      'calligroBuffer': double.parse(calligroBuffer.toStringAsFixed(2)),
    };
  }
}
