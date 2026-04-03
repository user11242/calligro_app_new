import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/admin/pages/admin_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../community/services/community_service.dart';
import '../../community/widgets/profile_posts_section.dart';
import '../../../../core/widgets/profile_image_viewer.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/follow_list_bottom_sheet.dart';
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart';
import '../../student/pages/public_profile/public_student_profile_page.dart';

class AdminProfileTab extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userProfileImage;

  const AdminProfileTab({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userProfileImage,
  });

  @override
  State<AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends State<AdminProfileTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? currentUserId;
  final CommunityService _communityService = CommunityService();
  Stream<Map<String, dynamic>>? _combinedProfileStream;

  @override
  void initState() {
    super.initState();
    // 3 Tabs for Admin: My Posts, Saved, Liked
    _tabController = TabController(length: 3, vsync: this);

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

  Future<void> _onToggleSave(String postId, bool isSaved) async {
    if (currentUserId == null) return;

    await _communityService.toggleSavePost(
      postId: postId,
      currentUserId: currentUserId!,
      isSaved: isSaved,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _combinedProfileStream,
          builder: (context, combinedSnapshot) {
            // Loading State
            if (combinedSnapshot.connectionState == ConnectionState.waiting &&
                !combinedSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              );
            }

            final data = combinedSnapshot.data;

            // Extract Data
            // If data is null (e.g. error or not loaded), use defaults
            final myPosts = (data?['myPosts'] as QuerySnapshot?)?.docs ?? [];
            final savedPostIds =
                (data?['savedPostsIds'] as List<String>?) ?? [];
            final likedPosts =
                (data?['likedPosts'] as QuerySnapshot?)?.docs ?? [];
            final userDoc = data?['user'] as DocumentSnapshot?;

            Map<String, dynamic> userData = {};
            if (userDoc != null && userDoc.exists) {
              userData = userDoc.data() as Map<String, dynamic>;
            }

            String displayFollowerCount = (userData['followerCount'] ?? 0).toString();
            String displayFollowingCount = (userData['followingCount'] ?? 0).toString();
            String displayBio = (userData['bio'] ?? "").toString();
            String displayName = userData['name'] ?? widget.userName;
            String displayPhotoUrl = userData['photoUrl'] ?? widget.userProfileImage;

            final myPostsCount = myPosts.length.toString();
            final savedCount = savedPostIds.length.toString();
            final likedCount = likedPosts.length.toString();

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(child: _buildTopBar(context)),
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(
                      context: context,
                      postCount: myPostsCount,
                      followerCount: displayFollowerCount,
                      followingCount: displayFollowingCount,
                      bio: displayBio,
                      name: displayName,
                      photoUrl: displayPhotoUrl,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildInfoCard(context)),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      _buildTabSelector(
                        context,
                        myPostsCount,
                        savedCount,
                        likedCount,
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  // 1. My Posts
                  ProfilePostsSection(
                    title: AppLocalizations.of(context)!.myPosts,
                    currentUserId: currentUserId ?? '',
                    postsStream: FirebaseFirestore.instance
                        .collection('community_posts')
                        .where('userId', isEqualTo: currentUserId)
                        .snapshots(),
                    savedPostIds: savedPostIds,
                    onToggleSave: _onToggleSave,
                  ),

                  // 2. Saved
                  ProfilePostsSection(
                    title: AppLocalizations.of(context)!.saved,
                    currentUserId: currentUserId ?? '',
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
                          final idsToCheck = savedPostIds.take(30).toList();
                          if (snapshot.docs.length < idsToCheck.length) {
                            final validIds = snapshot.docs
                                .map((d) => d.id)
                                .toSet();
                            for (int i = 0; i < idsToCheck.length; i++) {
                              final String id = idsToCheck[i];
                              if (!validIds.contains(id)) {
                                if (currentUserId != null) {
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(currentUserId!)
                                      .collection('saved_posts')
                                      .doc(id)
                                      .delete();
                                }
                              }
                            }
                          }
                          return snapshot;
                        }),
                    savedPostIds: savedPostIds,
                    onToggleSave: _onToggleSave,
                  ),

                  // 3. Liked
                  ProfilePostsSection(
                    title: AppLocalizations.of(context)!.liked,
                    currentUserId: currentUserId ?? '',
                    postsStream: FirebaseFirestore.instance
                        .collection('community_posts')
                        .where('likes.$currentUserId', isEqualTo: true)
                        .snapshots(),
                    savedPostIds: savedPostIds,
                    onToggleSave: _onToggleSave,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
                builder: (context) => const AdminSettingsPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader({
    required BuildContext context,
    required String postCount,
    required String followerCount,
    required String followingCount,
    required String bio,
    required String name,
    required String photoUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                radius: 40,
                imageUrl: photoUrl,
                heroTag: "profile_admin_$currentUserId",
                onTap: () => showProfileImageDialog(
                  context,
                  photoUrl,
                  "profile_admin_$currentUserId",
                ),
              ),
              const SizedBox(width: 20),
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
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.security,
                      color: AppColors.accentGold,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      AppLocalizations.of(context)!.adminRole.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bio.isNotEmpty) ...[
            Text(
              bio,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            widget.userEmail,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
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

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat(
            Icons.security, 
            AppLocalizations.of(context)!.security, 
            AppLocalizations.of(context)!.high
          ),
          Container(width: 1, height: 30, color: Colors.white10),
          _buildMiniStat(
            Icons.history, 
            AppLocalizations.of(context)!.lastLogin, 
            AppLocalizations.of(context)!.justNow
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.accentGold.withOpacity(0.7),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector(
    BuildContext context,
    String myPostsCount,
    String savedCount,
    String likedCount,
  ) {
    return Container(
      color: AppColors.primary,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.accentGold,
        labelColor: AppColors.accentGold,
        unselectedLabelColor: AppColors.textLight,
        isScrollable: false,
        tabs: [
          Tab(text: "${AppLocalizations.of(context)!.myPosts} ($myPostsCount)"),
          Tab(text: "${AppLocalizations.of(context)!.saved} ($savedCount)"),
          Tab(text: "${AppLocalizations.of(context)!.liked} ($likedCount)"),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final Widget _tabBar;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _tabBar;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
