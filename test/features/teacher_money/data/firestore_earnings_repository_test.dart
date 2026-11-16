import 'package:calligro_app/features/teacher_money/data/firestore_earnings_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads sales (completed only), course dates, withdrawals, name, share and payout method', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/t1').set({'name': 'Ali', 'commissionRate': 0.7});
    await db.doc('users/t1/private/payout').set({'selectedMethod': 'cliq', 'cliqAlias': 'ALI'});
    await db.doc('courses/c1').set({'teacherId': 't1', 'endDate': Timestamp.fromDate(DateTime(2026, 11, 1))});
    await db.doc('courses/other').set({'teacherId': 't2'});
    await db.collection('transactions').add({'teacherId': 't1', 'courseId': 'c1', 'teacherShare': 70, 'status': 'completed'});
    await db.collection('transactions').add({'teacherId': 't1', 'courseId': 'c1', 'teacherShare': 70, 'status': 'refunded'});
    await db.collection('withdrawal_requests').add({'teacherId': 't1', 'requestedAmount': 50, 'netAmount': 40, 'status': 'pending'});

    final d = await FirestoreEarningsRepository(firestore: db).load('t1');
    expect([d.teacherName, d.commissionRate, d.payoutMethod], ['Ali', 0.7, 'cliq']);
    expect(d.sales.single.teacherShare, 70);
    expect(d.courses.single.endDate, DateTime(2026, 11, 1));
    expect(d.withdrawals.single.requestedAmount, 50, reason: 'full amount, not after the fee');
  });
}
