// lib/features/community/widgets/comments_bottom_sheet.dart
//Done
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart'; // Adjust path as needed
import '../services/community_service.dart'; // Import CommunityService
import 'comment_tile.dart'; // Import the new CommentTile
import 'add_comment_bar.dart'; // Import the new AddCommentBar
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart';
import '../../student/pages/public_profile/public_student_profile_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/guest_guard.dart'; // Import GuestGuard
import '../../../core/message/app_messenger.dart';

final CommunityService _communityService = CommunityService();

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String currentLoggedInUserId;
  final String postAuthorId;
  final Function(String userId, String userRole)
  onProfileTap; // Callback for profile navigation

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.currentLoggedInUserId,
    required this.postAuthorId,
    required this.onProfileTap,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  Map<String, dynamic>? _currentUserData;
  bool _isUserDataLoading = true;
  
  // Reply State
  String? _replyToCommentId;
  String? _replyToUserName;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserData();
  }

  Future<void> _fetchCurrentUserData() async {
    try {
      final data = await _communityService.getCurrentUserData(
        widget.currentLoggedInUserId,
      );
      if (mounted) {
        setState(() {
          _currentUserData = data;
          _isUserDataLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching current user data for comment: $e");
      if (mounted) {
        setState(() {
          _isUserDataLoading = false;
        });
      }
    }
  }

  void _handleReply(String commentId, String userName) {
    if (!GuestGuard.check(context, isGuest: widget.currentLoggedInUserId == "")) return;
    setState(() {
      _replyToCommentId = commentId;
      _replyToUserName = userName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
    });
  }
  
  Future<void> _sendReply(String text) async {
    if (_replyToCommentId == null || _currentUserData == null) return;
    
    // We delegate the service call to here or AddCommentBar?
    // AddCommentBar has the text controller and loading state.
    // Ideally AddCommentBar handles the service call to keep logic encapsulated there
    // OR AddCommentBar just calls a callback "onSend(text)" and we handle it here.
    // AddCommentBar ALREADY sends the reply if we pass `onSendReply` callback.
    // So we just need to implement the service call here.
    
    final String userId = _currentUserData!['id'];
    final String userName = _currentUserData!['name'] ?? 'User';
    final String userPhotoUrl = _currentUserData!['photoUrl'] ?? '';
    final String userRole = _currentUserData!['role'] ?? 'student';
    
    try {
      await _communityService.addReply(
        postId: widget.postId,
        commentId: _replyToCommentId!,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        userRole: userRole,
        text: text,
      );
      
      // Reset reply state after success
      _cancelReply();
      
    } catch (e) {
      print("Failed to send reply: $e");
      // Optionally show snackbar (AddCommentBar might handle error display if we return future?)
      // For now, simple error print.
         if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.failedToPostReply,
          type: MessengerType.error,
        );
      }
    }
  }

  // Local navigation helper for comments to maintain consistency
  void _navigateToProfileFromComment(
    BuildContext context,
    String tappedUserId,
    String userRole,
  ) {
    Navigator.of(context).pop(); // Pop the CommentsBottomSheet first
    if (tappedUserId == widget.currentLoggedInUserId) {
      widget.onProfileTap(tappedUserId, userRole); // Use the provided callback
      return;
    }

    if (userRole == 'teacher') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicTeacherProfilePage(userId: tappedUserId),
        ),
      );
    } else if (userRole == 'student' || userRole == 'admin') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicStudentProfilePage(userId: tappedUserId),
        ),
      );
    } else {
      print("Tapped on a unknown role profile, not navigating.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuest = widget.currentLoggedInUserId == "";
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: AppColors.textLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          Text(
            AppLocalizations.of(context)!.comments,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.textLight.withOpacity(0.2), height: 1),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _communityService.getCommentsStream(
                widget.postId,
              ), // Use service stream
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentGold,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.noCommentsYet,
                      style: TextStyle(
                        color: AppColors.textLight.withOpacity(0.7),
                      ),
                    ),
                  );
                }

                final comments = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final commentData =
                        comments[index].data() as Map<String, dynamic>;
                    final String commentId = comments[index].id;

                    return CommentTile(
                      // Use the new CommentTile widget
                      postId: widget.postId,
                      commentId: commentId,
                      commentData: commentData,
                      currentLoggedInUserId: widget.currentLoggedInUserId,
                      postAuthorId: widget.postAuthorId,
                      onProfileTap: _navigateToProfileFromComment,
                      onReply: _handleReply, // Pass our handler
                    );
                  },
                  separatorBuilder: (context, index) => Divider(
                    color: AppColors.textLight.withOpacity(0.1),
                    height: 1,
                    indent: 72,
                  ),
                );
              },
            ),
          ),
          Divider(color: AppColors.textLight.withOpacity(0.2), height: 1),
          if (_isUserDataLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              ),
            )
          else if (_currentUserData != null)
            AddCommentBar(
              postId: widget.postId,
              currentUserData: _currentUserData!,
              replyToUserName: _replyToUserName,
              onCancelReply: _cancelReply,
              onSendReply: _sendReply,
            )
          else if (isGuest)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.primary,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => GuestGuard.check(context, isGuest: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.loginToInteract.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.primary,
              child: Text(
                AppLocalizations.of(context)!.errorLoadingUserData,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}
