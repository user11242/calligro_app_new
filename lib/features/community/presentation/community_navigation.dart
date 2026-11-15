import 'package:flutter/material.dart';

import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/utils/guest_guard.dart';
import 'package:calligro_app/features/student/pages/public_profile/public_student_profile_page.dart';
import 'package:calligro_app/features/teacher/pages/public_profile/public_teacher_profile_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import 'package:calligro_app/features/community/domain/models/community_models.dart';

/// Callback a dashboard passes so "my own profile" opens its own tab.
typedef OwnProfileCallback = void Function(String userId, String userRole);

/// Opening a profile from anywhere in the community (post author, liker,
/// commenter, search result). One place instead of four copies.
class CommunityNavigation {
  CommunityNavigation._();

  static void openProfile(
    BuildContext context, {
    required CommunitySession session,
    required String userId,
    required String role,
    OwnProfileCallback? onOwnProfile,
  }) {
    // Guests may view teacher profiles only.
    if (session.isGuest && role != 'teacher') {
      GuestGuard.check(context, isGuest: true);
      return;
    }
    if (userId == session.userId) {
      onOwnProfile?.call(userId, role);
      return;
    }
    final Widget? page = switch (role) {
      'teacher' => PublicTeacherProfilePage(userId: userId, onDashboardProfileTap: onOwnProfile),
      'student' || 'admin' => PublicStudentProfilePage(userId: userId, onDashboardProfileTap: onOwnProfile),
      _ => null,
    };
    if (page == null) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.info,
        message: AppLocalizations.of(context)!.profileNotAvailable,
        type: MessengerType.info,
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Shows the sign-in prompt for guests; true when the user may continue.
  static bool requireAccount(BuildContext context, CommunitySession session) =>
      GuestGuard.check(context, isGuest: session.isGuest);
}
