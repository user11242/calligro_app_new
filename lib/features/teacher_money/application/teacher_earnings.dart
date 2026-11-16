import '../domain/earnings.dart';
import '../domain/earnings_repository.dart';

class EarningsSummary {
  final Balance balance;
  final EarningsData data;
  const EarningsSummary(this.balance, this.data);
}

enum WithdrawOutcome { requested, noFunds, noPayoutMethod, busy, failed }

class WithdrawResult {
  final WithdrawOutcome outcome;
  final WithdrawalReceipt? receipt;
  final String? message;
  const WithdrawResult(this.outcome, {this.receipt, this.message});
}

/// The teacher's money: one balance calculation (EarningsRules) for every
/// screen, and withdrawals created by the server.
class TeacherEarnings {
  TeacherEarnings({required EarningsRepository repository, required String Function() currentUid, DateTime Function()? clock})
      : _repo = repository,
        _uid = currentUid,
        _now = clock ?? DateTime.now;

  final EarningsRepository _repo;
  final String Function() _uid;
  final DateTime Function() _now;
  bool _busy = false;

  Future<EarningsSummary> summary() async {
    final data = await _repo.load(_uid());
    final balance = EarningsRules.balance(
      sales: data.sales,
      courses: data.courses,
      withdrawals: data.withdrawals,
      now: _now(),
    );
    return EarningsSummary(balance, data);
  }

  /// Withdraw everything available (as before). The server re-checks it all.
  Future<WithdrawResult> withdraw(EarningsSummary current, {required String methodLabel}) async {
    if (current.data.payoutMethod == null) return const WithdrawResult(WithdrawOutcome.noPayoutMethod);
    if (!WithdrawalRules.canWithdraw(current.balance.available, current.data.payoutMethod)) {
      return const WithdrawResult(WithdrawOutcome.noFunds);
    }
    if (_busy) return const WithdrawResult(WithdrawOutcome.busy);
    _busy = true;
    try {
      final receipt = await _repo.requestWithdrawal(methodLabel: methodLabel);
      return WithdrawResult(WithdrawOutcome.requested, receipt: receipt);
    } catch (e) {
      final text = '$e';
      if (text.contains('No funds')) return WithdrawResult(WithdrawOutcome.noFunds, message: text);
      return WithdrawResult(WithdrawOutcome.failed, message: text);
    } finally {
      _busy = false;
    }
  }
}
