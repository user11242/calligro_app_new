// lib/features/community/widgets/follow_button.dart
//Done

import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for DocumentSnapshot type
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart'; // Adjust path as needed
import 'package:calligro_app/features/community/services/follow_service.dart'; // IMPORTANT: Import the service
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../../../core/message/app_messenger.dart';

// Instantiate the FollowService once
final FollowService _followService = FollowService();

class FollowButton extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final bool isPrimary; // Optional: true = filled button, false = outlined

  const FollowButton({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    this.isPrimary = true, // By default, show the big filled button
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  // final FollowService _followService = FollowService(); // Removed as it's globally instantiated above
  bool _isLoading = false;

  // This is the function we call when the button is pressed
  Future<void> _toggleFollow(bool isCurrentlyFollowing) async {
    // Prevent action if already loading or if trying to follow self
    if (_isLoading || widget.currentUserId == widget.targetUserId) {
      return;
    }

    setState(() {
      _isLoading = true; // Start loading state
    });

    try {
      // Delegate the complex logic to FollowService
      await _followService.toggleFollow(
        currentUserId: widget.currentUserId,
        targetUserId: widget.targetUserId,
        isFollowing: isCurrentlyFollowing, // Tell the service current state
      );
      // The StreamBuilder will handle the UI update based on Firestore change
    } catch (e) {
      print("Error toggling follow: $e");
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // End loading state
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Don't show a button if it's your own profile ---
    if (widget.currentUserId == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    // --- Use a StreamBuilder to check the relationship in real-time ---
    return StreamBuilder<DocumentSnapshot>(
      // MODIFIED: Now using the FollowService to get the stream
      stream: _followService.getFollowingStatusStream(
        currentUserId: widget.currentUserId,
        targetUserId: widget.targetUserId,
      ),
      builder: (context, snapshot) {
        // Show loading state if snapshot is waiting or if button is busy
        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
          // Adjust size based on button style
          double size = widget.isPrimary ? 24 : 16;
          return SizedBox(
            width: widget.isPrimary ? 80 : 24, // Example width
            height: widget.isPrimary ? 36 : 24, // Example height
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.isPrimary
                    ? AppColors.primary
                    : AppColors.accentGold,
              ),
            ),
          );
        }

        final bool isFollowing = snapshot.hasData && snapshot.data!.exists;

        // --- Render the correct button based on state ---
        if (isFollowing) {
          // --- User IS FOLLOWING: Show "Following" button ---
          if (widget.isPrimary) {
            return ElevatedButton(
              onPressed: () => _toggleFollow(true), // Pass current state
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.accentGold,
                side: const BorderSide(color: AppColors.accentGold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(AppLocalizations.of(context)?.following ?? 'Following'),
            );
          } else {
            return OutlinedButton(
              onPressed: () => _toggleFollow(true), // Pass current state
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentGold,
                side: const BorderSide(color: AppColors.accentGold, width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: Text(AppLocalizations.of(context)?.following ?? 'Following'),
            );
          }
        } else {
          // --- User IS NOT FOLLOWING: Show "Follow" button ---
          if (widget.isPrimary) {
            return ElevatedButton(
              onPressed: () => _toggleFollow(false), // Pass current state
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(AppLocalizations.of(context)?.follow ?? 'Follow'),
            );
          } else {
            return OutlinedButton(
              onPressed: () => _toggleFollow(false), // Pass current state
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textLight,
                side: const BorderSide(color: AppColors.textLight, width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: Text(AppLocalizations.of(context)?.follow ?? 'Follow'),
            );
          }
        }
      },
    );
  }
}
