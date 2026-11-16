import 'package:calligro_app/features/teacher_money/domain/earnings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16);

  group('when money unlocks (THE BUG: it unlocked 32 days after creation, even mid-course)', () {
    test('2 days after the course ends', () {
      final c = CourseDates(courseId: 'c', endDate: DateTime(2026, 12, 30), createdAt: DateTime(2026, 10, 1));
      expect(EarningsRules.unlockDate(c, now), DateTime(2027, 1, 1));
    });
    test('no end date: the old rule (created + 30 days + 2)', () {
      expect(EarningsRules.unlockDate(CourseDates(courseId: 'c', createdAt: DateTime(2026, 10, 1)), now), DateTime(2026, 11, 2));
    });
    test('unknown course: never unlocked here', () => expect(EarningsRules.unlockDate(null, now), isNull));
  });

  group('balance', () {
    final running = CourseDates(courseId: 'running', endDate: DateTime(2027, 1, 30), createdAt: DateTime(2026, 9, 1));
    final ended = CourseDates(courseId: 'ended', endDate: DateTime(2026, 11, 1), createdAt: DateTime(2026, 8, 1));

    test('a long course created 2+ months ago but still running stays PENDING', () {
      final b = EarningsRules.balance(
        sales: const [Sale(courseId: 'running', teacherShare: 70)],
        courses: [running],
        withdrawals: const [],
        now: now,
      );
      expect([b.total, b.pending, b.available], [70, 70, 0]);
    });

    test('ended courses are available; unknown courses pending', () {
      final b = EarningsRules.balance(
        sales: const [Sale(courseId: 'ended', teacherShare: 60), Sale(courseId: 'ended', teacherShare: 40), Sale(courseId: 'gone', teacherShare: 5)],
        courses: [ended],
        withdrawals: const [],
        now: now,
      );
      expect([b.total, b.pending, b.available], [105, 5, 100]);
    });

    test('a withdrawal takes its FULL amount (THE BUG: the fee came back as balance)', () {
      final b = EarningsRules.balance(
        sales: const [Sale(courseId: 'ended', teacherShare: 100)],
        courses: [ended],
        withdrawals: [Withdrawal.fromMap({'requestedAmount': 100, 'netAmount': 90, 'amount': 90, 'fee': 10, 'status': 'pending'})],
        now: now,
      );
      expect([b.available, b.withdrawn], [0, 100]);
    });

    test('rejected withdrawals give the money back; older requests without requestedAmount still count', () {
      final b = EarningsRules.balance(
        sales: const [Sale(courseId: 'ended', teacherShare: 100)],
        courses: [ended],
        withdrawals: [
          Withdrawal.fromMap({'requestedAmount': 80, 'status': 'rejected'}),
          Withdrawal.fromMap({'amount': 30, 'status': 'completed'}),
        ],
        now: now,
      );
      expect([b.available, b.withdrawn], [70, 30]);
    });

    test('never below zero', () {
      final b = EarningsRules.balance(
        sales: const [],
        courses: const [],
        withdrawals: [Withdrawal.fromMap({'requestedAmount': 50, 'status': 'completed'})],
        now: now,
      );
      expect(b.available, 0);
    });
  });

  group('withdrawing (unchanged rules)', () {
    test('fees and what the teacher receives', () {
      expect(WithdrawalRules.fee('western'), 10);
      expect(WithdrawalRules.fee('cliq'), 0);
      expect(WithdrawalRules.fee('bankTransfer'), 0);
      expect(WithdrawalRules.net(100, 'western'), 90);
    });
    test('only with a payout method and something left after the fee', () {
      expect(WithdrawalRules.canWithdraw(100, 'cliq'), isTrue);
      expect(WithdrawalRules.canWithdraw(0, 'cliq'), isFalse);
      expect(WithdrawalRules.canWithdraw(8, 'western'), isFalse);
      expect(WithdrawalRules.canWithdraw(100, null), isFalse);
    });
  });
}
