import 'package:flutter/material.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class AdminActivityPage extends StatelessWidget {
  final AdminService _adminService = AdminService();

  AdminActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          l10n.allPlatformActivity,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService
            .getRecentActivity(), // This currently takes 10, we could expand service if needed
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "${l10n.error}: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          final activities = snapshot.data ?? [];
          if (activities.isEmpty) {
            return Center(
              child: Text(
                l10n.noActivityHistoryFound,
                style: const TextStyle(color: Colors.white38),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final item = activities[index];
              return _buildActivityTile(context, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildActivityTile(BuildContext context, Map<String, dynamic> item) {
    final DateTime? date = (item['time'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: item['color'] as Color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _translateActivityTitle(context, item['title']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['subtitle'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    DateFormat.MMMd(
                      Localizations.localeOf(context).toString(),
                    ).add_jm().format(date),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
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
}
