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

  /// The splash screen's first route (kept exactly as before): approved
  /// teachers, admins and students go straight to their dashboard; everyone
  /// else (pending/rejected teachers, unknown roles, no profile) goes to '/'
  /// where AuthWrapper decides.
  static String splashRoute(Map<String, dynamic>? user) {
    if (user == null) return '/';
    final role = user['role'] is String ? user['role'] as String : 'student';
    final status = user['status'] is String ? user['status'] as String : 'approved';
    if (role == 'teacher' && status == 'approved') return '/teacherDashboard';
    if (role == 'admin') return '/adminDashboard';
    if (role == 'student') return '/studentDashboard';
    return '/';
  }
}
