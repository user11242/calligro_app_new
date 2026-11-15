import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/comments_controller.dart';
import '../../domain/models/community_models.dart';
import 'community_dialogs.dart';
import 'edit_comment_sheet.dart';

/// A comment (with its live replies underneath) or, when [parent] is set, a reply.
class CommentTile extends StatefulWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.controller,
    required this.onOpenProfile,
    required this.onReply,
    this.parent,
  });

  final CommunityComment comment;
  final CommentsController controller;

  /// The top-level comment this reply belongs to; null for a top-level comment.
  final CommunityComment? parent;
  final void Function(String userId, String role) onOpenProfile;

  /// Called with the name being answered; the sheet attaches the reply to the root comment.
  final void Function(String toName) onReply;

  bool get isReply => parent != null;

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isDeleting = false;
  bool _isExpanded = false;
  Stream<List<CommunityComment>>? _replies;

  CommunityComment get comment => widget.comment;
  CommentsController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (!widget.isReply) _replies = c.watchReplies(comment.id);
  }

  bool get _canEdit => widget.isReply ? c.canEditReply(comment) : c.canEdit(comment);
  bool get _canDelete => widget.isReply ? c.canDeleteReply(comment, parent: widget.parent!) : c.canDelete(comment);

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmCommunityAction(
      context,
      title: widget.isReply ? l10n.deleteReply : l10n.deleteComment,
      body: widget.isReply ? l10n.deleteReplyConfirm : l10n.deleteCommentConfirm,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _isDeleting = true);
    final ok = widget.isReply
        ? await c.deleteReply(comment, parent: widget.parent!)
        : await c.deleteComment(comment);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (!ok) showCommunityError(context, widget.isReply ? l10n.failedToDeleteReply : l10n.failedToDeleteComment);
  }

  Future<void> _edit() async {
    final l10n = AppLocalizations.of(context)!;
    final sheet = EditCommentSheet(
      initialText: comment.text,
      isReply: widget.isReply,
      onSave: (text) async {
        final ok = widget.isReply
            ? await c.editReply(comment, parent: widget.parent!, text: text)
            : await c.editComment(comment, text);
        if (!ok) {
          if (mounted) showCommunityError(context, l10n.failedToSaveChanges);
          throw StateError('Comment could not be saved');
        }
      },
    );
    if (Theme.of(context).platform == TargetPlatform.android) {
      await showDialog<void>(context: context, builder: (_) => sheet);
    } else {
      await showModalBottomSheet<void>(
          context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => sheet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final createdAt = comment.createdAt;
    final timeAgo = createdAt != null ? timeago.format(createdAt, locale: '${languageCode}_short') : '...';
    void openAuthor() => widget.onOpenProfile(comment.authorId, comment.authorRole);

    return Opacity(
      opacity: _isDeleting ? 0.5 : 1.0,
      child: Padding(
        padding: EdgeInsets.only(left: widget.isReply ? 52 : 16, right: 16, top: 8, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  key: const Key('comment-avatar'),
                  onTap: openAuthor,
                  child: ProfileAvatar(radius: 16, imageUrl: comment.authorPhotoUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              comment.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          if (comment.authorRole == 'teacher')
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.assignment_ind, color: AppColors.accentGold, size: 14),
                            ),
                          const SizedBox(width: 6),
                          Text(timeAgo, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                          if (comment.isEdited) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${l10n.edited})',
                              style: TextStyle(
                                color: AppColors.textLight.withOpacity(0.5),
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.text,
                        style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                        maxLines: _isExpanded ? null : 6,
                        overflow: _isExpanded ? null : TextOverflow.ellipsis,
                      ),
                      if (comment.text.length > 300)
                        GestureDetector(
                          onTap: () => setState(() => _isExpanded = !_isExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _isExpanded ? l10n.showLess : l10n.showMore,
                              style: const TextStyle(
                                  color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        key: const Key('comment-reply'),
                        onTap: () => widget.onReply(comment.authorName),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.reply, size: 14, color: AppColors.textLight),
                              const SizedBox(width: 4),
                              Text(l10n.reply,
                                  style: const TextStyle(
                                      color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_canEdit || _canDelete)
                  PopupMenuButton<String>(
                    key: const Key('comment-menu'),
                    icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.textLight),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (v) => v == 'edit' ? _edit() : _delete(),
                    itemBuilder: (_) => [
                      if (_canDelete)
                        PopupMenuItem(
                          key: const Key('comment-delete'),
                          value: 'delete',
                          child: Text(l10n.delete, style: const TextStyle(color: Colors.redAccent)),
                        ),
                      if (_canEdit)
                        PopupMenuItem(key: const Key('comment-edit'), value: 'edit', child: Text(l10n.edit)),
                    ],
                  ),
              ],
            ),
            if (_replies != null)
              StreamBuilder<List<CommunityComment>>(
                stream: _replies,
                builder: (context, snapshot) {
                  final replies = snapshot.data ?? const <CommunityComment>[];
                  if (replies.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      for (final r in replies)
                        CommentTile(
                          key: ValueKey('reply-${r.id}'),
                          comment: r,
                          parent: comment,
                          controller: c,
                          onOpenProfile: widget.onOpenProfile,
                          onReply: widget.onReply,
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
