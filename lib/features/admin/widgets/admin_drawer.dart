import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/features/admin/pages/admin_users_management_page.dart';
import 'package:calligro_app/features/admin/pages/admin_pending_teachers.dart';
import 'package:calligro_app/features/admin/pages/admin_courses_mgmt.dart';
import 'package:calligro_app/features/admin/pages/admin_community_mgmt.dart';
import 'package:calligro_app/features/admin/pages/admin_active_teachers_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    if (context.mounted) {
      // 1. Navigate
      Navigator.pushNamedAndRemoveUntil(context, "/onBoarding", (route) => false);
    }
    // 2. Sign Out
    // Small delay to ensure the UI has time to dispose active streams
    await Future.delayed(const Duration(milliseconds: 200));
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Premium Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.adminDashboard,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  l10n.adminRole,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard_rounded,
                  title: l10n.adminDashboard,
                  onTap: () => Navigator.pop(context),
                  isSelected: true,
                ),
                _buildDrawerItem(
                  icon: Icons.people_alt_rounded,
                  title: l10n.userManagement,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersManagementPage()));
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.pending_actions_rounded,
                  title: '${l10n.pending} ${l10n.teachers}',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminPendingTeachersPage()));
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.monetization_on_rounded,
                  title: l10n.teachersCommissions,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminActiveTeachersPage()));
                  },
                ),

                const Divider(color: Colors.white10, height: 32),
                _buildDrawerItem(
                  icon: Icons.auto_stories_rounded,
                  title: l10n.manageCourses,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminCoursesMgmt()));
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.forum_rounded,
                  title: l10n.community,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminCommunityMgmt()));
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.forum_rounded,
                  title: l10n.community,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminCommunityMgmt()));
                  },
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.grey),
              title: Text(l10n.logout, style: const TextStyle(color: Colors.white70)),
              onTap: () => _logout(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.amber : Colors.white60, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selectedTileColor: Colors.amber.withOpacity(0.1),
    );
  }
}
