// lib/features/community/widgets/comment_tile.dart
//Done
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
// For user avatars
import '../../../core/theme/colors.dart'; // Adjust path as needed
import '../services/community_service.dart'; // Import your CommunityService
import '../../../core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'edit_comment_sheet.dart';

final CommunityService _communityService = CommunityService();

class CommentTile extends StatefulWidget {
  final String postId;
  final String commentId;
  final Map<String, dynamic> commentData;
  final String currentLoggedInUserId;
  final String postAuthorId;
  final Function(BuildContext context, String userId, String userRole)
  onProfileTap;
  final Function(String rootCommentId, String userName) onReply;
  final bool isReply;
  final String? rootCommentId; // Required if isReply is true

  const CommentTile({
    super.key,
    required this.postId,
    required this.commentId,
    required this.commentData,
    required this.currentLoggedInUserId,
    required this.postAuthorId,
    required this.onProfileTap,
    required this.onReply,
    this.isReply = false,
    this.rootCommentId,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isDeleting = false;
  bool _isExpanded = false;

  Future<void> _deleteComment(BuildContext context) async {
    final bool didConfirm =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: BorderSide(
                  color: AppColors.textLight.withOpacity(0.2),
                ),
              ),
              title: Text(
                widget.isReply
                    ? AppLocalizations.of(context)!.deleteReply
                    : AppLocalizations.of(context)!.deleteComment,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              content: Text(
                widget.isReply
                    ? AppLocalizations.of(context)!.deleteReplyConfirm
                    : AppLocalizations.of(context)!.deleteCommentConfirm,
                style: const TextStyle(color: AppColors.textLight),
              ),
              actions: [
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text(
                    AppLocalizations.of(context)!.delete,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!didConfirm) return;

    setState(() {
      _isDeleting = true;
    });

    final localizations = AppLocalizations.of(context)!;
    try {
      if (widget.isReply) {
        if (widget.rootCommentId == null) {
          throw Exception("Root comment ID missing for reply deletion");
        }
        await _communityService.deleteReply(
          postId: widget.postId,
          commentId: widget.rootCommentId!,
          replyId: widget.commentId,
        );
      } else {
        await _communityService.deleteComment(
          postId: widget.postId,
          commentId: widget.commentId,
        );
      }
    } catch (e) {
      print("Error deleting item: $e");
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: localizations.error,
          message: widget.isReply
              ? localizations.failedToDeleteReply
              : localizations.failedToDeleteComment,
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  // SEPARATE DELETE FUNCTION FOR REPLIES (Need parent ID)

  Future<void> _showEditCommentSheet(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final Widget sheet = EditCommentSheet(
      initialText: widget.commentData['text'] ?? '',
      isReply: widget.isReply,
      onSave: (newText) async {
        try {
          if (widget.isReply) {
            if (widget.rootCommentId == null) {
              throw Exception("Root ID missing for reply edit");
            }
            await _communityService.editReply(
              postId: widget.postId,
              commentId: widget.rootCommentId!,
              replyId: widget.commentId,
              newText: newText,
            );
          } else {
            await _communityService.editComment(
              postId: widget.postId,
              commentId: widget.commentId,
              newText: newText,
            );
          }
        } catch (e) {
          if (mounted) {
            AppMessenger.showSnackBar(
              context,
              title: localizations.error,
              message: localizations.failedToSaveChanges,
              type: MessengerType.error,
            );
          }
          rethrow;
        }
      },
    );

    if (Theme.of(context).platform == TargetPlatform.android) {
      showDialog(
        context: context,
        builder: (dialogContext) => sheet,
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => sheet,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... extract data ...
    final String userId = widget.commentData['userId'] ?? '';
    final String userName = widget.commentData['userName'] ?? 'User';
    final String userPhotoUrl = widget.commentData['userPhotoUrl'] ?? '';
    final String text = widget.commentData['text'] ?? '...';
    final Timestamp? timestamp = widget.commentData['timestamp'] as Timestamp?;
    final String userRole = widget.commentData['userRole'] ?? 'student';
    final String languageCode = Localizations.localeOf(context).languageCode;
    final String timeAgo = timestamp != null
        ? timeago.format(timestamp.toDate(), locale: '${languageCode}_short')
        : '...';

    final bool isCurrentUser = (userId == widget.currentLoggedInUserId);

    return Opacity(
      opacity: _isDeleting ? 0.5 : 1.0,
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.isReply ? 52.0 : 16.0,
          right: 16.0,
          top: 8.0,
          bottom: 8.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. COMMMENT CONTENT ROW
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => widget.onProfileTap(context, userId, userRole),
                  child: ProfileAvatar(
                    radius: 16,
                    imageUrl: userPhotoUrl,
                  ), // Smaller avatar
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Time
                      Row(
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (userRole == 'teacher')
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                Icons.assignment_ind,
                                color: AppColors.accentGold,
                                size: 14,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 11,
                            ),
                          ),
                          if (widget.commentData['isEdited'] == true) ...[
                            const SizedBox(width: 4),
                            Text(
                              "(${AppLocalizations.of(context)!.edited})",
                              style: TextStyle(
                                color:
                                    AppColors.textLight.withOpacity(0.5),
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Text with expandable support
                      Text(
                        text,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                        ),
                        maxLines: _isExpanded ? null : 6,
                        overflow: _isExpanded ? null : TextOverflow.ellipsis,
                      ),
                      if (text.length > 300)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _isExpanded
                                  ? AppLocalizations.of(context)!.showLess
                                  : AppLocalizations.of(context)!.showMore,
                              style: const TextStyle(
                                color: AppColors.accentGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Actions Row (Reply, Delete)
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Reply Button
                          GestureDetector(
                            onTap: () {
                              // For both root and reply, we want to reply to the thread.
                              // If this is root, ID is widget.commentId.
                              // If this is reply, root is widget.rootCommentId.
                              final String targetRootId = widget.isReply
                                  ? widget.rootCommentId!
                                  : widget.commentId;
                              widget.onReply(
                                targetRootId,
                                userName,
                              ); // Keep distinct userName so we "Reply to @User"
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.reply,
                                    size: 14,
                                    color: AppColors.textLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppLocalizations.of(context)!.reply,
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Delete/Edit (Menu) if owner
                          // Using simple text buttons here for cleaner look? or keeping menu?
                          // Menu is better for space.
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu (Keep existing)
                if (isCurrentUser)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz,
                      size: 16,
                      color: AppColors.textLight,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditCommentSheet(context);
                      } else if (value == 'delete') {
                        _deleteComment(context);
                      }
                    },
                    itemBuilder: (c) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          AppLocalizations.of(context)!.delete,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(AppLocalizations.of(context)!.edit),
                      ),
                    ],
                  ),
              ],
            ),

            // 2. NESTED REPLIES (Only if logic says so, i.e. not isReply)
            if (!widget.isReply)
              StreamBuilder<QuerySnapshot>(
                stream: _communityService.getRepliesStream(
                  widget.postId,
                  widget.commentId,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final replies = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: replies.length,
                    itemBuilder: (context, index) {
                      final rData =
                          replies[index].data() as Map<String, dynamic>;
                      return CommentTile(
                        postId: widget.postId,
                        commentId: replies[index].id,
                        commentData: rData,
                        currentLoggedInUserId: widget.currentLoggedInUserId,
                        postAuthorId: widget.postAuthorId,
                        onProfileTap: widget.onProfileTap,
                        onReply: (rootId, name) => widget.onReply(
                          widget.commentId,
                          name,
                        ), // Always pass OUR ID as root
                        isReply: true,
                        rootCommentId: widget.commentId,
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
