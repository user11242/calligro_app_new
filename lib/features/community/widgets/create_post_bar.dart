// lib/features/community/widgets/create_post_bar.dart
//Done
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for DocumentSnapshot type
// For user avatar
import '../../../core/theme/colors.dart'; // Adjust path as needed
import '../pages/add_post_page.dart'; // Adjust path to your AddPostPage
import '../../../features/community/services/user_service.dart'; // <-- IMPORT THE USER SERVICE

import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/core/utils/guest_guard.dart';

// Instantiate the UserService once
final UserService _userService = UserService();

class CreatePostBar extends StatelessWidget {
  final String currentUserId;

  const CreatePostBar({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return _buildBar(context, '');
    }

    return StreamBuilder<DocumentSnapshot>(
      // MODIFIED: Now using the UserService to get the stream
      stream: _userService.getUserStream(currentUserId),
      builder: (context, snapshot) {
        String profileImageUrl = '';
        if (snapshot.hasData && snapshot.data!.data() != null) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          profileImageUrl = userData['photoUrl'] ?? '';
        }

        return _buildBar(context, profileImageUrl);
      },
    );
  }

  Widget _buildBar(BuildContext context, String profileImageUrl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 16.0),
      color: AppColors.primary,
      child: InkWell(
        onTap: () {
          if (GuestGuard.check(context, isGuest: currentUserId.isEmpty)) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddPostPage()),
            );
          }
        },
        child: Row(
          children: [
            ProfileAvatar(
              radius: 20,
              imageUrl: profileImageUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25.0),
                  border: Border.all(
                    color: AppColors.textLight.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.shareMasterpiece,
                  style: TextStyle(
                    color: AppColors.textLight.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
