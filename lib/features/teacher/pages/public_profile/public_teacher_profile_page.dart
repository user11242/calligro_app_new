import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- ADD: Import FirebaseAuth to get the current user's ID ---
import 'package:firebase_auth/firebase_auth.dart';
// You might need to adjust this path depending on where you saved follow_button.dart
import 'package:calligro_app/features/student/pages/public_profile/public_student_profile_page.dart';
import '../../../community/widgets/follow_button.dart';
import '../../../../features/community/widgets/post_card.dart';
import '../../../../features/community/services/community_service.dart';
import '../../../../features/rating/services/rating_service.dart'; // Import RatingService
import '../../../../core/widgets/rating_display.dart';
import '../../../../core/utils/rating_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/profile_image_viewer.dart';
import '../../../../core/utils/course_utils.dart';
import '../../../../features/student/pages/course_preview_page.dart';
import '../course_details/course_details_page.dart';
import '../../../../core/widgets/auto_translated_text.dart';
import '../../../../core/widgets/follow_list_bottom_sheet.dart';
import '../../../../core/utils/country_utils.dart';

class PublicTeacherProfilePage extends StatefulWidget {
  final String userId;
  final Function(String userId, String userRole)? onDashboardProfileTap;

  const PublicTeacherProfilePage({
    super.key,
    required this.userId,
    this.onDashboardProfileTap,
  });

  @override
  State<PublicTeacherProfilePage> createState() =>
      _PublicTeacherProfilePageState();
}

class _PublicTeacherProfilePageState extends State<PublicTeacherProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;
  String? get publicUserId => widget.userId;
  final RatingService _ratingService = RatingService(); // Initialize RatingService

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- NEW: Function to show the list of followers or following ---
  void _showFollowListSheet(
    BuildContext context,
    String title,
    String listType,
  ) {
    final DraggableScrollableController sheetController =
        DraggableScrollableController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
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
              currentLoggedInUserId: _currentUserId ?? "",
              targetUserId: publicUserId!,
              listType: listType, // 'followers' or 'following'
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
  // --- END OF NEW ---

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
          AppLocalizations.of(context)!.profile,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        // --- MODIFICATION: Replaced FutureBuilder with StreamBuilder ---
        child: StreamBuilder<DocumentSnapshot>(
          // This now LISTENS for live changes to the user's document
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(publicUserId)
              .snapshots(), // .snapshots() instead of .get()
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              );
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return _buildEmptyState(Icons.error_outline, AppLocalizations.of(context)!.userNotFound);
            }
            // --- END OF MODIFICATION ---

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community_posts')
                  .where('userId', isEqualTo: publicUserId)
                  .snapshots(),
              builder: (context, postSnapshot) {
                String postCount = "0";
                if (postSnapshot.connectionState == ConnectionState.active &&
                    postSnapshot.hasData) {
                  postCount = postSnapshot.data!.docs.length.toString();
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('courses')
                      .where('teacherId', isEqualTo: publicUserId)
                      .snapshots(),
                  builder: (context, courseSnapshot) {
                    String courseCount = "0";
                    if (courseSnapshot.connectionState ==
                            ConnectionState.active &&
                        courseSnapshot.hasData) {
                      courseCount = courseSnapshot.data!.docs.length.toString();
                    }

                    return Column(
                      children: [
                        _buildProfileHeader(
                          userData,
                          postCount,
                          _currentUserId,
                        ),
                        _buildTabSelector(postCount, courseCount),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            // ORDER: Courses, Reviews, Posts
                            children: [
                                _buildCoursesTab(),
                                _buildReviewsTab(), 
                                _buildPostsTab()
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET MODIFIED: Now uses new _buildStatItem ---
  Widget _buildProfileHeader(
    Map<String, dynamic> userData,
    String postCount,
    String? currentUserId,
  ) {
    String userName = userData['name'] ?? AppLocalizations.of(context)!.user;
    String userProfileImage = userData['photoUrl'] ?? '';
    String displayPostCount = postCount;

    // --- MODIFICATION: These values will now be live from the StreamBuilder ---
    String followerCount = (userData['followerCount'] ?? 0).toString();
    String followingCount = (userData['followingCount'] ?? 0).toString();
    // --- END OF MODIFICATION ---

    String userRole = userData['role'] ?? 'student';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => showProfileImageDialog(context, userProfileImage, "profile_$publicUserId"),
                child: Hero(
                  tag: "profile_$publicUserId",
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: userProfileImage.isNotEmpty
                        ? CachedNetworkImageProvider(userProfileImage)
                        : null,
                    backgroundColor: AppColors.goldGradientEnd,
                    child: userProfileImage.isEmpty
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : "?",
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
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(AppLocalizations.of(context)!.posts, displayPostCount),
                    _buildStatItem(
                      AppLocalizations.of(context)!.followers,
                      followerCount, // This will now update live
                      onTap: () {
                        _showFollowListSheet(context, AppLocalizations.of(context)!.followers, "followers");
                      },
                    ),
                    _buildStatItem(
                      AppLocalizations.of(context)!.following,
                      followingCount, // This will now update live
                      onTap: () {
                        _showFollowListSheet(context, AppLocalizations.of(context)!.following, "following");
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                  () {
                    final phone = userData['phone'] ?? userData['phoneNumber'] as String?;
                    final flag = CountryUtils.getFlagFromPhoneNumber(phone);
                    if (flag.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          flag,
                          style: const TextStyle(fontSize: 18),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }(),
                ],
              ),
              const SizedBox(width: 10),
              if (userRole == 'teacher')
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8.0),
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
                              fontWeight: FontWeight.w600,
                              fontSize: 12.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Rating Display
          RatingDisplay(
            averageRating: RatingUtils.calculateAverageRating(
              userData['totalStars'] ?? 0,
              userData['reviewCount'] ?? 0,
            ),
            reviewCount: userData['reviewCount'] ?? 0,
            isCompact: false,
          ),
          const SizedBox(height: 16),
          // Spoken Languages Section
          () {
            final List<String> languages = List<String>.from(userData['spokenLanguages'] ?? []);
            if (languages.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildLanguagesSection(languages),
              );
            }
            return const SizedBox.shrink();
          }(),

          // Bio Section (Instagram Style)
          if ((userData['bio'] ?? "").toString().isNotEmpty) ...[
            const SizedBox(height: 8),
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

          Row(
            children: [
              Expanded(
                child: (currentUserId == null || publicUserId == null)
                    ? const SizedBox()
                      : FollowButton(
                          currentUserId: currentUserId,
                          targetUserId: publicUserId ?? widget.userId,
                          isPrimary: true,
                        ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLanguagesSection(List<String> languages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.translate_rounded,
                size: 14,
                color: AppColors.accentGold,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.spokenLanguages.toUpperCase(),
              style: TextStyle(
                color: AppColors.accentGold.withOpacity(0.9),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: languages.map((lang) {
            String labelText = lang;
            if (lang == "Arabic") labelText = "العربية";
            if (lang == "English") labelText = "English";
            if (lang == "Turkish") labelText = "Türkçe";
            if (lang == "Bengali") labelText = "বাংলা";
            if (lang == "Urdu") labelText = "اردو";
            if (lang == "Farsi") labelText = "فارسی";
            if (lang == "Kurdish") labelText = "کوردي";

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withAlpha(25),
                    Colors.white.withAlpha(10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(20),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accentGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    labelText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Unchanged Widgets (Tabs, Stats, Empty State) ---
  Widget _buildTabSelector(String postCount, String courseCount) {
    return Container(
      height: 72.0, // Increased from 65.0 to prevent bottom overflow on Android
      color: AppColors.primary,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.accentGold,
        labelColor: AppColors.accentGold,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        unselectedLabelColor: AppColors.textLight.withOpacity(0.7),
        labelPadding: const EdgeInsets.symmetric(horizontal: 21.0, vertical: 5.0),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12.0,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12.0,
        ),
        tabs: [
          _buildTabWithIconAndCount(
            Icons.menu_book_outlined,
            AppLocalizations.of(context)!.courses,
            courseCount,
          ),
          _buildTabWithIconAndCount(
            Icons.star_outline,
            AppLocalizations.of(context)!.reviews, 
             // We don't have review count passed here easily, can use '?' or fetch passed reviewCount if available
             // For now let's use a placeholder or remove count requirement for reviews
             "★", 
          ),
          _buildTabWithIconAndCount(
            Icons.grid_view_outlined,
            AppLocalizations.of(context)!.posts,
            postCount,
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    return FutureBuilder<List<String>>(
      future: CommunityService().getSavedPostIds(_currentUserId ?? ''),
      builder: (context, savedSnapshot) {
        // We'll use a local list to track saves optimistically if needed, 
        // but for now let's just use the initial fetch for simple "isSaved" check.
        // For real-time updates on "saved" status across the app, a Stream is better,
        // but getSavedPostIds returns a Future<List<String>>. Here we use it directly.
        
        final List<String> savedPostIds = savedSnapshot.data ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('community_posts')
              .where('userId', isEqualTo: publicUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              );
            }
            if (snapshot.hasError) {
              return _buildEmptyState(Icons.error_outline, AppLocalizations.of(context)!.somethingWentWrong);
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(
                Icons.grid_view_outlined,
                AppLocalizations.of(context)!.noPostsYet,
              );
            }

            var posts = snapshot.data!.docs;
            // Order by timestamp descending locally since the query only filters by userId
            // (Combined indices might be needed for server-side ordering)
            try {
              posts.sort((a, b) {
                Timestamp t1 = a['timestamp'] ?? Timestamp.now();
                Timestamp t2 = b['timestamp'] ?? Timestamp.now();
                return t2.compareTo(t1);
              });
            } catch (e) {
              // ordering failed, maybe missing timestamp
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 40),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                var postData = posts[index].data() as Map<String, dynamic>;
                String postId = posts[index].id;
                
                // Get user data for the post (though we are on their profile, so we already have it mostly)
                // However, PostCard expects these fields:
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
                        // Already on the profile, maybe do nothing or scroll to top?
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
                       // Trigger rebuild to update bookmark icon
                       setState(() {}); 
                    },
                  ),
                );
              },
            );
          },
        );
      }
    );
  }

  Widget _buildCoursesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: publicUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentGold),
          );
        }
        if (snapshot.hasError) {
          return _buildEmptyState(Icons.error_outline, AppLocalizations.of(context)!.somethingWentWrong);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            Icons.menu_book_outlined,
            AppLocalizations.of(context)!.noCoursesCreated,
          );
        }

        var courses = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final doc = courses[index];
            final data = doc.data() as Map<String, dynamic>;
            final String title = CourseUtils.getLocalizedCourseName(context, data);
            final String bannerUrl = data['courseBanner'] ?? '';
            final String level = data['selectedCategory'] ?? 'Beginner';
            
            final dynamic studentsRaw = data['enrolledStudents'];
            final int studentCount = (studentsRaw is List) ? studentsRaw.length : (studentsRaw is num ? studentsRaw.toInt() : 0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: () {
                  final bool isMe = _currentUserId == publicUserId;
                  final List<dynamic> enrolledStudents = (data['enrolledStudents'] is List) ? data['enrolledStudents'] : [];
                  final bool isEnrolled = _currentUserId != null && enrolledStudents.contains(_currentUserId);

                  if (isMe || isEnrolled) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CourseDetailsPage(
                          courseId: doc.id,
                          courseData: data,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CoursePreviewPage(
                          courseId: doc.id,
                          courseData: data,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Banner Image
                        Positioned.fill(
                          child: bannerUrl.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: bannerUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.white.withOpacity(0.05),
                                    child: const Icon(Icons.image_not_supported, color: Colors.white24),
                                  ),
                                )
                              : bannerUrl.startsWith('assets')
                                  ? Image.asset(bannerUrl, fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.white.withOpacity(0.05),
                                      child: const Icon(Icons.image, color: Colors.white24),
                                    ),
                        ),
                        
                        // Gradient Overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6),
                                  Colors.black.withOpacity(0.9),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Enrollment Badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: () {
                            final List<dynamic> enrolledStudents = (data['enrolledStudents'] is List) ? data['enrolledStudents'] : [];
                            final bool isEnrolled = _currentUserId != null && enrolledStudents.contains(_currentUserId);
                            if (isEnrolled) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.enrolled.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }(),
                        ),
                        
                        // Level Badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              CourseUtils.getLocalizedLevel(context, level).toUpperCase(),
                              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        
                        // Title and Students
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AutoTranslatedText(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.people_outline, color: AppColors.accentGold, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(context)!.enrolledStudentsCount(studentCount),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReviewsTab() {
      return StreamBuilder<QuerySnapshot>(
          stream: _ratingService.getTeacherReviews(publicUserId ?? widget.userId),
          builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(Icons.star_border, AppLocalizations.of(context)!.noLikesYet); // Using noLikesYet as placeholder or add noReviewsYet
              }
              
              final rawReviews = snapshot.data!.docs;
              
              // Sort locally by timestamp descending
              final reviews = rawReviews.toList()..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                
                final Timestamp? t1 = aData['timestamp'] as Timestamp?;
                final Timestamp? t2 = bData['timestamp'] as Timestamp?;
                
                if (t1 == null || t2 == null) return 0;
                return t2.compareTo(t1);
              });
              
              return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                      final data = reviews[index].data() as Map<String, dynamic>;
                      // Creating a Review Tile
                      String formatDate(Timestamp? timestamp) {
                        if (timestamp == null) return '';
                        final date = timestamp.toDate();
                        return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                      }
                      
                      final studentId = data['studentId'] as String?;

                      return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                                width: 1,
                              ),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Row(
                                      children: [
                                          // Student Avatar with FutureBuilder
                                          studentId != null 
                                          ? FutureBuilder<DocumentSnapshot>(
                                              future: FirebaseFirestore.instance.collection('users').doc(studentId).get(),
                                              builder: (context, userSnap) {
                                                String imageUrl = '';
                                                if (userSnap.hasData && userSnap.data!.exists) {
                                                  final userData = userSnap.data!.data() as Map<String, dynamic>;
                                                  imageUrl = userData['photoUrl'] ?? '';
                                                }
                                                return CircleAvatar(
                                                    radius: 22,
                                                    backgroundColor: AppColors.accentGold.withOpacity(0.15),
                                                    backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
                                                    child: imageUrl.isEmpty ? Text(
                                                        (data['studentName'] ?? 'S').toString().isNotEmpty 
                                                            ? (data['studentName'] as String)[0].toUpperCase() 
                                                            : 'S',
                                                        style: const TextStyle(
                                                            color: AppColors.accentGold, 
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                        ),
                                                    ) : null,
                                                );
                                              },
                                            )
                                          : CircleAvatar(
                                              radius: 22,
                                              backgroundColor: AppColors.accentGold.withOpacity(0.15),
                                              child: Text(
                                                  (data['studentName'] ?? 'S').toString().isNotEmpty 
                                                      ? (data['studentName'] as String)[0].toUpperCase() 
                                                      : 'S',
                                                  style: const TextStyle(
                                                      color: AppColors.accentGold, 
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                  ),
                                              ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                      Text(
                                                          data['studentName'] ?? 'Student',
                                                          style: const TextStyle(
                                                              fontWeight: FontWeight.bold, 
                                                              color: AppColors.textPrimary,
                                                              fontSize: 16,
                                                          ),
                                                      ),
                                                      if (data['courseName'] != null)
                                                          Padding(
                                                              padding: const EdgeInsets.only(top: 2.0),
                                                              child: Text(
                                                                  "${data['courseName']}",
                                                                  style: TextStyle(
                                                                      color: AppColors.accentGold.withOpacity(0.8), 
                                                                      fontSize: 12,
                                                                  ),
                                                              ),
                                                          ),
                                                  ],
                                              ),
                                          ),
                                          // Star Rating
                                          Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: List.generate(5, (starIndex) {
                                                final rating = data['rating'] as int? ?? 5;
                                                return Icon(
                                                  starIndex < rating 
                                                      ? Icons.star_rounded 
                                                      : Icons.star_outline_rounded,
                                                  color: AppColors.accentGold,
                                                  size: 18,
                                                );
                                              }),
                                          ),
                                      ],
                                  ),
                                  if (data['reviewText'] != null && data['reviewText'].toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                        data['reviewText'].toString().trim(),
                                        style: TextStyle(
                                            color: AppColors.textLight.withOpacity(0.9), 
                                            height: 1.5,
                                            fontSize: 14,
                                        ),
                                    ),
                                  ],
                                  if (data['timestamp'] != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                        formatDate(data['timestamp'] as Timestamp?),
                                        style: TextStyle(
                                          color: AppColors.textLight.withOpacity(0.4),
                                          fontSize: 11,
                                        ),
                                    ),
                                  ]
                              ],
                          ),
                      );
                  },
              );
          },
      );
  }

  // Method replaced by global utility showProfileImageDialog

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  Widget _buildTabWithIconAndCount(IconData icon, String label, String count) {
    return Tab(
      height: 68.0, // <-- Added explicit height here to prevent 46.0 constraint
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  count,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60.0, color: AppColors.textLight.withOpacity(0.5)),
          const SizedBox(height: 16.0),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textLight.withOpacity(0.7),
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------
// --- NEW WIDGETS ADDED FOR FOLLOW LISTS ---
// -----------------------------------------------------------------
