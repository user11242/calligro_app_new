import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

// ✅ Adjust these imports to match your project structure
import '../pages/settings/student_settings_page.dart'; // Added Import
import '../../community/widgets/profile_posts_section.dart';
import '../../community/services/community_service.dart';
import 'package:rxdart/rxdart.dart';
import '../../../../core/widgets/profile_image_viewer.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/follow_list_bottom_sheet.dart';
import 'package:calligro_app/features/student/pages/public_profile/public_student_profile_page.dart';
import 'package:calligro_app/features/teacher/pages/public_profile/public_teacher_profile_page.dart';

class StudentProfileTab extends StatefulWidget {
  const StudentProfileTab({super.key});

  @override
  State<StudentProfileTab> createState() => _StudentProfileTabState();
}

class _StudentProfileTabState extends State<StudentProfileTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? currentUserId;
  bool isGuest = true;
  final CommunityService _communityService = CommunityService();
  Stream<Map<String, dynamic>>? _combinedProfileStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentUserId = user.uid;
        isGuest = false;
        _initStreams();
      });
    } else {
      setState(() {
        isGuest = true;
      });
    }
  }

  void _initStreams() {
    if (currentUserId == null) return;

    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .snapshots();

    final myPostsStream = FirebaseFirestore.instance
        .collection('community_posts')
        .where('userId', isEqualTo: currentUserId)
        .snapshots();

    final savedPostsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('saved_posts')
        .snapshots();

    final likedPostsStream = FirebaseFirestore.instance
        .collection('community_posts')
        .where('likes.$currentUserId', isEqualTo: true)
        .snapshots();

    _combinedProfileStream = CombineLatestStream.combine4(
      userDocStream,
      myPostsStream,
      savedPostsStream,
      likedPostsStream,
      (userDoc, myPosts, savedPosts, likedPosts) {
        return {
          'user': userDoc,
          'myPosts': myPosts,
          'savedPostsIds': savedPosts.docs.map((d) => d.id).toList(),
          'likedPosts': likedPosts,
        };
      },
    ).onErrorReturn({}).asBroadcastStream();
  }

  // Removed _fetchSavedPostIds as we use real-time stream now

  Future<void> _onToggleSave(String postId, bool isSaved) async {
    if (currentUserId == null) return;

    // We rely on the real-time stream for state updates
    await _communityService.toggleSavePost(
      postId: postId,
      currentUserId: currentUserId!,
      isSaved: isSaved,
    );
  }

  // --- REUSED: Logic to show Followers/Following ---
  void _showFollowListSheet(
    BuildContext context,
    String title,
    String listType,
  ) {
    if (isGuest || currentUserId == null) return;

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
            // ✅ Reusing the Widget you built for the Teacher
            return FollowListBottomSheet(
              sheetController: sheetController,
              scrollController: scrollController,
              currentLoggedInUserId: currentUserId ?? "",
              targetUserId: currentUserId ?? "", // Viewing own list
              listType: listType,
              title: title,
              onProfileTap: (tappedUserId, userRole) {
                Navigator.of(context).pop();
                if (tappedUserId != currentUserId) {
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
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. GUEST VIEW
    if (isGuest) {
      return _buildGuestView();
    }

    // 2. LOGGED IN STUDENT VIEW
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _combinedProfileStream,
          builder: (context, combinedSnapshot) {
            if (combinedSnapshot.connectionState == ConnectionState.waiting &&
                !combinedSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              );
            }

            final data = combinedSnapshot.data;
            if (data == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              );
            }

            final userDoc = data['user'] as DocumentSnapshot;
            final myPosts = (data['myPosts'] as QuerySnapshot).docs;
            final savedPostIds = data['savedPostsIds'] as List<String>;
            final likedPosts = (data['likedPosts'] as QuerySnapshot).docs;

            // User Data Variables
            Map<String, dynamic> userData = {};
            if (userDoc.exists) {
              userData = userDoc.data() as Map<String, dynamic>;
            }

            String userName =
                userData['name'] ?? AppLocalizations.of(context)!.student;
            String userImage = userData['photoUrl'] ?? "";
            String displayBio = userData['bio'] ?? "";
            String followerCount = (userData['followerCount'] ?? 0).toString();
            String followingCount = (userData['followingCount'] ?? 0)
                .toString();
            String postCount = myPosts.length.toString();
            final savedCount = savedPostIds.length.toString();
            final likedCount = likedPosts.length.toString();

            return Column(
              children: [
                _buildTopBar(),
                // Header (Same design as Teacher)
                _buildProfileHeader(
                  userName,
                  userImage,
                  displayBio,
                  postCount,
                  followerCount,
                  followingCount,
                ),

                // Tabs
                _buildTabSelector(savedCount, likedCount),

                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SingleChildScrollView(
                        child: ProfilePostsSection(
                          title: AppLocalizations.of(context)!.saved,
                          currentUserId: currentUserId!,
                          postsStream: FirebaseFirestore.instance
                              .collection('community_posts')
                              .where(
                                FieldPath.documentId,
                                whereIn: savedPostIds.isNotEmpty
                                    ? savedPostIds.take(30).toList()
                                    : ['placeholder'],
                              )
                              .snapshots()
                              .map((snapshot) {
                                // Lazy cleanup of orphaned saved posts
                                final idsToCheck = savedPostIds
                                    .take(30)
                                    .toList();
                                if (snapshot.docs.length < idsToCheck.length) {
                                  final validIds = snapshot.docs
                                      .map((d) => d.id)
                                      .toSet();
                                  for (int i = 0; i < idsToCheck.length; i++) {
                                    final String id = idsToCheck[i];
                                    if (!validIds.contains(id)) {
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(currentUserId)
                                          .collection('saved_posts')
                                          .doc(id)
                                          .delete();
                                    }
                                  }
                                }
                                return snapshot;
                              }),
                          savedPostIds: savedPostIds,
                          onToggleSave: _onToggleSave,
                        ),
                      ),
                      SingleChildScrollView(
                        child: ProfilePostsSection(
                          title: AppLocalizations.of(context)!.liked,
                          currentUserId: currentUserId!,
                          postsStream: FirebaseFirestore.instance
                              .collection('community_posts')
                              .where('likes.$currentUserId', isEqualTo: true)
                              .snapshots(),
                          savedPostIds: savedPostIds,
                          onToggleSave: _onToggleSave,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.profile,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentSettingsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------------
  // UI WIDGETS
  // ------------------------------------------------------------------------

  Widget _buildGuestView() {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 60,
              color: AppColors.textLight.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.guestMode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.logInToViewProfile,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/LoginPage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.loginRegister,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    String name,
    String image,
    String bio,
    String posts,
    String followers,
    String following,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              ProfileAvatar(
                radius: 40,
                imageUrl: image,
                heroTag: "profile_me_$currentUserId",
                onTap: () => showProfileImageDialog(
                  context,
                  image,
                  "profile_me_$currentUserId",
                ),
              ),
              const SizedBox(width: 20),

              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(AppLocalizations.of(context)!.posts, posts),
                    _buildStatItem(
                      AppLocalizations.of(context)!.followers,
                      followers,
                      onTap: () => _showFollowListSheet(
                        context,
                        AppLocalizations.of(context)!.followers,
                        "followers",
                      ),
                    ),
                    _buildStatItem(
                      AppLocalizations.of(context)!.following,
                      following,
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

          // Name & Student Badge
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  AppLocalizations.of(context)!.studentBadge,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bio Section (Instagram Style)
          if (bio.isNotEmpty) ...[
            Text(
              bio,
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

          const SizedBox(height: 10),
        ],
      ),
    );
  }

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

  Widget _buildTabSelector(String savedCount, String likedCount) {
    return Container(
      color: AppColors.primary,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.accentGold,
        labelColor: AppColors.accentGold,
        unselectedLabelColor: AppColors.textLight,
        tabs: [
          Tab(text: "${AppLocalizations.of(context)!.saved} ($savedCount)"),
          Tab(text: "${AppLocalizations.of(context)!.liked} ($likedCount)"),
        ],
      ),
    );
  }
}
