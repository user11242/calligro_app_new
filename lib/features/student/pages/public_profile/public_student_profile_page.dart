import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ Adjust path to your FollowButton
import '../../../../features/community/widgets/follow_button.dart';
import '../../../../features/community/widgets/post_card.dart';
import '../../../../features/community/services/community_service.dart';
// ✅ Adjust path if you have the FollowListBottomSheet in a shared file,
// otherwise import from the Teacher Public Profile where we defined it.
import '../../../../core/widgets/follow_list_bottom_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/profile_image_viewer.dart';
import 'package:calligro_app/features/teacher/pages/public_profile/public_teacher_profile_page.dart';

class PublicStudentProfilePage extends StatefulWidget {
  final String userId;
  final Function(String userId, String userRole)? onDashboardProfileTap;

  const PublicStudentProfilePage({
    super.key,
    required this.userId,
    this.onDashboardProfileTap,
  });

  @override
  State<PublicStudentProfilePage> createState() =>
      _PublicStudentProfilePageState();
}

class _PublicStudentProfilePageState extends State<PublicStudentProfilePage> {
  String? _currentUserId;
  String? get publicUserId => widget.userId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  // Helper to show Followers/Following Sheet
  void _showFollowListSheet(
    BuildContext context,
    String title,
    String listType,
  ) {
    // If guest, maybe redirect to login? For now, we just show the list (read-only usually)
    // or return if you want to block guests.

    final DraggableScrollableController sheetController =
        DraggableScrollableController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          controller: sheetController,
          initialChildSize: 0.6,
          minChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            // Reusing the same BottomSheet widget from the Teacher Profile
            return FollowListBottomSheet(
              sheetController: sheetController,
              scrollController: scrollController,
              currentLoggedInUserId: _currentUserId ?? "",
              targetUserId: publicUserId!,
              listType: listType,
              title: title,
              onProfileTap: (tappedUserId, tappedUserRole) {
                Navigator.of(context).pop(); // Pop sheet
                
                if (tappedUserId == _currentUserId) {
                  // User tapped themselves: Pop profile page and go to dashboard tab
                  Navigator.of(context).pop(); 
                  widget.onDashboardProfileTap?.call(tappedUserId, tappedUserRole);
                } else if (tappedUserId == publicUserId) {
                  // User tapped the same profile they are viewing: Just pop sheet
                } else {
                  // Navigate to another user's public profile
                  if (tappedUserRole == 'teacher') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicTeacherProfilePage(
                          userId: tappedUserId,
                          onDashboardProfileTap: widget.onDashboardProfileTap,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicStudentProfilePage(
                          userId: tappedUserId,
                          onDashboardProfileTap: widget.onDashboardProfileTap,
                        ),
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textLight,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.studentProfile,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(publicUserId)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              );
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.userNotFound,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;

            // Get Posts Count
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community_posts')
                  .where('userId', isEqualTo: publicUserId)
                  .snapshots(),
              builder: (context, postSnapshot) {
                String postCount = "0";
                if (postSnapshot.hasData) {
                  postCount = postSnapshot.data!.docs.length.toString();
                }

                return Column(
                  children: [
                    // 1. Header
                    _buildProfileHeader(userData, postCount),

                    const Divider(color: Colors.white10),

                    // 2. Section Title
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.grid_view,
                            color: AppColors.accentGold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.posts,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            AppLocalizations.of(context)!.postsCount(int.parse(postCount)),
                            style: TextStyle(
                              color: AppColors.textLight.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. List of Posts
                    Expanded(child: _buildPostsList(postSnapshot)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData, String postCount) {
    String userName = userData['name'] ?? AppLocalizations.of(context)!.student;
    String userImage = userData['photoUrl'] ?? '';
    String followerCount = (userData['followerCount'] ?? 0).toString();
    String followingCount = (userData['followingCount'] ?? 0).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () => showProfileImageDialog(context, userImage, "profile_$publicUserId"),
                child: Hero(
                  tag: "profile_$publicUserId",
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.goldGradientEnd,
                    backgroundImage: userImage.isNotEmpty
                        ? NetworkImage(userImage)
                        : null,
                    child: userImage.isEmpty
                        ? Text(
                            userName.isNotEmpty ? userName[0] : "?",
                            style: const TextStyle(
                              fontSize: 30,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(AppLocalizations.of(context)!.posts, postCount),
                    _buildStatItem(
                      AppLocalizations.of(context)!.followers,
                      followerCount,
                      onTap: () => _showFollowListSheet(
                        context,
                        AppLocalizations.of(context)!.followers,
                        "followers",
                      ),
                    ),
                    _buildStatItem(
                      AppLocalizations.of(context)!.following,
                      followingCount,
                      onTap: () => _showFollowListSheet(
                        context,
                        AppLocalizations.of(context)!.following,
                        "following",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name & Badge
          Row(
            children: [
              Text(
                userName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (userData['role'] == 'admin')
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.verified,
                    color: AppColors.accentGold,
                    size: 18,
                  ),
                ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: userData['role'] == 'admin' 
                      ? AppColors.accentGold.withOpacity(0.15) 
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: userData['role'] == 'admin' 
                        ? AppColors.accentGold 
                        : Colors.white24
                  ),
                ),
                child: Text(
                  userData['role'] == 'admin' 
                      ? AppLocalizations.of(context)!.adminRole.toUpperCase() 
                      : AppLocalizations.of(context)!.student,
                  style: TextStyle(
                    color: userData['role'] == 'admin' 
                        ? AppColors.accentGold 
                        : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bio Section (Instagram Style)
          if ((userData['bio'] ?? "").toString().isNotEmpty) ...[
            Text(
              userData['bio'],
              maxLines: 4, // Shows max 4 lines (Instagram standard)
              overflow: TextOverflow.ellipsis, // Adds "..." if it's too long
              softWrap: true,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4, // Good height for emojis and text
              ),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child:
                    (_currentUserId == null || _currentUserId == publicUserId)
                    ? const SizedBox() // Don't show follow button for self
                    : FollowButton(
                        currentUserId: _currentUserId!,
                        targetUserId: publicUserId!,
                        isPrimary: true,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view, size: 60, color: Colors.white10),
            const SizedBox(height: 10),
            Text(AppLocalizations.of(context)!.noPostsYet, style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    var posts = snapshot.data!.docs;
    // Order by timestamp descending locally
    try {
      posts.sort((a, b) {
        Timestamp t1 = a['timestamp'] ?? Timestamp.now();
        Timestamp t2 = b['timestamp'] ?? Timestamp.now();
        return t2.compareTo(t1);
      });
    } catch (e) {
      // ordering failed
    }

    return FutureBuilder<List<String>>(
      future: CommunityService().getSavedPostIds(_currentUserId ?? ''),
      builder: (context, savedSnapshot) {
        final List<String> savedPostIds = savedSnapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 40),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            var postData = posts[index].data() as Map<String, dynamic>;
            String postId = posts[index].id;
            
            String postUserId = postData['userId'] ?? '';
            String postUserName = postData['userName'] ?? '';
            String postUserImage = postData['userImageUrl'] ?? '';
            String postUserRole = postData['userRole'] ?? '';
            String caption = postData['caption'] ?? '';
            List<String> imageUrls = List<String>.from(postData['imageUrls'] ?? []);
            Timestamp? timestamp = postData['timestamp'] as Timestamp?;
            int likesCount = postData['likesCount'] ?? 0;
            int commentsCount = postData['commentsCount'] ?? 0;
            Map<String, dynamic> likes = Map<String, dynamic>.from(postData['likes'] ?? {});
            
            bool isSaved = savedPostIds.contains(postId);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: PostCard(
                postId: postId,
                userId: postUserId,
                currentLoggedInUserId: _currentUserId ?? '',
                isGuest: _currentUserId == null,
                userName: postUserName,
                userImageUrl: postUserImage,
                userRole: postUserRole,
                caption: caption,
                imageUrls: imageUrls,
                timestamp: timestamp,
                onProfileTap: (uid, role) {
                   // Already on profile
                },
                likesCount: likesCount,
                likes: likes,
                commentsCount: commentsCount,
                isSaved: isSaved,
                isEdited: postData['isEdited'] ?? false,
                onToggleSave: () async {
                   await CommunityService().toggleSavePost(
                      postId: postId,
                      currentUserId: _currentUserId ?? '',
                      isSaved: isSaved,
                   );
                   setState(() {});
                },
              ),
            );
          },
        );
      }
    );
  }

  // Method replaced by global utility showProfileImageDialog

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
