/// Admin rules (pure Dart): what changing a role, approving, suspending and
/// deleting an account write. Every admin action uses these, so the same
/// action always leaves the data in the same shape.
library;

import 'package:calligro_app/features/auth/domain/account_keys.dart';

/// The writes for moving a user to [newRole] (users/{uid} + the role folders).
class RolePlan {
  final Map<String, dynamic> userUpdate;

  /// The role folder to (re)create with the full profile, if any.
  final String? setCollection;
  final Map<String, dynamic> setData;
  final List<String> deleteCollections;

  const RolePlan({
    required this.userUpdate,
    this.setCollection,
    this.setData = const {},
    this.deleteCollections = const [],
  });

  bool get isNoChange => userUpdate.isEmpty;
}

class AdminRules {
  AdminRules._();

  /// Unchanged behaviour of "Change role", now also used by "Promote to admin"
  /// (which left the teacher/student entry behind, so admins still showed up in
  /// teacher lists) and "Revoke admin" (which made a student without a
  /// students entry).
  static RolePlan changeRole(Map<String, dynamic> user, String newRole) {
    final oldRole = user['role'] is String ? user['role'] as String : 'student';
    if (oldRole == newRole) return const RolePlan(userUpdate: {});
    final update = <String, dynamic>{
      'role': newRole,
      if (newRole == 'teacher') 'approved': true,
      if (newRole == 'teacher') 'status': 'approved',
    };
    final full = {...user, ...update};
    return switch (newRole) {
      'teacher' => RolePlan(userUpdate: update, setCollection: 'teachers', setData: full, deleteCollections: const ['students']),
      'student' => RolePlan(userUpdate: update, setCollection: 'students', setData: full, deleteCollections: const ['teachers']),
      'admin' => RolePlan(userUpdate: update, deleteCollections: const ['students', 'teachers']),
      _ => RolePlan(userUpdate: update),
    };
  }

  /// Approving a teacher (also how a suspended teacher is restored).
  static const approve = {'status': 'approved'};

  /// Suspending a teacher: back to "pending". The app routes by `status` and
  /// course creation checks status OR approved — only setting approved:false
  /// (as before) blocked nothing. Restored with the existing Approve button.
  static Map<String, dynamic> suspend(Object now) => {'status': 'pending', 'approved': false, 'suspendedAt': now};

  static bool isValidCommissionPercent(double percent) => percent >= 0 && percent <= 100;

  /// The "taken" reservations to release when an account is deleted (same keys
  /// as registration — the admin delete used its own phone format).
  static Map<String, String> reservationsOf(Map<String, dynamic> user) {
    String s(String k) => user[k] is String ? user[k] as String : '';
    return {
      if (s('email').isNotEmpty) 'locked_emails': AccountKeys.email(s('email')),
      if (s('name').isNotEmpty) 'locked_usernames': AccountKeys.username(s('name')),
      if (AccountKeys.phone(s('phone')).isNotEmpty) 'locked_phones': AccountKeys.phone(s('phone')),
    };
  }
}
