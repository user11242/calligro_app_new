import 'earnings.dart';

/// Everything the teacher's money screens read.
class EarningsData {
  final List<Sale> sales;
  final List<CourseDates> courses;
  final List<Withdrawal> withdrawals;
  final String teacherName;

  /// 0.7 = 70%; null = not set by an admin yet.
  final double? commissionRate;

  /// 'cliq' | 'bankTransfer' | null (no payout details saved).
  final String? payoutMethod;

  const EarningsData({
    this.sales = const [],
    this.courses = const [],
    this.withdrawals = const [],
    this.teacherName = 'Teacher',
    this.commissionRate,
    this.payoutMethod,
  });
}

class WithdrawalReceipt {
  final double requestedAmount;
  final double netAmount;
  final double fee;
  const WithdrawalReceipt({required this.requestedAmount, required this.netAmount, required this.fee});
}

abstract interface class EarningsRepository {
  Future<EarningsData> load(String teacherId);

  /// The server creates the request from the real balance (functions/withdrawals.js).
  Future<WithdrawalReceipt> requestWithdrawal({required String methodLabel});
}
