import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../student/data/model/student_user_model.dart';
import '../../auth/data/services/auth_service.dart';
import '../../student/pages/settings/student_settings_page.dart';
import '../../teacher/pages/settings/help_center_page.dart';
import '../pages/student_my_courses_page.dart';
import '../pages/gallery_page.dart';
import '../../../core/utils/guest_guard.dart';
import '../../../core/widgets/profile_avatar.dart';

class StudentDrawer extends StatelessWidget {
  final StudentUserModel student;
  final bool isGuestMode;
  final Function(String?)? onGoToCourses;

  const StudentDrawer({
    super.key,
    required this.student,
    this.isGuestMode = false,
    this.onGoToCourses,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: AppColors.primary,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                if (isGuestMode)
                  _buildGuestSection(context, l10n)
                else ...[
                  _buildSectionTitle(l10n.accountCaps),
                  _buildDrawerMenuItem(
                    context,
                    icon: Icons.auto_stories_outlined,
                    title: l10n.myCourses,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentMyCoursesPage()));
                    },
                  ),
                  _buildDrawerMenuItem(
                    context,
                    icon: Icons.collections_outlined,
                    title: l10n.gallery,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const GalleryPage()));
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    child: Divider(color: Colors.white10),
                  ),
                  _buildSectionTitle(l10n.supportLegalCaps),
                  _buildDrawerMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: l10n.settings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentSettingsPage()));
                    },
                  ),
                  _buildDrawerMenuItem(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: l10n.helpCenter,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterPage()));
                    },
                  ),
                ],
              ],
            ),
          ),
          _buildLogoutButton(context, l10n),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

   Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 70, 25, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            radius: 35,
            imageUrl: student.photoUrl,
            placeholderIcon: Icons.person,
          ),
          const SizedBox(height: 15),
          Text(
            isGuestMode ? "Guest User" : student.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isGuestMode) ...[
            const SizedBox(height: 4),
            Text(
              student.email,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accentGold, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.white24,
        size: 18,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 0),
    );
  }

  Widget _buildGuestSection(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.stars, color: AppColors.accentGold, size: 40),
            const SizedBox(height: 10),
            const Text(
              "Full Access",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => GuestGuard.check(context, isGuest: true, returnTo: '/studentDashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.loginRegister),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/onBoarding', (route) => false);
              },
              child: Text(
                l10n.backToWelcome ?? "Back to Welcome Screen",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppLocalizations l10n) {
    if (isGuestMode) return const SizedBox(height: 40);

    return Container(
      margin: const EdgeInsets.fromLTRB(25, 10, 25, 40),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
        title: Text(
          l10n.signOut,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        onTap: () async {
          await AuthService().signOut();
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/onBoarding',
              (r) => false,
            );
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
