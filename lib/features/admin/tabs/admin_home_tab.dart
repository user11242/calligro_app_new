import 'package:calligro_app/features/admin/pages/admin_courses_mgmt.dart';
import 'package:calligro_app/features/admin/pages/admin_users_management_page.dart';
import 'package:calligro_app/features/admin/pages/admin_pending_teachers.dart';
import 'package:calligro_app/features/admin/pages/admin_activity_page.dart';
import 'package:calligro_app/features/admin/pages/admin_payouts_page.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return StreamBuilder<Map<String, dynamic>>(
      stream: _adminService.getGlobalStats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("${l10n.error}: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final stats = snapshot.data ?? {};

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    Text(
                      '${l10n.welcome}, ${l10n.adminRole}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.adminDashboard,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // Stats Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildStatTile(
                          label: l10n.totalUsers,
                          value: (stats['totalUsers'] ?? 0).toString(),
                          icon: Icons.people_rounded,
                          color: Colors.blue,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersManagementPage())),
                        ),
                        _buildStatTile(
                          label: l10n.pendingPayouts,
                          value: (stats['pendingWithdrawals'] ?? 0).toString(),
                          icon: Icons.payments_rounded,
                          color: Colors.amber,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPayoutsPage())),
                        ),
                        _buildStatTile(
                          label: l10n.pendingTeachers,
                          value: (stats['pendingTeachers'] ?? 0).toString(),
                          icon: Icons.assignment_ind,
                          color: Colors.green,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminPendingTeachersPage())),
                        ),
                        _buildStatTile(
                          label: l10n.activeCourses,
                          value: (stats['totalCourses'] ?? 0).toString(),
                          icon: Icons.auto_stories_rounded,
                          color: Colors.purple,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminCoursesMgmt())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Recent Activity Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.recentActivity,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminActivityPage())),
                          child: Text(l10n.showAll, style: const TextStyle(color: Colors.amber, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adminService.getRecentActivity(),
              builder: (context, actSnapshot) {
                if (actSnapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text("Activity Error: ${actSnapshot.error}", 
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  );
                }
                final activities = actSnapshot.data ?? [];
                if (activities.isEmpty && actSnapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: Colors.amber)));
                }
                if (activities.isEmpty) {
                  return const SliverToBoxAdapter(child: Center(child: Text("No recent activity", style: TextStyle(color: Colors.white38))));
                }
                
                // Show only first 5 items on dashboard
                final displayActivities = activities.take(5).toList();
                
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = displayActivities[index];
                      return _buildActivityItem(item);
                    },
                    childCount: displayActivities.length,
                  ),
                );
              },
            ),


          ],
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _translateActivityTitle(context, item['title']),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  item['subtitle'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }

  String _translateActivityTitle(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'newUserJoined':
        return l10n.newUserJoined;
      case 'newCourseCreated':
        return l10n.newCourseCreated;
      case 'newCommunityPost':
        return l10n.newCommunityPost;
      default:
        return key;
    }
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF252525),
              const Color(0xFF1E1E1E),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -1),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildQuickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 16),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: Colors.white12, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
