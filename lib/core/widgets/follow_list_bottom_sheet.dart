import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../features/community/widgets/follow_button.dart';

class FollowListBottomSheet extends StatefulWidget {
  final DraggableScrollableController sheetController;
  final ScrollController scrollController;
  final String currentLoggedInUserId;
  final String targetUserId;
  final String listType; // "followers" or "following"
  final String title;
  final Function(String userId, String userRole) onProfileTap;
  final bool showSearch;

  const FollowListBottomSheet({
    super.key,
    required this.sheetController,
    required this.scrollController,
    required this.currentLoggedInUserId,
    required this.targetUserId,
    required this.listType,
    required this.title,
    required this.onProfileTap,
    this.showSearch = true,
  });

  @override
  State<FollowListBottomSheet> createState() => _FollowListBottomSheetState();
}

class _FollowListBottomSheetState extends State<FollowListBottomSheet> {
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
    _fetchUserIdsAndData();
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

  void _onSearchChanged() {
    if (!mounted) return;
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

  Future<void> _fetchUserIdsAndData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .collection(widget.listType)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final List<String> userIds = snapshot.docs.map((doc) => doc.id).toList();

      List<Future<DocumentSnapshot>> futures = userIds
          .map(
            (id) => FirebaseFirestore.instance.collection('users').doc(id).get(),
          )
          .toList();

      final List<DocumentSnapshot> docs = await Future.wait(futures);
      final WriteBatch cleanupBatch = FirebaseFirestore.instance.batch();
      bool needsCleanup = false;

      List<Map<String, dynamic>> users = [];
      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i];
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          users.add(data);
        } else {
          // --- ORPHANED REFERENCE DETECTED ---
          final orphanedId = userIds[i];
          needsCleanup = true;
          
          // 1. Remove from this user's subcollection
          cleanupBatch.delete(FirebaseFirestore.instance
              .collection('users')
              .doc(widget.targetUserId)
              .collection(widget.listType)
              .doc(orphanedId));
          
          // 2. Decrement the count on the parent user document
          final String countField = widget.listType == 'followers' ? 'followerCount' : 'followingCount';
          cleanupBatch.update(FirebaseFirestore.instance.collection('users').doc(widget.targetUserId), {
            countField: FieldValue.increment(-1),
          });
          
          debugPrint("Lazy Cleanup: Removed orphaned $orphanedId from ${widget.targetUserId}'s ${widget.listType}");
        }
      }

      if (needsCleanup) {
        await cleanupBatch.commit();
      }

      // Move current user to top if present
      int currentUserIndex = users.indexWhere((u) => u['id'] == widget.currentLoggedInUserId);
      if (currentUserIndex != -1) {
        Map<String, dynamic> currentUserData = users.removeAt(currentUserIndex);
        users.insert(0, currentUserData);
      }

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching follow list: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToProfile(BuildContext context, String tappedUserId, String userRole) {
    widget.onProfileTap(tappedUserId, userRole);
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
            widget.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          
          if (widget.showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    hintText: "${AppLocalizations.of(context)?.searchUsers ?? 'Search'} ${widget.title}...",
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? (AppLocalizations.of(context)?.nothingToShow ?? 'Nothing to show')
                              : (AppLocalizations.of(context)?.noUsersFound ?? 'No users found'),
                          style: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
                        ),
                      )
                    : ListView.separated(
                        controller: widget.scrollController,
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final userData = _filteredUsers[index];
                          final bool isCurrentUser = userData['id'] == widget.currentLoggedInUserId;

                          return _UserFollowTile(
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
                          indent: 72,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserFollowTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool isCurrentUser;
  final String currentLoggedInUserId;
  final Function(String userId, String userRole) onTap;

  const _UserFollowTile({
    required this.userData,
    required this.isCurrentUser,
    required this.currentLoggedInUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String userId = userData['id'] ?? '';
    final String userName = userData['name'] ?? (AppLocalizations.of(context)?.user ?? 'User');
    final String userImageUrl = userData['photoUrl'] ?? '';
    final String userRole = userData['role'] ?? 'student';

    List<Widget> titleWidgets = [
      Flexible(
        child: Text(
          userName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    if (isCurrentUser) {
      titleWidgets.add(const SizedBox(width: 6.0));
      titleWidgets.add(
        Text(
          AppLocalizations.of(context)?.youLabel ?? '(You)',
          style: TextStyle(
            color: AppColors.textLight.withOpacity(0.7),
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
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: (userImageUrl.isNotEmpty) ? CachedNetworkImageProvider(userImageUrl) : null,
        backgroundColor: AppColors.goldGradientEnd,
        child: (userImageUrl.isEmpty) ? const Icon(Icons.person, color: AppColors.primary) : null,
      ),
      title: Row(mainAxisSize: MainAxisSize.min, children: titleWidgets),
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
