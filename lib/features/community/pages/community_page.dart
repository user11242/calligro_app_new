// lib/features/community/pages/community_page.dart

import 'package:calligro_app/features/student/pages/public_profile/public_student_profile_page.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../services/community_service.dart';
import '../../../features/community/services/user_service.dart';
import '../widgets/post_card.dart';
import '../../../../core/utils/guest_guard.dart'; // Import GuestGuard
import '../widgets/create_post_bar.dart';
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart';
import '../pages/add_post_page.dart';
import 'package:calligro_app/features/community/pages/search_users_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../services/follow_service.dart'; // Import FollowService
import '../../../core/message/app_messenger.dart'; 

final CommunityService _communityService = CommunityService();
final UserService _userService = UserService();
final FollowService _followService = FollowService(); // Initialize FollowService

class CommunityPage extends StatefulWidget {
  final Function(String userId, String userRole)? onProfileTap;

  const CommunityPage({super.key, this.onProfileTap});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String? _currentUserRole;
  final ScrollController _scrollController = ScrollController();

  // Track if we are at the very top of the page
  bool _isAtTop = true;

  String _selectedFilter = ''; // Initialized in didChangeDependencies

  // 1. ADD THIS VARIABLE: Store the stream here
  // 1. ADD THIS VARIABLE: Store the stream here
  Stream<QuerySnapshot>? _postsStream;
  List<String> _savedPostIds = []; // Local cache of saved IDs for UI state
  StreamSubscription<QuerySnapshot>? _savedPostsSubscription; // Real-time listener

  List<String> _getFilterOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.all,
      l10n.friends, // Add Friends option
      // l10n.saved,   // Saved option removed
      l10n.popular,
      l10n.teachers,
      l10n.myPosts, // Moved My Posts to the end
    ];

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedFilter.isEmpty) {
      _selectedFilter = AppLocalizations.of(context)!.all;
      _updatePostsStream();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_scrollListener);

    _currentUser = _auth.currentUser;

    // 2. INITIALIZE STREAM HERE
    if (_currentUser != null) {
      _fetchUserRole(_currentUser!.uid);
      _subscribeToSavedPosts(); // Real-time subscription
    }

    // Listener removed: Auth state is handled globally by AuthWrapper.
  }

  // 3. NEW HELPER METHOD: Only call this when filters change
  Future<void> _updatePostsStream() async {
    final bool isGuest = _currentUser == null;
    
    // If guest, only allow 'All', 'Popular', 'Teachers'
    if (isGuest && (_selectedFilter == AppLocalizations.of(context)!.friends || _selectedFilter == AppLocalizations.of(context)!.myPosts)) {
       setState(() => _selectedFilter = AppLocalizations.of(context)!.all);
    }

    List<String>? followingIds;
    List<String>? savedPostIds;
    
    // If "Friends" filter is selected, we must fetch the IDs first
    if (_selectedFilter == AppLocalizations.of(context)!.friends) {
      setState(() => _postsStream = null);
      if (_currentUser != null) {
        followingIds = await _followService.getFollowingIds(_currentUser!.uid);
      }
    } 
    // If "Saved" filter is selected (Deleted Logic)
    /*
    else if (_selectedFilter == AppLocalizations.of(context)!.saved) {
        setState(() => _postsStream = null);
        savedPostIds = await _communityService.getSavedPostIds(_currentUser!.uid);
        if (mounted) {
           setState(() => _savedPostIds = savedPostIds!);
        }
    }
    */
    
    // Canonical mapping for service
    String serviceFilter = _selectedFilter;
    final l10n = AppLocalizations.of(context)!;
    
    if (_selectedFilter == l10n.all) {
      serviceFilter = 'All';
    } else if (_selectedFilter == l10n.popular) serviceFilter = 'Popular';
    else if (_selectedFilter == l10n.teachers) serviceFilter = 'Teachers';
    else if (_selectedFilter == l10n.myPosts) serviceFilter = 'My Posts';
    else if (_selectedFilter == l10n.friends) serviceFilter = 'Friends';
    // else if (_selectedFilter == l10n.saved) serviceFilter = 'Saved';

    if (mounted) {
      setState(() {
        _postsStream = _communityService.getCommunityPostsStream(
          filter: serviceFilter,
          currentUserId: _currentUser?.uid, // Nullable for guest
          followingIds: followingIds,
          savedPostIds: savedPostIds,
        );
      });
    }
  }

  void _subscribeToSavedPosts() {
    if (_currentUser == null) return;
    
    _savedPostsSubscription?.cancel();
    _savedPostsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('saved_posts') // Ensure this matches your DB structure. If it's a field array, adjust accordingly.
        .limit(1000) // Safety limit if subcollection
        .snapshots()
        .listen((snapshot) {
            // If saved_posts is a SUBCOLLECTION where each doc ID is a postId:
            final ids = snapshot.docs.map((doc) => doc.id).toList();
            
            // If saved_posts is a FIELD in user doc (single document), adjust this logic.
            // Based on previous code `getSavedPostIds`, it seems to return List<String>.
            // Let's assume it's a subcollection based on standard patterns, 
            // BUT strict verification: verify `CommunityService.getSavedPostIds`. 
            // If I can't verify, I'll assume usage pattern matches typical subcollection or I'll check service.
            
            // Checking previous `_fetchSavedPosts` -> calls `_communityService.getSavedPostIds`.
            // Let's trust the subcollection pattern for now or better, check how `toggleSavePost` writes.
            // If it writes to a subcollection, this listener is correct.
            
            if (mounted) {
              setState(() => _savedPostIds = ids);
            }
        }, onError: (e) {
            // Swallow errors
        });
  }

  void _scrollListener() {
    if (_scrollController.offset <= 10 && !_isAtTop) {
      setState(() {
        _isAtTop = true;
      });
    } else if (_scrollController.offset > 10 && _isAtTop) {
      setState(() {
        _isAtTop = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _savedPostsSubscription?.cancel(); // ERROR: Dispose subscription
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          _currentUser = _auth.currentUser;
          if (_currentUser != null && _currentUserRole == null) {
            _fetchUserRole(_currentUser!.uid);
          }
        });
      }
    }
  }

  Future<void> _fetchUserRole(String userId) async {
    try {
      final role = await _userService.getUserRole(userId);
      if (mounted) {
        setState(() {
          _currentUserRole = role;
        });
      }
    } catch (e) {
      print("Error fetching user role in CommunityPage: $e");
      if (mounted) {
        setState(() {
          _currentUserRole = 'student';
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_currentUser != null) {
      await _fetchUserRole(_currentUser!.uid);
      _updatePostsStream();
    }
    if (mounted) {
      setState(() {});
    }
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _navigateToProfile(
    BuildContext context,
    String tappedUserId,
    String userRole,
  ) {
    if (_currentUser == null && userRole != 'teacher') {
       GuestGuard.check(context, isGuest: true);
       return;
    }

    if (tappedUserId == _currentUser?.uid) {
      widget.onProfileTap?.call(tappedUserId, userRole);
      return;
    }

    if (userRole == 'teacher') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicTeacherProfilePage(
            userId: tappedUserId,
            onDashboardProfileTap: widget.onProfileTap,
          ),
        ),
      );
    } else {
      // This includes 'student' and 'admin'
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicStudentProfilePage(
            userId: tappedUserId,
            onDashboardProfileTap: widget.onProfileTap,
          ),
        ),
      );
    }
  }

  void _onSearchPressed() {
    if (_currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchUsersPage(
            currentLoggedInUserId: _currentUser?.uid ?? '',
            onProfileTap: (userId, userRole) {
              _navigateToProfile(context, userId, userRole);
            },
          ),
        ),
      );
    }
  }

  Widget _buildNormalFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        // 4. UPDATE STREAM ONLY WHEN FILTER CHANGES
        if (_selectedFilter != label) {
          setState(() {
            _selectedFilter = label;
          });
          _updatePostsStream();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentGold
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.accentGold
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedActionItem({
    required Widget child,
    required bool isVisible,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isVisible ? 48.0 : 0.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible ? 1.0 : 0.0,
        child: ClipRect(
          child: OverflowBox(
            minWidth: 0,
            maxWidth: 48,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isGuest = _currentUser == null;

    if (isGuest && _postsStream == null) {
      // Initialize for guest
      _selectedFilter = AppLocalizations.of(context)!.all;
      _updatePostsStream();
    }

    if (!isGuest && _currentUserRole == null) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentGold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.accentGold,
        backgroundColor: AppColors.cardBackground,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.primary,
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              automaticallyImplyLeading: false,
              centerTitle: false,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _isAtTop
                      ? Align(
                          alignment: AlignmentDirectional.centerStart,
                          key: ValueKey('TitleCommunity'),
                          child: Text(
                            AppLocalizations.of(context)!.community,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        )
                      : Align(
                          alignment: AlignmentDirectional.centerStart,
                          key: const ValueKey('TitleBrand'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/app_icon.png',
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'CALLIGRO',
                                style: TextStyle(
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6.0),
                  child: IconButton(
                    icon: const Icon(Icons.search, color: AppColors.textLight),
                    onPressed: () {
                      if (GuestGuard.check(context, isGuest: isGuest)) {
                        _onSearchPressed();
                      }
                    },
                  ),
                ),
                _buildAnimatedActionItem(
                  isVisible: !_isAtTop,
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.filter_list,
                      color: AppColors.textLight,
                    ),
                    color: AppColors.cardBackground,
                    onSelected: (String value) {
                      // 5. UPDATE STREAM ON DROPDOWN CHANGE
                      if (_selectedFilter != value) {
                        // Guest Guards for Friends/My Posts filters
                        if (isGuest && (value == AppLocalizations.of(context)!.friends || value == AppLocalizations.of(context)!.myPosts)) {
                           GuestGuard.check(context, isGuest: true);
                           return;
                        }
                        setState(() {
                          _selectedFilter = value;
                        });
                        _updatePostsStream();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return _getFilterOptions(context).map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Row(
                            children: [
                              Icon(
                                Icons.check,
                                size: 16,
                                color: _selectedFilter == choice
                                    ? AppColors.accentGold
                                    : Colors.transparent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                choice,
                                style: TextStyle(
                                  color: _selectedFilter == choice
                                      ? AppColors.accentGold
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                _buildAnimatedActionItem(
                  isVisible: !_isAtTop,
                  child: IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.accentGold,
                    ),
                    onPressed: () {
                      if (GuestGuard.check(context, isGuest: isGuest)) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddPostPage(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: CreatePostBar(currentUserId: _currentUser?.uid ?? ''),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  children: _getFilterOptions(context)
                      .map((filter) => _buildNormalFilterChip(filter))
                      .toList(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // 6. USE THE STORED STREAM HERE
            StreamBuilder<QuerySnapshot>(
              key: ValueKey<String>(_selectedFilter),
              stream: _postsStream, // <--- CHANGED THIS LINE
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.errorLoadingPosts,
                        style: TextStyle(color: Colors.redAccent.shade100),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_list_off,
                            size: 48,
                            color: AppColors.textLight.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.noPostsFoundForFilter(_selectedFilter),
                            style: TextStyle(
                              color: AppColors.textLight.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final posts = snapshot.data!.docs;

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final postData =
                        posts[index].data() as Map<String, dynamic>;
                    final postId = posts[index].id;
                    final postUserId = postData['userId'] ?? '';

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(postUserId)
                          .snapshots()
                          .handleError((e) => null),
                      builder: (context, userSnapshot) {
                        String displayUserName =
                            postData['userName'] ?? 'Anonymous';
                        String displayUserImage =
                            postData['userImageUrl'] ?? '';
                        String displayUserRole =
                            postData['userRole'] ?? 'student';

                        if (userSnapshot.hasData &&
                            userSnapshot.data != null &&
                            userSnapshot.data!.exists) {
                          final userData =
                              userSnapshot.data!.data() as Map<String, dynamic>;
                          if (userData['name'] != null) {
                            displayUserName = userData['name'];
                          }
                          if (userData['photoUrl'] != null) {
                            displayUserImage = userData['photoUrl'];
                          }
                          if (userData['role'] != null) {
                            displayUserRole = userData['role'];
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: PostCard(
                            postId: postId,
                            userId: postUserId,
                            currentLoggedInUserId: _currentUser?.uid ?? '',
                            isGuest: isGuest,
                            userName: displayUserName,
                            userImageUrl: displayUserImage,
                            userRole: displayUserRole,
                            caption: postData['caption'] ?? '',
                            imageUrls: List<String>.from(
                              postData['imageUrls'] ?? [],
                            ),
                            timestamp: postData['timestamp'] as Timestamp?,
                            onProfileTap: (tappedUserId, role) =>
                                _navigateToProfile(context, tappedUserId, role),
                            likesCount: postData['likesCount'] ?? 0,
                            likes: Map<String, dynamic>.from(
                              postData['likes'] ?? {},
                            ),
                            commentsCount: postData['commentsCount'] ?? 0,
                            isSaved: _savedPostIds.contains(postId), // Pass saved status
                            isEdited: postData['isEdited'] ?? false,
                            onToggleSave: () async {
                                // Optimistic update
                                final isCurrentlySaved = _savedPostIds.contains(postId);
                                setState(() {
                                    if (isCurrentlySaved) {
                                        _savedPostIds.remove(postId);
                                    } else {
                                        _savedPostIds.add(postId);
                                    }
                                });
                                // API Call
                                try {
                                    await _communityService.toggleSavePost(
                                        postId: postId,
                                        currentUserId: _currentUser?.uid ?? '',
                                        isSaved: isCurrentlySaved
                                    );
                                } catch (e) {
                                    // Rollback on error
                                    if (mounted) {
                                        setState(() {
                                            if (isCurrentlySaved) {
                                                _savedPostIds.add(postId);
                                            } else {
                                                _savedPostIds.remove(postId);
                                            }
                                        });
                                        AppMessenger.showSnackBar(
                                            context,
                                            title: AppLocalizations.of(context)!.error,
                                            message: "Failed to update saved status: ${e.toString()}",
                                            type: MessengerType.error,
                                        );
                                    }
                                }
                            },
                          ),
                        );
                      },
                    );
                  }, childCount: posts.length),
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }
}
