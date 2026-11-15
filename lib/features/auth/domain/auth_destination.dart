/// Where a signed-in user lands (AuthWrapper), from their users/{uid} document.
enum AuthDestination { onboarding, studentDashboard, teacherDashboard, teacherPending, teacherRejected, adminDashboard }

class AuthRouting {
  AuthRouting._();

  /// No document / no role → onboarding (finish sign-up). Teachers by status
  /// (missing status = approved, as before); admins; everyone else = student.
  static AuthDestination destinationFor(Map<String, dynamic>? user) {
    if (user == null) return AuthDestination.onboarding;
    final role = user['role'];
    if (role is! String || role.isEmpty) return AuthDestination.onboarding;
    final status = user['status'] is String ? user['status'] as String : 'approved';
    switch (role) {
      case 'teacher':
        return switch (status) {
          'approved' => AuthDestination.teacherDashboard,
          'rejected' => AuthDestination.teacherRejected,
          _ => AuthDestination.teacherPending,
        };
      case 'admin':
        return AuthDestination.adminDashboard;
      default:
        return AuthDestination.studentDashboard;
    }
  }
}
