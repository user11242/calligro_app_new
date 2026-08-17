import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/colors.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../services/community_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CommunityService _communityService = CommunityService();

  Future<void> _unblockUser(String blockedUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _communityService.unblockUser(
        currentUserId: currentUserId,
        blockedUserId: blockedUserId,
      );
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.userUnblockedSuccess,
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: "${AppLocalizations.of(context)!.failedToUnblockUser} $e",
          type: MessengerType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.blockedUsersTitle, 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(child: Text(AppLocalizations.of(context)!.userDataNotFound, style: const TextStyle(color: Colors.white)));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          final List<dynamic> blockedUsers = userData?['blockedUsers'] ?? [];

          if (blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: AppColors.textLight.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noBlockedUsers,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              final blockedId = blockedUsers[index] as String;
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(blockedId).snapshots(),
                builder: (context, blockedSnapshot) {
                  if (!blockedSnapshot.hasData || !blockedSnapshot.data!.exists) {
                    return const SizedBox.shrink(); // Hide if user doesn't exist
                  }

                  final blockedData = blockedSnapshot.data!.data() as Map<String, dynamic>?;
                  final name = blockedData?['name'] ?? 'Unknown User';
                  final photoUrl = blockedData?['photoUrl'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          radius: 20,
                          imageUrl: photoUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _unblockUser(blockedId),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.accentGold),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.unblockUser,
                            style: const TextStyle(color: AppColors.accentGold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
