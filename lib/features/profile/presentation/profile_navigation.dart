import 'package:flutter/material.dart';

import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/utils/guest_guard.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../domain/profile_models.dart';
import '../domain/profile_policy.dart';
import 'pages/public_profile_page.dart';

/// Callback a dashboard passes so "my own profile" opens its profile tab.
typedef OwnProfileCallback = void Function(String userId, String userRole);

/// Opening any user's profile — used by profiles, community, course and admin screens.
class ProfileNavigation {
  ProfileNavigation._();

  static void open(
    BuildContext context, {
    required ProfileViewer viewer,
    required String userId,
    required String role,
    OwnProfileCallback? onOwnProfile,
  }) {
    if (!ProfilePolicy.canOpen(viewer, role)) {
      GuestGuard.check(context, isGuest: true);
      return;
    }
    if (ProfilePolicy.isOwn(viewer, userId)) {
      onOwnProfile?.call(userId, role);
      return;
    }
    if (!ProfilePolicy.hasPublicPage(role)) {
      final l10n = AppLocalizations.of(context)!;
      AppMessenger.showSnackBar(context, title: l10n.info, message: l10n.profileNotAvailable, type: MessengerType.info);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PublicProfilePage(userId: userId, onDashboardProfileTap: onOwnProfile)),
    );
  }
}
