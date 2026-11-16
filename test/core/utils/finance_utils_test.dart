import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/core/utils/finance_utils.dart';

void main() {
  group('FinanceUtils.calculateCommissionSplit', () {
    test('calculates 60% teacher commission correctly', () {
      final result = FinanceUtils.calculateCommissionSplit(54.0, 0.60);
      
      expect(result['teacherPayout'], equals(32.40));
      expect(result['calligroBuffer'], equals(21.60));
    });

    test('calculates 30% recorded course commission correctly', () {
      final result = FinanceUtils.calculateCommissionSplit(54.0, 0.30);
      
      expect(result['teacherPayout'], equals(16.20));
      expect(result['calligroBuffer'], equals(37.80));
    });

    test('throws ArgumentError on negative price', () {
      expect(
        () => FinanceUtils.calculateCommissionSplit(-10.0, 0.60),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError on invalid commission rate (e.g. 1.5 for 150%)', () {
      expect(
        () => FinanceUtils.calculateCommissionSplit(54.0, 1.50),
        throwsArgumentError,
      );
    });
  });
}
