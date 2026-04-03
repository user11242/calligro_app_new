import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/colors.dart';
import '../services/community_service.dart';
import 'likers_bottom_sheet.dart';
import 'comments_bottom_sheet.dart';
import 'post_image_carousel.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart';
import '../../student/pages/public_profile/public_student_profile_page.dart';
import '../../../core/message/app_messenger.dart';
import '../../../../core/utils/guest_guard.dart'; // Import GuestGuard
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import '../pages/edit_post_page.dart';

final CommunityService _communityService = CommunityService();

class PostCard extends StatefulWidget {
  final String postId;
  final String userId;
  final String currentLoggedInUserId;
  final String userName;
  final String userImageUrl;
  final String caption;
  final List<String> imageUrls;
  final Timestamp? timestamp;
  final String userRole;
  final Function(String userId, String userRole) onProfileTap;
  final int likesCount;
  final Map<String, dynamic> likes;
  final int commentsCount;
  final bool isSaved; // New field
  final bool isGuest; // New flag
  final bool isEdited; // New field
  final VoidCallback onToggleSave; // New callback

  const PostCard({
    super.key,
    required this.postId,
    required this.userId,
    required this.currentLoggedInUserId,
    required this.userName,
    required this.userImageUrl,
    required this.caption,
    required this.imageUrls,
    required this.timestamp,
    required this.userRole,
    required this.onProfileTap,
    required this.likesCount,
    required this.likes,
    required this.commentsCount,
    required this.isSaved,
    required this.isGuest,
    required this.isEdited,
    required this.onToggleSave,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  bool _isDeleting = false;
  late bool _isLiked;
  late int _currentLikesCount;
  bool _isLikeProcessing = false;
  String? _currentUserRole;

  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnimation;

  bool _isExpanded = false;
  final int _maxLinesCollapsed = 3;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.likes.containsKey(widget.currentLoggedInUserId);
    _currentLikesCount = widget.likesCount;
    _fetchCurrentUserRole();

    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _likeScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeAnimController, curve: Curves.easeOut),
    );

    _likeAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _likeAnimController.reverse();
      }
    });
  }

  Future<void> _fetchCurrentUserRole() async {
    if (widget.currentLoggedInUserId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentLoggedInUserId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUserRole = doc.data()?['role'] ?? 'student';
        });
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.likes != oldWidget.likes ||
        widget.likesCount != oldWidget.likesCount) {
      _isLiked = widget.likes.containsKey(widget.currentLoggedInUserId);
      _currentLikesCount = widget.likesCount;
    }
    if (widget.currentLoggedInUserId != oldWidget.currentLoggedInUserId) {
      _fetchCurrentUserRole();
    }
  }

  // --- Logic Helpers ---

  bool _isTextOverflowing(String text, int maxLines, TextStyle style) {
    final double maxWidth = MediaQuery.of(context).size.width - 24.0;
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: Directionality.of(context),
    )..layout(minWidth: 0, maxWidth: maxWidth);
    return textPainter.didExceedMaxLines;
  }

  // --- Action Functions ---

  void _sharePost() {
    final l10n = AppLocalizations.of(context)!;
    // Generate the deep link
    final String postLink = "https://calligro.digital/post/${widget.postId}";

    String shareContent =
        "${l10n.postedBy(widget.userName)}\n\n${widget.caption}";

    // Add the view link
    shareContent += "\n\n${l10n.viewOnCalligro}: $postLink";

    if (widget.imageUrls.isNotEmpty) {
      shareContent += "\n\n${l10n.checkOutImage} ${widget.imageUrls.first}";
    }
    shareContent += "\n\n${l10n.sentFromCalligro}";
    Share.share(shareContent);
  }

  Future<void> _toggleLike() async {
    if (!GuestGuard.check(context, isGuest: widget.isGuest)) return;
    if (_isLikeProcessing) return;
    _likeAnimController.forward();
    setState(() => _isLikeProcessing = true);

    final bool newIsLikedState = !_isLiked;
    final int newLikesCount = newIsLikedState
        ? _currentLikesCount + 1
        : _currentLikesCount - 1;

    setState(() {
      _isLiked = newIsLikedState;
      _currentLikesCount = newLikesCount;
    });

    try {
      await _communityService.toggleLike(
        postId: widget.postId,
        currentUserId: widget.currentLoggedInUserId,
        isLiked: !newIsLikedState,
      );
    } catch (e) {
      setState(() {
        _isLiked = !newIsLikedState;
        _currentLikesCount = widget.likesCount;
      });
    } finally {
      if (mounted) setState(() => _isLikeProcessing = false);
    }
  }

  void _showLikers() {
    // Viewing likes is public - no guest guard needed
    if (_currentLikesCount == 0) return;
    final DraggableScrollableController sheetController =
        DraggableScrollableController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.6,
        minChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => LikersBottomSheet(
          sheetController: sheetController,
          scrollController: scrollController,
          userIds: widget.likes.keys.toList(),
          currentLoggedInUserId: widget.currentLoggedInUserId,
          postAuthorId: widget.userId,
          onProfileTap: (userId, userRole) {
            _navigateToProfile(context, userId, userRole);
          },
        ),
      ),
    );
  }

  void _showComments() {
    // Guests can view comments. They will be prompted to login only when attempting to POST.

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final screenHeight = MediaQuery.of(context).size.height;
        final maxSheetHeight = screenHeight * 0.85; // 85% max height
        double contentHeight = screenHeight * 0.7; // Default 70% height
        if (contentHeight + bottomInset > maxSheetHeight) {
          contentHeight = maxSheetHeight - bottomInset;
        }

        if (contentHeight < 200) contentHeight = 200; // Safety bounds

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: contentHeight,
            child: CommentsBottomSheet(
              postId: widget.postId,
              currentLoggedInUserId: widget.currentLoggedInUserId,
              postAuthorId: widget.userId,
              onProfileTap: (userId, userRole) {
                _navigateToProfile(context, userId, userRole);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePost() async {
    final bool didConfirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: Text(
              AppLocalizations.of(context)!.deletePost,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              AppLocalizations.of(context)!.areYouSure,
              style: const TextStyle(color: AppColors.textLight),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  AppLocalizations.of(context)!.delete,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!didConfirm) return;

    final localizations = AppLocalizations.of(context)!;

    setState(() => _isDeleting = true);
    try {
      await _communityService.deletePost(
        postId: widget.postId,
        postAuthorId: widget.userId,
        imageUrls: widget.imageUrls,
      );
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: localizations.error,
          message: localizations.failedToDelete(e.toString()),
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
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
          builder: (ctx) => PublicTeacherProfilePage(userId: tappedUserId),
        ),
      );
    } else if (userRole == 'student' || userRole == 'admin') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PublicStudentProfilePage(userId: tappedUserId),
        ),
      );
    } else {
      // Other roles
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.info,
        message: AppLocalizations.of(context)!.profileNotAvailable,
        type: MessengerType.info,
      );
    }
  }

  Future<void> _editPost() async {
    final bool? didUpdate = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostPage(
          postId: widget.postId,
          initialCaption: widget.caption,
          initialImageUrls: widget.imageUrls,
        ),
      ),
    );

    if (didUpdate == true && mounted) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.success,
        message: AppLocalizations.of(context)!.postUpdated,
        type: MessengerType.success,
      );
    }
  }

  Widget _buildReactionStack() {
    return SizedBox(
      width: 50,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
              ),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.favorite, size: 12, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            right: 18,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
              ),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.blue,
                child: Icon(Icons.thumb_up, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String timeAgo = widget.timestamp != null
        ? timeago.format(
            widget.timestamp!.toDate(),
            locale: '${Localizations.localeOf(context).languageCode}_short',
          )
        : AppLocalizations.of(context)!.justNow;
    final bool isPostAuthor = widget.userId == widget.currentLoggedInUserId;
    const TextStyle captionStyle = TextStyle(
      color: AppColors.textLight,
      fontSize: 15,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _navigateToProfile(
                      context,
                      widget.userId,
                      widget.userRole,
                    ),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          radius: 20,
                          imageUrl: widget.userImageUrl,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.userName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (widget.userRole == 'teacher')
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Icon(
                                      Icons.assignment_ind,
                                      color: AppColors.accentGold,
                                      size: 18,
                                    ),
                                  ),
                                if (widget.userRole == 'admin')
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.verified,
                                      color: AppColors.accentGold,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    color: AppColors.textLight.withOpacity(
                                      0.7,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                                if (widget.isEdited) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    "(${AppLocalizations.of(context)!.edited})",
                                    style: TextStyle(
                                      color: AppColors.textLight.withOpacity(
                                        0.5,
                                      ),
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_isDeleting)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentGold,
                      ),
                    )
                  else if (isPostAuthor || _currentUserRole == 'admin')
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textLight,
                      ),
                      color: AppColors.cardBackground,
                      onSelected: (v) {
                        if (v == 'delete') {
                          _deletePost();
                        } else if (v == 'edit') {
                          _editPost();
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (isPostAuthor)
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit,
                                  color: AppColors.accentGold,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.edit,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.delete,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Caption
            if (widget.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.caption,
                      style: captionStyle,
                      maxLines: _isExpanded ? null : _maxLinesCollapsed,
                      overflow: _isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    if (!_isExpanded &&
                        _isTextOverflowing(
                          widget.caption,
                          _maxLinesCollapsed,
                          captionStyle,
                        ))
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = true),
                        child: Text(
                          AppLocalizations.of(context)!.seeMore,
                          style: const TextStyle(color: AppColors.accentGold),
                        ),
                      ),
                    if (_isExpanded &&
                        _isTextOverflowing(
                          widget.caption,
                          _maxLinesCollapsed,
                          captionStyle,
                        ))
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = false),
                        child: Text(
                          AppLocalizations.of(context)!.showLess,
                          style: const TextStyle(color: AppColors.accentGold),
                        ),
                      ),
                  ],
                ),
              ),

            // Images
            if (widget.imageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostImageCarousel(imageUrls: widget.imageUrls),
              ),

            const Divider(height: 1, color: Colors.white10),

            // ----------------------------------------------------------------
            // BOTTOM ACTIONS
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  // LIKE BUTTON
                  InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(4.0),
                    child: Row(
                      children: [
                        ScaleTransition(
                          scale: _likeScaleAnimation,
                          child: Icon(
                            _isLiked
                                ? Icons.thumb_up
                                : Icons.thumb_up_alt_outlined,
                            size: 20,
                            color: _isLiked
                                ? AppColors.accentGold
                                : AppColors.textLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$_currentLikesCount",
                          style: TextStyle(
                            color: _isLiked
                                ? AppColors.accentGold
                                : AppColors.textLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // COMMENT BUTTON
                  InkWell(
                    onTap: _showComments,
                    borderRadius: BorderRadius.circular(4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.commentsCount.toString(),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // SHARE BUTTON
                  InkWell(
                    onTap: _sharePost,
                    borderRadius: BorderRadius.circular(4.0),
                    child: const Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: AppColors.textLight,
                    ),
                  ),

                  const SizedBox(width: 24),

                  // SAVE / BOOKMARK BUTTON
                  InkWell(
                    onTap: () {
                      if (GuestGuard.check(context, isGuest: widget.isGuest)) {
                        widget.onToggleSave();
                      }
                    },
                    borderRadius: BorderRadius.circular(4.0),
                    child: Icon(
                      widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: widget.isSaved
                          ? AppColors.accentGold
                          : AppColors.textLight,
                    ),
                  ),

                  const Spacer(),

                  // LIKE STACK (With Size Reservation to prevent jump)
                  if (_currentLikesCount > 0)
                    InkWell(onTap: _showLikers, child: _buildReactionStack())
                  else
                    // This invisible box ensures the Row height doesn't collapse
                    // when the real reaction stack is missing.
                    const SizedBox(width: 50, height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
