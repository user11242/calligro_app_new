import 'package:flutter/material.dart';

import 'package:calligro_app/core/utils/guest_guard.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/profile/domain/profile_models.dart';
import 'package:calligro_app/features/profile/presentation/profile_navigation.dart' as profile;

/// Callback a dashboard passes so "my own profile" opens its own tab.
typedef OwnProfileCallback = profile.OwnProfileCallback;

/// Opening a profile from the community (post author, liker, commenter,
/// search result). The rules live in the profile feature.
class CommunityNavigation {
  CommunityNavigation._();

  static void openProfile(
    BuildContext context, {
    required CommunitySession session,
    required String userId,
    required String role,
    OwnProfileCallback? onOwnProfile,
  }) =>
      profile.ProfileNavigation.open(
        context,
        viewer: session.isGuest ? ProfileViewer.guest : ProfileViewer(userId: session.userId, role: session.role),
        userId: userId,
        role: role,
        onOwnProfile: onOwnProfile,
      );

  /// Shows the sign-in prompt for guests; true when the user may continue.
  static bool requireAccount(BuildContext context, CommunitySession session) =>
      GuestGuard.check(context, isGuest: session.isGuest);
}
