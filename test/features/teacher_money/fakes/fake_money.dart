import 'dart:async';

import 'package:calligro_app/features/teacher_money/domain/earnings.dart';
import 'package:calligro_app/features/teacher_money/domain/earnings_repository.dart';

class FakeEarningsRepository implements EarningsRepository {
  EarningsData data = const EarningsData();
  final requests = <String>[];
  Object? failRequest;
  Completer<void>? hold;

  @override
  Future<EarningsData> load(String teacherId) async => data;

  @override
  Future<WithdrawalReceipt> requestWithdrawal({required String methodLabel}) async {
    if (hold != null) await hold!.future;
    if (failRequest != null) throw failRequest!;
    requests.add(methodLabel);
    return const WithdrawalReceipt(requestedAmount: 100, netAmount: 100, fee: 0);
  }
}
