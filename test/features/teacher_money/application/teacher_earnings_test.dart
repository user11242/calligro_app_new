import 'dart:async';

import 'package:calligro_app/features/teacher_money/application/teacher_earnings.dart';
import 'package:calligro_app/features/teacher_money/domain/earnings.dart';
import 'package:calligro_app/features/teacher_money/domain/earnings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_money.dart';

void main() {
  late FakeEarningsRepository repo;
  late TeacherEarnings earnings;
  final now = DateTime(2026, 11, 16);

  setUp(() {
    repo = FakeEarningsRepository()
      ..data = EarningsData(
        teacherName: 'Ali',
        commissionRate: 0.7,
        payoutMethod: 'cliq',
        sales: const [Sale(courseId: 'ended', teacherShare: 100), Sale(courseId: 'running', teacherShare: 70)],
        courses: [
          CourseDates(courseId: 'ended', endDate: DateTime(2026, 11, 1)),
          CourseDates(courseId: 'running', endDate: DateTime(2027, 1, 30), createdAt: DateTime(2026, 9, 1)),
        ],
      );
    earnings = TeacherEarnings(repository: repo, currentUid: () => 't1', clock: () => now);
  });

  test('summary uses the one balance calculation', () async {
    final s = await earnings.summary();
    expect([s.balance.total, s.balance.pending, s.balance.available], [170, 70, 100]);
    expect(s.data.teacherName, 'Ali');
  });

  test('withdraw: the server creates the request', () async {
    final r = await earnings.withdraw(await earnings.summary(), methodLabel: 'CliQ');
    expect(r.outcome, WithdrawOutcome.requested);
    expect(repo.requests, ['CliQ']);
  });

  test('nothing available or no payout method: not even asked', () async {
    repo.data = const EarningsData(payoutMethod: 'cliq');
    expect((await earnings.withdraw(await earnings.summary(), methodLabel: 'CliQ')).outcome, WithdrawOutcome.noFunds);
    repo.data = const EarningsData(sales: [Sale(courseId: 'x', teacherShare: 5)]);
    expect((await earnings.withdraw(await earnings.summary(), methodLabel: 'x')).outcome, WithdrawOutcome.noPayoutMethod);
    expect(repo.requests, isEmpty);
  });

  test('double tap → one request; the server saying "no funds" is reported as such', () async {
    final s = await earnings.summary();
    repo.hold = Completer<void>();
    final first = earnings.withdraw(s, methodLabel: 'CliQ');
    await Future<void>.delayed(Duration.zero);
    expect((await earnings.withdraw(s, methodLabel: 'CliQ')).outcome, WithdrawOutcome.busy);
    repo.hold!.complete();
    expect((await first).outcome, WithdrawOutcome.requested);
    expect(repo.requests, hasLength(1));

    repo.failRequest = Exception('No funds available to withdraw.');
    expect((await earnings.withdraw(s, methodLabel: 'CliQ')).outcome, WithdrawOutcome.noFunds);
  });
}
