// lib/features/community/widgets/likers_bottom_sheet.dart
//Done
import 'package:flutter/material.dart';
// Added for CachedNetworkImageProvider
import '../../../core/theme/colors.dart'; // Adjust path as needed
import '../services/community_service.dart'; // Import CommunityService
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart'; // Adjust path
import '../../student/pages/public_profile/public_student_profile_page.dart'; // Student profile
import '../../community/pages/follow_button.dart'; // Adjust path to your FollowButton
import '../../../core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';

final CommunityService _communityService = CommunityService();

class LikersBottomSheet extends StatefulWidget {
  final DraggableScrollableController sheetController;
  final ScrollController scrollController;
  final List<String> userIds;
  final String currentLoggedInUserId;
  final String postAuthorId;
  // --- CORRECTED THIS LINE ---
  final Function(String userId, String userRole) onProfileTap;
  // --- END CORRECTION ---

  const LikersBottomSheet({
    super.key,
    required this.sheetController,
    required this.scrollController,
    required this.userIds,
    required this.currentLoggedInUserId,
    required this.postAuthorId,
    required this.onProfileTap,
  });

  @override
  State<LikersBottomSheet> createState() => _LikersBottomSheetState();
}

class _LikersBottomSheetState extends State<LikersBottomSheet> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);

    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(_onFocusChange);

    _fetchUsersData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_searchFocusNode.hasFocus) {
        widget.sheetController.animateTo(
          0.9,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        widget.sheetController.animateTo(
          0.6,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchUsersData() async {
    try {
      final fetchedUsers = await _communityService.fetchLikersData(
        widget.userIds,
      );

      // Re-order to put current user first if they exist
      Map<String, dynamic>? currentUserData;
      int currentUserIndex = -1;
      for (int i = 0; i < fetchedUsers.length; i++) {
        if (fetchedUsers[i]['id'] == widget.currentLoggedInUserId) {
          currentUserIndex = i;
          break;
        }
      }
      if (currentUserIndex != -1) {
        currentUserData = fetchedUsers.removeAt(currentUserIndex);
        fetchedUsers.insert(0, currentUserData);
      }

      if (mounted) {
        setState(() {
          _allUsers = fetchedUsers;
          _filteredUsers = fetchedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching users for likers list: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          final String name = (user['name'] ?? '').toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  void _navigateToProfile(
    BuildContext context,
    String tappedUserId,
    String userRole,
  ) {
    Navigator.of(context).pop(); // Pop the bottom sheet first

    if (tappedUserId == widget.currentLoggedInUserId) {
      widget.onProfileTap(
        tappedUserId,
        userRole,
      ); // Call the parent's onProfileTap
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
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.info,
        message: AppLocalizations.of(context)!.profileNotAvailable,
        type: MessengerType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            AppLocalizations.of(context)!.likes,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchLikes,
                  hintStyle: TextStyle(
                    color: AppColors.textLight.withOpacity(0.7),
                  ),
                  icon: Icon(
                    Icons.search,
                    color: AppColors.textLight.withOpacity(0.7),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Divider(color: AppColors.textLight.withOpacity(0.2), height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentGold,
                    ),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? AppLocalizations.of(context)!.noLikesYet
                          : AppLocalizations.of(context)!.noUsersFound,
                      style: TextStyle(
                        color: AppColors.textLight.withOpacity(0.7),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final userData = _filteredUsers[index];
                      final bool isCurrentUser =
                          userData['id'] == widget.currentLoggedInUserId;

                      return _UserLikeTile(
                        userData: userData,
                        isCurrentUser: isCurrentUser,
                        postAuthorId: widget.postAuthorId,
                        currentLoggedInUserId: widget.currentLoggedInUserId,
                        onTap: (String userId, String userRole) {
                          _navigateToProfile(context, userId, userRole);
                        },
                      );
                    },
                    separatorBuilder: (context, index) => Divider(
                      color: AppColors.textLight.withOpacity(0.1),
                      height: 1,
                      indent: 72,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Helper Widget for LikersBottomSheet
class _UserLikeTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool isCurrentUser;
  final String postAuthorId;
  final String currentLoggedInUserId;
  // This onTap is already correctly defined in your code
  final Function(String userId, String userRole) onTap;

  const _UserLikeTile({
    required this.userData,
    required this.isCurrentUser,
    required this.postAuthorId,
    required this.currentLoggedInUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String userId = userData['id'];
    final String userName = userData['name'] ?? AppLocalizations.of(context)!.user;
    final String userImageUrl = userData['photoUrl'] ?? '';
    final String userRole = userData['role'] ?? 'student';
    final bool isPostAuthor = (userId == postAuthorId);

    List<Widget> titleWidgets = [
      Text(
        userName,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

    if (isCurrentUser) {
      titleWidgets.add(const SizedBox(width: 6.0));
      titleWidgets.add(
        Text(
          AppLocalizations.of(context)!.youLabel,
          style: TextStyle(
            color: AppColors.textLight.withOpacity(0.7),
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
        ),
      );
    } else if (isPostAuthor) {
      titleWidgets.add(const SizedBox(width: 6.0));
      titleWidgets.add(
        Text(
          AppLocalizations.of(context)!.authorLabel,
          style: TextStyle(
            color: AppColors.accentGold.withOpacity(0.8),
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
        ),
      );
    }

    if (userRole == 'teacher') {
      titleWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: Icon(Icons.assignment_ind, color: AppColors.accentGold, size: 16.0),
        ),
      );
    }

    return ListTile(
      leading: ProfileAvatar(
        radius: 20,
        imageUrl: userImageUrl,
      ),
      title: Row(children: titleWidgets),
      trailing: isCurrentUser
          ? null // Don't show a button for yourself
          : FollowButton(
              currentUserId: currentLoggedInUserId,
              targetUserId: userId,
              isPrimary: false, // Use the outlined "Follow" button style
            ),
      onTap: () => onTap(userId, userRole),
    );
  }
}
