import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Teacher money guard-rails: one balance calculation, server-created withdrawals.
void main() {
  test('nobody reads the non-existent expiryDate any more (money unlocked mid-course)', () {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(f.readAsStringSync().contains("data['expiryDate']"), isFalse, reason: f.path);
    }
  });

  test('the finance page and dashboard use EarningsRules / the money service, not their own formula', () {
    final finance = File('lib/features/teacher_money/presentation/teacher_finance_page.dart').readAsStringSync();
    expect(finance.contains('MoneyScope.of(context).summary()'), isTrue);
    expect(finance.contains("collection('withdrawal_requests').add("), isFalse, reason: 'the server creates requests');
    expect(finance.contains("collection('transactions')"), isFalse);
    final dash = File('lib/features/teacher/presentation/teacher_dashboard.dart').readAsStringSync();
    expect(dash.contains('EarningsRules.balance('), isTrue);
    expect(dash.contains("totalWithdrawn +="), isFalse);
  });

  test('domain is pure; app and server agree on the rules', () {
    final domain = File('lib/features/teacher_money/domain/earnings.dart').readAsStringSync();
    expect(domain.contains('package:'), isFalse);
    expect(domain.contains('static const unlockDelay = Duration(days: 2);'), isTrue);
    expect(domain.contains("method == 'western' ? 10.0 : 0.0"), isTrue);
    final server = File('functions/withdrawals.js').readAsStringSync();
    expect(server.contains('const UNLOCK_DELAY = 2 * DAY;'), isTrue);
    expect(server.contains('method === "western" ? 10 : 0'), isTrue);
    expect(server.contains('w.requestedAmount ?? w.amount ?? w.netAmount'), isTrue);
    expect(server.contains('const EARNED_STATUSES = ["completed", "settled"];'), isTrue);
    expect(domain.contains("static const earnedStatuses = ['completed', 'settled'];"), isTrue,
        reason: 'settled sales count as earned in the app and on the server');
    expect(domain.contains("d['requestedAmount'] ?? d['amount'] ?? d['netAmount']"), isTrue);
  });

  test('the rules stop the app writing withdrawal requests', () {
    final rules = File('firestore.rules').readAsStringSync();
    final block = rules.substring(rules.indexOf('match /withdrawal_requests/{requestId}'));
    expect(block.substring(0, block.indexOf('allow update')).contains('allow create: if false;'), isTrue);
  });
}
