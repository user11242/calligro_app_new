import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/profile_controllers.dart';
import '../../domain/profile_models.dart';
import '../profile_scope.dart';
import 'profile_body.dart';

/// Anyone's profile (student, teacher or admin), as other people see it.
class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({super.key, required this.userId, this.onDashboardProfileTap});

  final String userId;

  /// Opens the dashboard's own profile tab when the viewer taps themself.
  final void Function(String userId, String userRole)? onDashboardProfileTap;

  @override
  Widget build(BuildContext context) {
    return ProfileViewerGate(
      builder: (context, viewer) =>
          _PublicProfile(key: ValueKey(viewer.userId), userId: userId, viewer: viewer, onOwnProfile: onDashboardProfileTap),
    );
  }
}

class _PublicProfile extends StatefulWidget {
  const _PublicProfile({super.key, required this.userId, required this.viewer, this.onOwnProfile});
  final String userId;
  final ProfileViewer viewer;
  final void Function(String userId, String userRole)? onOwnProfile;

  @override
  State<_PublicProfile> createState() => _PublicProfileState();
}

class _PublicProfileState extends State<_PublicProfile> {
  ProfileController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ProfileScope.of(context);
    _controller ??= ProfileController(
      profileId: widget.userId,
      viewer: widget.viewer,
      profiles: s.profiles,
      counts: s.counts,
      publicView: true,
    )..start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = _controller!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Text(
            c.profile?.isTeacher ?? true ? l10n.profile : l10n.studentProfile,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ProfileBody(
          controller: c,
          onOwnProfile: widget.onOwnProfile,
          onLeaveForOwnProfile: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
