import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:shimmer/shimmer.dart';

// --- IMPORTS (Adjust paths if needed) ---
import '../pages/settings/teacher_settings.dart';
import '../../../core/widgets/rating_display.dart';
import '../../../core/utils/rating_utils.dart';
import '../../community/widgets/profile_posts_section.dart';
import '../../community/services/community_service.dart';
import 'package:rxdart/rxdart.dart';
import '../../../../core/widgets/profile_image_viewer.dart';
import '../../../core/widgets/follow_list_bottom_sheet.dart';
import 'package:calligro_app/features/teacher/pages/public_profile/public_teacher_profile_page.dart';
import 'package:calligro_app/features/student/pages/public_profile/public_student_profile_page.dart';

class TeacherProfileTab extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userProfileImage;
  final String courseCount;
  final String studentCount;
  final String earnings;

  const TeacherProfileTab({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userProfileImage,
    required this.courseCount,
    required this.studentCount,
    required this.earnings,
  });

  @override
  State<TeacherProfileTab> createState() => _TeacherProfileTabState();
}

class _TeacherProfileTabState extends State<TeacherProfileTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? currentUserId;
  final CommunityService _communityService = CommunityService();
  Stream<Map<String, dynamic>>? _combinedProfileStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      _initStreams();
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
    ).asBroadcastStream();
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

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  // --- ACTIONS ---

  // Updated to accept the LIVE image URL
  // Method replaced by global utility showProfileImageDialog

  void _showFollowListSheet(
    BuildContext context,
    String title,
    String listType,
  ) {
    if (currentUserId == null) return;
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
            return FollowListBottomSheet(
              sheetController: sheetController,
              scrollController: scrollController,
              currentLoggedInUserId: currentUserId ?? "",
              targetUserId: currentUserId ?? "",
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

  void _openPostDetails(
    BuildContext context,
    Map<String, dynamic> postData,
    String postId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailsPage(postData: postData, postId: postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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

            // Use null-safe casts to prevent crashes during logout
            final userDoc = data['user'] as DocumentSnapshot?;
            final myPosts = (data['myPosts'] as QuerySnapshot?)?.docs ?? [];
            final savedPostIds = (data['savedPostsIds'] as List<String>?) ?? [];
            final likedPosts = (data['likedPosts'] as QuerySnapshot?)?.docs ?? [];

            // --- LIVE DATA FETCHING ---
            String displayFollowerCount = "0";
            String displayFollowingCount = "0";
            String displayBio = "";
            String displayName = widget.userName;
            String displayPhotoUrl = widget.userProfileImage;
            num displayTotalStars = 0;
            num displayReviewCount = 0;

            if (userDoc != null && userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              displayFollowerCount = (userData['followerCount'] ?? 0)
                  .toString();
              displayFollowingCount = (userData['followingCount'] ?? 0)
                  .toString();
              displayBio = (userData['bio'] ?? "").toString();
              displayTotalStars = userData['totalStars'] ?? 0;
              displayReviewCount = userData['reviewCount'] ?? 0;
              if (userData['name'] != null) displayName = userData['name'];
              if (userData['photoUrl'] != null) {
                displayPhotoUrl = userData['photoUrl'];
              }
            }

            final myWorkCount = myPosts.length.toString();
            final savedCount = savedPostIds.length.toString();
            final likedCount = likedPosts.length.toString();

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(child: _buildTopBar()),
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(
                      postCount: myWorkCount,
                      followerCount: displayFollowerCount,
                      followingCount: displayFollowingCount,
                      bio: displayBio,
                      name: displayName,
                      photoUrl: displayPhotoUrl,
                      totalStars: displayTotalStars,
                      reviewCount: displayReviewCount,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.accentGold,
                        labelColor: AppColors.accentGold,
                        unselectedLabelColor: Colors.white54,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        tabs: [
                          _buildTabWithCount(
                            AppLocalizations.of(context)!.saved,
                            savedCount,
                          ),
                          _buildTabWithCount(
                            AppLocalizations.of(context)!.liked,
                            likedCount,
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
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
            );
          },
        ),
      ),
    );
  }

  // --- REUSABLE LIST BUILDER ---
  Widget _buildPostList(
    List<QueryDocumentSnapshot> posts, {
    required bool showDate,
  }) {
    if (posts.isEmpty) {
      return _buildEmptyState(
        Icons.image_outlined,
        AppLocalizations.of(context)!.nothingToShow,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: posts.length,
      cacheExtent: 2000,
      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final doc = posts[index];
        final postData = doc.data() as Map<String, dynamic>;

        return InkWell(
          onTap: () => _openPostDetails(context, postData, doc.id),
          borderRadius: BorderRadius.circular(12),
          child: _buildPostStatsCard(postData, showDate),
        );
      },
    );
  }

  Widget _buildPostStatsCard(Map<String, dynamic> data, bool showDate) {
    List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
    String imageUrl = imageUrls.isNotEmpty ? imageUrls[0] : '';
    String caption = data['caption'] ?? 'No caption';
    int likes = data['likesCount'] ?? 0;
    int comments = data['commentsCount'] ?? 0;

    String dateStr = "";
    if (showDate && data['timestamp'] != null) {
      final date = (data['timestamp'] as Timestamp).toDate();
      dateStr = DateFormat(
        'MMM d, yyyy',
        Localizations.localeOf(context).toString(),
      ).format(date);
    }

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
            child: imageUrl.isNotEmpty
                ? SmartImage(
                    imageUrl: imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    placeholder: Shimmer.fromColors(
                      baseColor: Colors.white.withOpacity(0.1),
                      highlightColor: Colors.white.withOpacity(0.2),
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.white24,
                      ),
                    ),
                  )
                : Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[900],
                    child: const Icon(Icons.image, color: Colors.white24),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (showDate) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 14,
                        color: Colors.redAccent.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$likes",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.comment,
                        size: 14,
                        color: AppColors.accentGold.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$comments",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(
              Icons.arrow_forward_ios,
              color: Colors.white24,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  // --- HEADER & HELPERS ---
  Widget _buildTabWithCount(String label, String count) {
    return Tab(
      height: 60.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
                builder: (context) => const TeacherSettingsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader({
    required String postCount,
    required String followerCount,
    required String followingCount,
    required String bio,
    required String name,
    required String photoUrl,
    required num totalStars,
    required num reviewCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Avatar & Stats Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                // Use the LIVE photo URL here
                onTap: () => showProfileImageDialog(
                  context,
                  photoUrl,
                  "profile_me_$currentUserId",
                ),
                child: Hero(
                  tag: "profile_me_$currentUserId",
                  child: ProfileAvatar(
                    imageUrl: photoUrl,
                    radius: 40,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      AppLocalizations.of(context)!.posts,
                      postCount,
                    ),
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

          // 2. Name & Role Badge
          Row(
            children: [
              Text(
                name, // Uses live name
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: AppColors.accentGold, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.assignment_ind,
                      color: AppColors.accentGold,
                      size: 14.0,
                    ),
                    const SizedBox(width: 5.0),
                    Text(
                      AppLocalizations.of(context)!.teacher,
                      style: const TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rating Display
          RatingDisplay(
            averageRating: RatingUtils.calculateAverageRating(
              totalStars,
              reviewCount,
            ),
            reviewCount: reviewCount.toInt(),
            isCompact: false,
          ),

          // 3. Bio Section (Instagram Style)
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
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
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50.0, color: Colors.white24),
          const SizedBox(height: 16.0),
          Text(message, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  // --- NEW: Saved Posts Builder ---
  // Since Saved Posts are a list of IDs, we need to fetch them.
  // We can't use _buildPostList directly because that takes QueryDocumentSnapshot list.
  Widget _buildSavedPostsList(List<String> postIds) {
    if (postIds.isEmpty) {
      return _buildEmptyState(
        Icons.bookmark_border,
        AppLocalizations.of(context)!.noSavedItems,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: postIds.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final postId = postIds[index];
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('community_posts')
              .doc(postId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox(); // Handle deleted posts gracefully
            }
            final postData = snapshot.data!.data() as Map<String, dynamic>;

            return InkWell(
              onTap: () => _openPostDetails(context, postData, postId),
              borderRadius: BorderRadius.circular(12),
              child: _buildPostStatsCard(postData, false),
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------
// --- FOLLOW LIST BOTTOM SHEET ---
// -----------------------------------------------------------

// -----------------------------------------------------------
// --- POST DETAILS PAGE ---
// -----------------------------------------------------------

class PostDetailsPage extends StatelessWidget {
  final Map<String, dynamic> postData;
  final String postId;

  const PostDetailsPage({
    super.key,
    required this.postData,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    List<String> imageUrls = List<String>.from(postData['imageUrls'] ?? []);
    String userName = postData['userName'] ?? "Unknown";
    String userImage = postData['userImageUrl'] ?? "";
    String caption = postData['caption'] ?? "";
    int likes = postData['likesCount'] ?? 0;

    String dateStr = "";
    if (postData['timestamp'] != null) {
      final date = (postData['timestamp'] as Timestamp).toDate();
      dateStr = DateFormat(
        'MMMM d, yyyy • h:mm a',
        Localizations.localeOf(context).toString(),
      ).format(date);
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Post Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ProfileAvatar(
                    imageUrl: userImage,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (imageUrls.isNotEmpty)
              SmartImage(
                imageUrl: imageUrls[0],
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: Shimmer.fromColors(
                  baseColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.2),
                  child: Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.white,
                  ),
                ),
                errorWidget: const Icon(Icons.error),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_border,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$likes likes",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 26,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final Widget _tabBar;

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.primary,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
