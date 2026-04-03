import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/message/app_messenger.dart';
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/core/utils/date_utils.dart';
import 'package:intl/intl.dart';

class AdminActiveTeachersPage extends StatelessWidget {
  const AdminActiveTeachersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          l10n.activeTeachers,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.accentGold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'teacher')
            .where('approved', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_ind,
                    size: 80,
                    color: AppColors.textLight.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noActiveTeachers,
                    style: TextStyle(
                      color: AppColors.textLight.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildTeacherCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildTeacherCard(BuildContext context, String teacherId, Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final name = data['name'] ?? l10n.anonymous;
    final email = data['email'] ?? l10n.noEmail;
    final photoUrl = data['photoUrl'] ?? '';
    final createdAt = CalligroDateUtils.toDateTime(data['createdAt']);
    final portfolioLink = data['portfolioLink'] ?? '';

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicTeacherProfilePage(userId: teacherId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  ProfileAvatar(
                    radius: 32,
                    imageUrl: photoUrl,
                  ),
                  const SizedBox(width: 16),

                  // Teacher Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.verified,
                              color: AppColors.accentGold,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: AppColors.textLight.withOpacity(0.8),
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.joinedDate(DateFormat.yMMMd().format(createdAt)),
                            style: TextStyle(
                              color: AppColors.textLight.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textLight),
                    color: AppColors.cardBackground,
                    onSelected: (value) => _handleAction(context, value, teacherId, data),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            const Icon(Icons.visibility, color: AppColors.accentGold, size: 20),
                            const SizedBox(width: 12),
                            Text(l10n.viewProfile, style: const TextStyle(color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'suspend',
                        child: Row(
                          children: [
                            const Icon(Icons.block, color: Colors.orange, size: 20),
                            const SizedBox(width: 12),
                            Text(l10n.suspendTeacher, style: const TextStyle(color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, color: Colors.red, size: 20),
                            const SizedBox(width: 12),
                            Text(l10n.deleteUser, style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Portfolio Link
              if (portfolioLink.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: AppColors.accentGold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          portfolioLink,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Stats (placeholder - can be enhanced with real data)
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip(Icons.book, '0', l10n.courses),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.people, '0', l10n.students),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.star, '0.0', l10n.rating),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accentGold, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textLight.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    String teacherId,
    Map<String, dynamic> data,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PublicTeacherProfilePage(userId: teacherId),
          ),
        );
        break;

      case 'suspend':
        await _suspendTeacher(context, teacherId, data);
        break;

      case 'delete':
        await _deleteTeacher(context, teacherId, data);
        break;
    }
  }

  Future<void> _suspendTeacher(
    BuildContext context,
    String teacherId,
    Map<String, dynamic> data,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await FirebaseFirestore.instance.collection('users').doc(teacherId).update({
        'approved': false,
      });

      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.success,
          message: l10n.teacherSuspended,
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    }
  }

  Future<void> _deleteTeacher(
    BuildContext context,
    String teacherId,
    Map<String, dynamic> data,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = data['name'] ?? l10n.user;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          l10n.deleteUserConfirmTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          l10n.deleteUserConfirmMessage(name),
          style: const TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(teacherId).delete();

        if (context.mounted) {
          AppMessenger.showSnackBar(
            context,
            title: l10n.success,
            message: '${l10n.deleteUser} ${l10n.success}',
            type: MessengerType.success,
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppMessenger.showSnackBar(
            context,
            title: l10n.error,
            message: e.toString(),
            type: MessengerType.error,
          );
        }
      }
    }
  }
}
