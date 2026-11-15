import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/message/app_messenger.dart';
import '../domain/notification_models.dart';
import 'notification_services.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Stream<List<InboxItem>> _stream(BuildContext context) {
    final services = NotificationScope.of(context);
    return services.inbox.watch(services.currentUid());
  }

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
              final services = NotificationScope.of(context);
              final uid = services.currentUid();
              if (uid.isEmpty) return;
              await services.inbox.markAllRead(uid);
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
      body: StreamBuilder<List<InboxItem>>(
        stream: _stream(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noNotificationsYet,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final item = notifications[index];
              final isUnread = !item.read;
              final createdAt = item.createdAt;
              final timeStr = createdAt != null
                  ? timeago.format(createdAt, locale: Localizations.localeOf(context).languageCode)
                  : '';

              // Icon mapping based on type
              IconData icon = Icons.notifications;
              Color iconColor = AppColors.accentGold;
              if (item.type == 'enrollment') {
                icon = Icons.person_add;
                iconColor = Colors.greenAccent;
              } else if (item.type == 'assignment') {
                icon = Icons.assignment;
                iconColor = Colors.orangeAccent;
              } else if (const {'comment', 'like', 'reply', 'community'}.contains(item.type)) {
                icon = Icons.forum;
                iconColor = Colors.pinkAccent;
              }

              return _buildNotificationItem(
                context,
                item: item,
                title: item.title.isEmpty ? 'Notification' : item.title,
                subtitle: item.body,
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
    required InboxItem item,
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
        color: isUnread ? AppColors.cardBackground : AppColors.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: isUnread
            ? Border.all(color: AppColors.accentGold.withOpacity(0.3))
            : Border.all(color: Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      // Own transparent Material so the tap ripple is not hidden by the card colour.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
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
                  decoration: const BoxDecoration(color: AppColors.accentGold, shape: BoxShape.circle),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: isUnread ? Colors.white70 : Colors.white38, fontSize: 13)),
              const SizedBox(height: 6),
              Text(time, style: TextStyle(color: AppColors.textLight.withOpacity(0.5), fontSize: 11)),
            ],
          ),
          onTap: () {
            final services = NotificationScope.of(context);
            final uid = services.currentUid();
            if (isUnread && uid.isNotEmpty) services.inbox.markRead(uid, item.id);
            // Open what the notification is about (it used to open nothing).
            if (item.target is! InboxTarget) services.opener.open(item.target);
          },
        ),
      ),
    );
  }
}
