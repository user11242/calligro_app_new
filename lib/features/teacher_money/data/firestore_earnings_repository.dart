import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:calligro_app/features/teacher_money/data/payout_settings_repository.dart';

import '../domain/earnings.dart';
import '../domain/earnings_repository.dart';

class FirestoreEarningsRepository implements EarningsRepository {
  FirestoreEarningsRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore,
        _fn = functions;
  final FirebaseFirestore? _db;
  final FirebaseFunctions? _fn;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  @override
  Future<EarningsData> load(String teacherId) async {
    final results = await Future.wait([
      db.collection('users').doc(teacherId).get(),
      db.collection('courses').where('teacherId', isEqualTo: teacherId).get(),
      db.collection('transactions').where('teacherId', isEqualTo: teacherId).where('status', whereIn: EarningsRules.earnedStatuses).get(),
      db.collection('withdrawal_requests').where('teacherId', isEqualTo: teacherId).get(),
    ]);
    final user = (results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ?? const {};
    final courses = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final sales = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final withdrawals = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final payout = await PayoutSettingsRepository(firestore: db).load(teacherId);
    return EarningsData(
      teacherName: user['name'] is String ? user['name'] as String : 'Teacher',
      commissionRate: user['commissionRate'] is num ? (user['commissionRate'] as num).toDouble() : null,
      payoutMethod: payout?.selectedMethod,
      courses: [
        for (final d in courses.docs)
          CourseDates(courseId: d.id, endDate: _date(d.data()['endDate']), createdAt: _date(d.data()['createdAt'])),
      ],
      sales: [
        for (final d in sales.docs)
          Sale(
            courseId: d.data()['courseId'] is String ? d.data()['courseId'] as String : '',
            teacherShare: d.data()['teacherShare'] is num ? (d.data()['teacherShare'] as num).toDouble() : 0.0,
          ),
      ],
      withdrawals: [for (final d in withdrawals.docs) Withdrawal.fromMap(d.data())],
    );
  }

  @override
  Future<WithdrawalReceipt> requestWithdrawal({required String methodLabel}) async {
    try {
      final r = await (_fn ?? FirebaseFunctions.instanceFor(region: 'us-central1'))
          .httpsCallable('requestWithdrawal')
          .call({'method': methodLabel});
      final m = r.data is Map ? r.data as Map : const {};
      double n(Object? v) => v is num ? v.toDouble() : 0.0;
      return WithdrawalReceipt(requestedAmount: n(m['requestedAmount']), netAmount: n(m['netAmount']), fee: n(m['fee']));
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Withdrawal failed.');
    }
  }
}
