import 'package:calligro_app/features/auth/data/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ IMPORT YOUR ONBOARDING SCREEN
import 'package:calligro_app/screens/on_boarding_page.dart'; // Check your file name!
import 'package:calligro_app/features/student/student_dashboard.dart';
import 'package:calligro_app/features/auth/pages/teacher_pending_page.dart';
import 'package:calligro_app/features/auth/pages/teacher_rejected_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/features/teacher/teacher_dashboard.dart';
import 'package:calligro_app/features/admin/admin_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  String? _lastUid;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛡️ CACHED SNAPSHOT — This is the critical fix for the meeting page bug.
  // When iOS allocates camera/mic resources during a LiveKit meeting, it can
  // briefly interrupt the network. Firestore's real-time stream detects this
  // and transitions to ConnectionState.waiting. Without caching, the builder
  // returns a loading spinner, which DESTROYS the entire Navigator stack
  // (including CalligroMeetPage), killing the meeting mid-session.
  //
  // By caching the last valid snapshot, we keep showing the dashboard even
  // during temporary network blips. The meeting page stays alive.
  // ═══════════════════════════════════════════════════════════════════════════
  DocumentSnapshot? _cachedUserSnapshot;

  @override
  void initState() {
    super.initState();
    // 👻 CLEANUP GHOST ACCOUNTS ON APP START
    // If the app was closed during registration, a "ghost" account might remain.
    // This will check if the user exists in Firebase Auth but NOT in Firestore,
    // and delete them so they can register again.
    _authService.cleanupGhostAccount();
  }

  void _refreshFCM(String uid) {
    if (_lastUid == uid) return;
    _lastUid = uid;
    // Use a small delay to ensure Firebase is fully ready if needed, 
    // though saveUserFcmToken handles its own async logic.
    Future.microtask(() => _authService.saveUserFcmToken(uid));
  }

  /// Build the appropriate dashboard widget based on user data.
  /// Extracted to avoid duplication between live and cached paths.
  Widget _buildForUserData(Map<String, dynamic> userData) {
    final String? role = userData['role'];
    final String status = userData['status'] ?? 'approved';

    if (role == null || role.isEmpty) {
      return const OnboardingPage(key: ValueKey('onboarding_root'));
    }

    if (role == 'teacher') {
      if (status == 'approved') {
        return const TeacherDashboardPage();
      } else if (status == 'rejected') {
        return const TeacherRejectedPage();
      } else {
        return const TeacherPendingPage();
      }
    } else if (role == 'admin') {
      return const AdminDashboardPage();
    } else {
      return const StudentDashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // ✅ FIX: Provide initial data to prevent "waiting" flicker
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // 1. User Logged In -> Fetch Role
        if (snapshot.hasData && snapshot.data != null) {
          final User user = snapshot.data!;
          
          // Refresh FCM token whenever the user changes or logs in
          _refreshFCM(user.uid);

          return StreamBuilder<DocumentSnapshot?>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().handleError((e) {
              debugPrint("AuthWrapper Stream Error: $e");
              return null; // This will trigger the hasError or empty check below
            }),
            builder: (context, userSnapshot) {
              // 1. Check for errors (e.g. permission-denied during logout)
              //    Only redirect to onboarding if we have NO cached data.
              if (userSnapshot.hasError) {
                if (_cachedUserSnapshot != null) {
                  debugPrint("AuthWrapper: Stream error but using cached snapshot to keep UI stable.");
                  final data = _cachedUserSnapshot!.data();
                  if (data != null && data is Map<String, dynamic>) {
                    return _buildForUserData(data);
                  }
                }
                return const OnboardingPage(key: ValueKey('onboarding_root'));
              }

              // 2. Handle loading state — THIS IS THE CRITICAL FIX
              //    NEVER show a loading spinner if we already have cached data.
              //    The old code returned a Scaffold with a spinner here, which
              //    destroyed the entire Navigator stack including meetings.
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                if (_cachedUserSnapshot != null) {
                  // We have cached data — keep showing the current UI!
                  // This prevents meetings from being killed by network blips.
                  final data = _cachedUserSnapshot!.data();
                  if (data != null && data is Map<String, dynamic>) {
                    return _buildForUserData(data);
                  }
                }
                // First load ever — no cache yet, show spinner
                return const Scaffold(
                  backgroundColor: Color(0xFF1F1F1F),
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  ),
                );
              }

              // 3. Handle missing data or user deletion
              if (!userSnapshot.hasData || userSnapshot.data == null || !userSnapshot.data!.exists) {
                _cachedUserSnapshot = null; // Clear cache — user truly doesn't exist
                return const OnboardingPage(key: ValueKey('onboarding_root'));
              }

              // 4. Safely extract user data
              final data = userSnapshot.data!.data();
              if (data == null || data is! Map<String, dynamic>) {
                _cachedUserSnapshot = null;
                return const OnboardingPage(key: ValueKey('onboarding_root'));
              }
              
              // ✅ Cache the valid snapshot for resilience against future blips
              _cachedUserSnapshot = userSnapshot.data!;

              return _buildForUserData(data);
            },
          );
        }

        // 2. User Logged Out (Default) -> Show OnboardingPage
        _lastUid = null;
        _cachedUserSnapshot = null; // Clear cache on logout
        return const OnboardingPage(key: ValueKey('onboarding_root'));
      },
    );
  }
}
