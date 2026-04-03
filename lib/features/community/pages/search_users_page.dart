// lib/features/community/pages/search_users_page.dart

import 'dart:async'; // Required for Timer (Debounce)
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/teacher/pages/public_profile/public_teacher_profile_page.dart';
import 'package:calligro_app/features/student/pages/public_profile/public_student_profile_page.dart';
import 'package:calligro_app/features/community/services/user_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../widgets/follow_button.dart';

// Ensure UserService uses the updated logic provided above
final UserService _userService = UserService();

class SearchUsersPage extends StatefulWidget {
  final String currentLoggedInUserId;
  final Function(String userId, String userRole) onProfileTap;

  const SearchUsersPage({
    super.key,
    required this.currentLoggedInUserId,
    required this.onProfileTap,
  });

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- Search Logic ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Debounce: Wait 500ms after user stops typing to reduce flickering
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _hasSearched = false;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Logic is now delegated to UserService which handles
      // "Contains" and "Case Insensitive" matching.
      final users = await _userService.searchUsersByName(query);

      if (mounted) {
        setState(() {
          _results = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error searching users: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToProfile(
    BuildContext context,
    String tappedUserId,
    String userRole,
  ) {
    if (tappedUserId == widget.currentLoggedInUserId) {
      widget.onProfileTap(tappedUserId, userRole);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textLight,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
          cursorColor: AppColors.accentGold,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchByName,
            hintStyle: TextStyle(
              color: AppColors.textLight.withOpacity(0.7),
              fontSize: 18,
            ),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textLight),
              onPressed: () {
                _searchController.clear();
                _executeSearch('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentGold),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: AppColors.textLight.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.searchTeachersStudents,
              style: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.textLight.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noUsersFound,
              style: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final userData = _results[index];
        final bool isCurrentUser =
            userData['id'] == widget.currentLoggedInUserId;

        return _UserSearchTile(
          userData: userData,
          isCurrentUser: isCurrentUser,
          currentLoggedInUserId: widget.currentLoggedInUserId,
          onTap: (String userId, String userRole) {
            _navigateToProfile(context, userId, userRole);
          },
        );
      },
      separatorBuilder: (context, index) => Divider(
        color: AppColors.textLight.withOpacity(0.1),
        height: 1,
        indent: 16,
        endIndent: 16,
      ),
    );
  }
}

class _UserSearchTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool isCurrentUser;
  final String currentLoggedInUserId;
  final Function(String userId, String userRole) onTap;

  const _UserSearchTile({
    required this.userData,
    required this.isCurrentUser,
    required this.currentLoggedInUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String userId = userData['id'];
    final String userName = userData['name'] ?? 'User';
    final String userImageUrl = userData['photoUrl'] ?? '';
    final String userRole = userData['role'] ?? 'student';

    List<Widget> titleWidgets = [
      Flexible(
        child: Text(
          userName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            overflow: TextOverflow.ellipsis,
          ),
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
    }

    if (userRole == 'teacher') {
      titleWidgets.add(
        const Padding(
          padding: EdgeInsets.only(left: 6.0),
          child: Icon(Icons.assignment_ind, color: AppColors.accentGold, size: 16.0),
        ),
      );
    } else if (userRole == 'admin') {
      titleWidgets.add(
        const Padding(
          padding: EdgeInsets.only(left: 6.0),
          child: Icon(Icons.verified, color: AppColors.accentGold, size: 16.0),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: (userImageUrl.isNotEmpty)
            ? CachedNetworkImageProvider(userImageUrl)
            : null,
        backgroundColor: AppColors.goldGradientEnd,
        child: (userImageUrl.isEmpty)
            ? const Icon(Icons.person, color: AppColors.primary)
            : null,
      ),
      title: Row(children: titleWidgets),
      subtitle: Text(
        userRole == 'teacher'
            ? AppLocalizations.of(context)!.teacherRole
            : (userRole == 'admin' ? AppLocalizations.of(context)!.administrator : AppLocalizations.of(context)!.studentRole),
        style: TextStyle(
          color: AppColors.textLight.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
      trailing: isCurrentUser
          ? null
          : FollowButton(
              currentUserId: currentLoggedInUserId,
              targetUserId: userId,
              isPrimary: false,
            ),
      onTap: () => onTap(userId, userRole),
    );
  }
}
