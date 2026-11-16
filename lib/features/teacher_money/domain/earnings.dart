/// A teacher's money (pure Dart). ONE calculation for the finance page, the
/// dashboard and the server (functions/withdrawals.js keeps the same rules).
library;

/// A completed sale: what the teacher earns from it, and for which course.
class Sale {
  final String courseId;
  final double teacherShare;
  const Sale({required this.courseId, required this.teacherShare});
}

/// When a course's earnings unlock (see [EarningsRules.unlockDate]).
class CourseDates {
  final String courseId;
  final DateTime? endDate;
  final DateTime? createdAt;
  const CourseDates({required this.courseId, this.endDate, this.createdAt});
}

class Withdrawal {
  /// The full amount taken from the balance (before any fee).
  final double requestedAmount;
  final String status;
  const Withdrawal({required this.requestedAmount, required this.status});

  bool get countsAgainstBalance => status != 'rejected';

  /// Older requests may lack requestedAmount; amount / netAmount are what they stored.
  factory Withdrawal.fromMap(Map<String, dynamic> d) {
    double n(Object? v) => v is num ? v.toDouble() : 0.0;
    final requested = d['requestedAmount'] ?? d['amount'] ?? d['netAmount'];
    return Withdrawal(requestedAmount: n(requested), status: d['status'] is String ? d['status'] as String : 'pending');
  }
}

class Balance {
  final double total;
  final double pending;
  final double available;
  final double withdrawn;
  const Balance({this.total = 0, this.pending = 0, this.available = 0, this.withdrawn = 0});
}

class EarningsRules {
  EarningsRules._();

  static const unlockDelay = Duration(days: 2);

  /// Earnings unlock 2 days after the course ENDS. (The code read a field no
  /// course has — expiryDate — and always fell back to creation + 32 days, so
  /// money unlocked while long courses were still running.) Courses without an
  /// end date keep the old rule: created + 30 days + 2.
  static DateTime? unlockDate(CourseDates? c, DateTime now) {
    if (c == null) return null;
    final end = c.endDate ?? c.createdAt?.add(const Duration(days: 30)) ?? now;
    return end.add(unlockDelay);
  }

  /// Total earned, still locked, available to withdraw, already withdrawn.
  /// Withdrawals count their FULL requested amount (the fee is part of it —
  /// counting only the amount after the fee gave the fee back as balance).
  static Balance balance({
    required List<Sale> sales,
    required List<CourseDates> courses,
    required List<Withdrawal> withdrawals,
    required DateTime now,
  }) {
    final byCourse = {for (final c in courses) c.courseId: c};
    var total = 0.0, pending = 0.0, unlocked = 0.0;
    for (final s in sales) {
      total += s.teacherShare;
      final unlock = unlockDate(byCourse[s.courseId], now);
      if (unlock == null || now.isBefore(unlock)) {
        pending += s.teacherShare;
      } else {
        unlocked += s.teacherShare;
      }
    }
    final withdrawn = withdrawals.where((w) => w.countsAgainstBalance).fold(0.0, (a, w) => a + w.requestedAmount);
    final available = unlocked - withdrawn;
    return Balance(total: total, pending: pending, available: available < 0 ? 0 : available, withdrawn: withdrawn);
  }
}

class WithdrawalRules {
  WithdrawalRules._();

  /// Western Union costs 10; bank transfer and CliQ are free (unchanged).
  static double fee(String? method) => method == 'western' ? 10.0 : 0.0;

  /// What the teacher receives for withdrawing [available]. Nothing → cannot withdraw.
  static double net(double available, String? method) => available - fee(method);

  static bool canWithdraw(double available, String? method) => method != null && net(available, method) > 0;
}
