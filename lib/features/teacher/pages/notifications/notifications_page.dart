import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/message/app_messenger.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: AppColors.accentGold),
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              final snapshot = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .where('read', isEqualTo: false)
                  .get();
              if (snapshot.docs.isNotEmpty) {
                final batch = FirebaseFirestore.instance.batch();
                for (var doc in snapshot.docs) {
                  batch.update(doc.reference, {'read': true});
                }
                await batch.commit();
              }
              if (context.mounted) {
                AppMessenger.showSnackBar(
                  context,
                  title: AppLocalizations.of(context)!.notifications,
                  message: AppLocalizations.of(context)!.allMarkedRead,
                  type: MessengerType.success,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseAuth.instance.currentUser != null
            ? FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('notifications')
                .orderBy('createdAt', descending: true)
                .snapshots()
            : const Stream<QuerySnapshot>.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noNotificationsYet,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final isUnread = !(data['read'] as bool? ?? false);
              final createdAt = data['createdAt'] as Timestamp?;
              final timeStr = createdAt != null 
                  ? timeago.format(createdAt.toDate(), locale: Localizations.localeOf(context).languageCode)
                  : '';
              
              // Icon mapping based on type
              IconData icon = Icons.notifications;
              Color iconColor = AppColors.accentGold;
              if (data['type'] == 'enrollment') {
                icon = Icons.person_add;
                iconColor = Colors.greenAccent;
              } else if (data['type'] == 'assignment') {
                icon = Icons.assignment;
                iconColor = Colors.orangeAccent;
              } else if (data['type'] == 'community') {
                icon = Icons.forum;
                iconColor = Colors.pinkAccent;
              }

              return _buildNotificationItem(
                context,
                id: notifications[index].id,
                type: data['type'] ?? 'notification',
                title: data['title'] ?? 'Notification',
                subtitle: data['body'] ?? '',
                time: timeStr,
                icon: icon,
                iconColor: iconColor,
                isUnread: isUnread,
              ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, {
    required String id,
    required String type,
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color iconColor,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.cardBackground
            : AppColors.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: isUnread
            ? Border.all(color: AppColors.accentGold.withOpacity(0.3))
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isUnread ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accentGold,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isUnread ? Colors.white70 : Colors.white38,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: TextStyle(
                color: AppColors.textLight.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        onTap: () async {
          // Identify potential navigation target (we can expand this later)
          final notificationType = type;
          
          // Mark as read in Firestore
          if (isUnread) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .doc(id)
                  .update({'read': true});
            }
          }

          // Optional: Handle navigation based on type
          if (type == 'community') {
             // Navigate to community (might need more context like postId)
          }
        },
      ),
    );
  }
}
