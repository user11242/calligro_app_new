// lib/features/community/pages/single_post_page.dart

import 'package:calligro_app/features/community/widgets/post_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/guest_guard.dart';
import '../../../l10n/app_localizations.dart';
import '../services/community_service.dart';
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart';
import '../../student/pages/public_profile/public_student_profile_page.dart';

class SinglePostPage extends StatefulWidget {
  final String postId;

  const SinglePostPage({super.key, required this.postId});

  @override
  State<SinglePostPage> createState() => _SinglePostPageState();
}

class _SinglePostPageState extends State<SinglePostPage> {
  final CommunityService _communityService = CommunityService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _savedPostIds = [];

  @override
  void initState() {
    super.initState();
    _fetchSavedPosts();
  }

  Future<void> _fetchSavedPosts() async {
    final user = _auth.currentUser;
    if (user != null) {
      final ids = await _communityService.getSavedPostIds(user.uid);
      if (mounted) {
        setState(() => _savedPostIds = ids);
      }
    }
  }

  void _navigateToProfile(BuildContext context, String tappedUserId, String userRole) {
    final user = _auth.currentUser;
    if (user == null && userRole != 'teacher') {
      GuestGuard.check(context, isGuest: true);
      return;
    }

    if (userRole == 'teacher') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicTeacherProfilePage(userId: tappedUserId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicStudentProfilePage(userId: tappedUserId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final bool isGuest = user == null;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.post),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.nothingToShow,
                style: const TextStyle(color: AppColors.textLight),
              ),
            );
          }

          final postData = snapshot.data!.data() as Map<String, dynamic>;
          final postUserId = postData['userId'] ?? '';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(postUserId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  String displayUserName = postData['userName'] ?? 'Anonymous';
                  String displayUserImage = postData['userImageUrl'] ?? '';
                  String displayUserRole = postData['userRole'] ?? 'student';

                  if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    displayUserName = userData['name'] ?? displayUserName;
                    displayUserImage = userData['photoUrl'] ?? displayUserImage;
                    displayUserRole = userData['role'] ?? displayUserRole;
                  }

                  return PostCard(
                    postId: widget.postId,
                    userId: postUserId,
                    currentLoggedInUserId: user?.uid ?? '',
                    isGuest: isGuest,
                    userName: displayUserName,
                    userImageUrl: displayUserImage,
                    userRole: displayUserRole,
                    caption: postData['caption'] ?? '',
                    imageUrls: List<String>.from(postData['imageUrls'] ?? []),
                    timestamp: postData['timestamp'] as Timestamp?,
                    onProfileTap: (tappedUserId, role) => _navigateToProfile(context, tappedUserId, role),
                    likesCount: postData['likesCount'] ?? 0,
                    likes: Map<String, dynamic>.from(postData['likes'] ?? {}),
                    commentsCount: postData['commentsCount'] ?? 0,
                    isSaved: _savedPostIds.contains(widget.postId),
                    isEdited: postData['isEdited'] ?? false,
                    onToggleSave: () async {
                      if (GuestGuard.check(context, isGuest: isGuest)) {
                        final isCurrentlySaved = _savedPostIds.contains(widget.postId);
                        setState(() {
                          if (isCurrentlySaved) {
                            _savedPostIds.remove(widget.postId);
                          } else {
                            _savedPostIds.add(widget.postId);
                          }
                        });
                        try {
                          await _communityService.toggleSavePost(
                            postId: widget.postId,
                            currentUserId: user!.uid,
                            isSaved: isCurrentlySaved,
                          );
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              if (isCurrentlySaved) {
                                _savedPostIds.add(widget.postId);
                              } else {
                                _savedPostIds.remove(widget.postId);
                              }
                            });
                          }
                        }
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
