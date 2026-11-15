import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/admin/pages/admin_settings.dart';
import 'package:calligro_app/features/student/pages/settings/student_settings_page.dart';
import 'package:calligro_app/features/teacher/pages/settings/teacher_settings.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/profile_controllers.dart';
import '../../domain/profile_models.dart';
import '../profile_scope.dart';
import 'profile_body.dart';

/// The dashboard's "Profile" tab for every role (replaces the three per-role tabs).
class MyProfileTab extends StatelessWidget {
  const MyProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileViewerGate(
      builder: (context, viewer) =>
          viewer.isGuest ? const _GuestProfile() : _MyProfile(key: ValueKey(viewer.userId), viewer: viewer),
    );
  }
}

class _MyProfile extends StatefulWidget {
  const _MyProfile({super.key, required this.viewer});
  final ProfileViewer viewer;

  @override
  State<_MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<_MyProfile> {
  ProfileController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ProfileScope.of(context);
    _controller ??= ProfileController(
      profileId: widget.viewer.userId,
      viewer: widget.viewer,
      profiles: s.profiles,
      counts: s.counts,
    )..start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _settingsPage() => switch (widget.viewer.role) {
        'teacher' => const TeacherSettingsPage(),
        'admin' => const AdminSettingsPage(),
        _ => const StudentSettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: ProfileBody(
          controller: _controller!,
          topBar: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.profile,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                IconButton(
                  key: const Key('profile-settings'),
                  icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                  onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _settingsPage())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 60, color: AppColors.textLight.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text(l10n.guestMode, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(l10n.logInToViewProfile, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 30),
            ElevatedButton(
              key: const Key('guest-login'),
              onPressed: () => Navigator.pushNamed(context, '/LoginPage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: Text(l10n.loginRegister, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
