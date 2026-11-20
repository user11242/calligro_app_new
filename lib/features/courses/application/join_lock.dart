import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/course_schedule.dart';

/// The remote ON/OFF switch for the students' class-time lock on the Join button.
///
/// Firestore `app_config/features` → `joinLock` (bool). Admins flip it from the admin
/// home ("Join button lock"). While OFF, students can join at any time, on every phone,
/// at once, without an app update. Missing or unreadable = ON (the normal lock).
/// It is live: an open course page follows a flip within seconds.
class JoinLock {
  JoinLock._();

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  static StreamSubscription<Map<String, dynamic>?>? _sub;

  /// The value a features document gives (anything but an explicit `false` = ON).
  static bool enabledFrom(Map<String, dynamic>? features) => features?['joinLock'] != false;

  /// Starts following the switch (once, at app start).
  static void start(Stream<Map<String, dynamic>?> features) {
    _sub ??= features.listen(
      (doc) => enabled.value = enabledFrom(doc),
      onError: (Object _) {}, // unreadable: keep the last known value
    );
  }

  /// For tests.
  @visibleForTesting
  static Future<void> reset() async {
    await _sub?.cancel();
    _sub = null;
    enabled.value = true;
  }

  /// [check] as the student sees it: with the lock OFF, nothing is ever locked.
  static JoinCheck apply(JoinCheck check) => enabled.value ? check : const JoinCheck(JoinStatus.unknown);

  /// Whether the home screen's Join button is enabled: in the class window, or
  /// always when the lock is OFF.
  static bool homeButtonEnabled(JoinCheck check) => !enabled.value || check.status == JoinStatus.open;
}
