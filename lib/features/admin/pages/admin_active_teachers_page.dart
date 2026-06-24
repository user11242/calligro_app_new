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
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(l10n);
          }

          final activeTeachers = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final bool isApprovedBool = data['approved'] == true;
            final bool isStatusApproved = data['status'] == 'approved';
            return isApprovedBool || isStatusApproved;
          }).toList();

          // Sort locally by createdAt descending
          activeTeachers.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = CalligroDateUtils.toDateTime(aData['createdAt']) ?? DateTime(0);
            final bTime = CalligroDateUtils.toDateTime(bData['createdAt']) ?? DateTime(0);
            return bTime.compareTo(aTime);
          });

          if (activeTeachers.isEmpty) {
            return _buildEmptyState(l10n);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeTeachers.length,
            itemBuilder: (context, index) {
              final doc = activeTeachers[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildTeacherCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
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

  Widget _buildTeacherCard(BuildContext context, String teacherId, Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final name = data['name'] ?? l10n.anonymous;
    final email = data['email'] ?? l10n.noEmail;
    final photoUrl = data['photoUrl'] ?? '';
    final createdAt = CalligroDateUtils.toDateTime(data['createdAt']);
    final portfolioLink = data['portfolioLink'] ?? '';
    final hasCommission = data.containsKey('commissionRate');
    final commissionStr = hasCommission ? ((data['commissionRate'] as num).toDouble() * 100).toStringAsFixed(0) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasCommission ? Colors.green.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background subtle glow based on commission status
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasCommission ? Colors.green.withOpacity(0.05) : Colors.redAccent.withOpacity(0.05),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PublicTeacherProfilePage(userId: teacherId)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accentGold.withOpacity(0.3), width: 2),
                            ),
                            child: ProfileAvatar(radius: 34, imageUrl: photoUrl),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified, color: AppColors.accentGold, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (createdAt != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 12, color: Colors.white.withOpacity(0.4)),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.joinedDate(DateFormat.yMMMd().format(createdAt)),
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),

                      // Commission Status Bar (Clickable)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleAction(context, 'commission', teacherId, data),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: hasCommission ? Colors.green.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasCommission ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  hasCommission ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                  color: hasCommission ? Colors.greenAccent : Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hasCommission ? "${l10n.commissionLabel}: $commissionStr%" : l10n.setCommission,
                                  style: TextStyle(
                                    color: hasCommission ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (portfolioLink.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link, color: AppColors.accentGold, size: 16),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  portfolioLink,
                                  style: const TextStyle(color: AppColors.accentGold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Stats
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildStatChip(Icons.play_circle_outline, '0', l10n.courses),
                          const SizedBox(width: 12),
                          _buildStatChip(Icons.people_outline, '0', l10n.students),
                          const SizedBox(width: 12),
                          _buildStatChip(Icons.star_border, '0.0', l10n.rating),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accentGold.withOpacity(0.8), size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
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

      case 'commission':
        await _setCommissionRate(context, teacherId, data);
        break;

      case 'suspend':
        await _suspendTeacher(context, teacherId, data);
        break;

      case 'delete':
        await _deleteTeacher(context, teacherId, data);
        break;
    }
  }

  Future<void> _setCommissionRate(
    BuildContext context,
    String teacherId,
    Map<String, dynamic> data,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final currentRate = data.containsKey('commissionRate') 
        ? ((data['commissionRate'] as num).toDouble() * 100).toStringAsFixed(0)
        : '';
    
    final controller = TextEditingController(text: currentRate);

    final newRateStr = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          l10n.setCommissionRate,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.commissionRateDesc,
              style: TextStyle(color: AppColors.textLight.withOpacity(0.8)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                suffixText: '%',
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGold),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.save, style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (newRateStr != null && newRateStr.isNotEmpty) {
      final double? parsed = double.tryParse(newRateStr);
      if (parsed != null && parsed >= 0 && parsed <= 100) {
        
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: Text(l10n.areYouSure, style: const TextStyle(color: AppColors.textPrimary)),
            content: Text(
              "Are you sure you want to set the commission to ${parsed.toStringAsFixed(0)}%?",
              style: const TextStyle(color: AppColors.textLight),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textLight)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGold),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.save, style: const TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        final double rate = parsed / 100.0;
        try {
          // Update users collection
          await FirebaseFirestore.instance.collection('users').doc(teacherId).update({
            'commissionRate': rate,
          });

          // Update teachers collection as requested by user
          await FirebaseFirestore.instance.collection('teachers').doc(teacherId).set({
            'commissionRate': rate,
          }, SetOptions(merge: true));

          if (context.mounted) {
            AppMessenger.showSnackBar(
              context,
              title: l10n.success,
              message: l10n.commissionRateUpdated(parsed.toStringAsFixed(0)),
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
      } else {
        if (context.mounted) {
          AppMessenger.showSnackBar(
            context,
            title: l10n.error,
            message: "Invalid percentage. Enter a number between 0 and 100.",
            type: MessengerType.error,
          );
        }
      }
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
