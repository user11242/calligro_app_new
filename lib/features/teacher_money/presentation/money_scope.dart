import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../application/teacher_earnings.dart';
import '../data/firestore_earnings_repository.dart';

/// The ONE place that picks the real money implementation.
class MoneyScope extends InheritedWidget {
  const MoneyScope({super.key, required this.earnings, required super.child});
  final TeacherEarnings earnings;
  static TeacherEarnings? _fallback;

  static TeacherEarnings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MoneyScope>()?.earnings ??
      (_fallback ??= TeacherEarnings(
        repository: FirestoreEarningsRepository(),
        currentUid: () => FirebaseAuth.instance.currentUser?.uid ?? '',
      ));

  @override
  bool updateShouldNotify(MoneyScope oldWidget) => earnings != oldWidget.earnings;
}
