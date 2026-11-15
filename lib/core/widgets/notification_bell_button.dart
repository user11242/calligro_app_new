import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';
import '../../features/notifications/data/firestore_notification_repositories.dart';
import '../../features/notifications/presentation/notification_services.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../utils/guest_guard.dart';

class NotificationBellButton extends StatelessWidget {
  final bool isGuest;
  final VoidCallback? customOnPressed;

  /// Injected in tests; the real singletons otherwise.
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const NotificationBellButton({
    super.key,
    this.isGuest = false,
    this.customOnPressed,
    this.auth,
    this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    final user = (auth ?? FirebaseAuth.instance).currentUser;
    final uid = user?.uid;

    void handleTap() {
      if (customOnPressed != null) {
        customOnPressed!();
        return;
      }
      if (isGuest || uid == null) {
        GuestGuard.check(context, isGuest: true);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NotificationsPage(),
        ),
      );
    }

    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: handleTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 24,
              ),
              if (uid != null && !isGuest)
                StreamBuilder<int>(
                  // Counts old (isRead) and new (read) items alike.
                  stream: (firestore != null
                          ? FirestoreInboxRepository(firestore: firestore)
                          : NotificationScope.of(context).inbox)
                      .watchUnreadCount(uid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == 0) {
                      return const SizedBox.shrink();
                    }

                    final count = snapshot.data!;
                    final displayCount = count > 99 ? '99+' : count.toString();

                    return Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: count > 9 ? 4 : 0,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935), // Vibrant red notification badge
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.cardBackground,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE53935).withOpacity(0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          displayCount,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
