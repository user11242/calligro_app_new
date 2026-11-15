import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/comments_controller.dart';
import '../../domain/models/community_models.dart';
import '../../domain/models/community_post.dart';
import '../community_navigation.dart';
import '../community_scope.dart';
import 'add_comment_bar.dart';
import 'comment_tile.dart';
import 'community_dialogs.dart';

/// Opens the comments sheet for [post] (70% of the screen, max 85% with the keyboard).
Future<void> showCommentsSheet(
  BuildContext context, {
  required CommunityPost post,
  required CommunitySession session,
  required void Function(String userId, String role) onOpenProfile,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
      final screenHeight = MediaQuery.of(sheetContext).size.height;
      var height = screenHeight * 0.7;
      if (height + bottomInset > screenHeight * 0.85) height = screenHeight * 0.85 - bottomInset;
      if (height < 200) height = 200;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: height,
          child: CommentsBottomSheet(
            postId: post.id,
            postAuthorId: post.authorId,
            session: session,
            onOpenProfile: (userId, role) {
              Navigator.of(sheetContext).pop();
              onOpenProfile(userId, role);
            },
          ),
        ),
      );
    },
  );
}

class CommentsBottomSheet extends StatefulWidget {
  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.session,
    required this.onOpenProfile,
  });

  final String postId;
  final String postAuthorId;
  final CommunitySession session;
  final void Function(String userId, String role) onOpenProfile;

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  CommentsController? _controller;
  CommentsController get c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= CommentsController(
      repository: CommunityScope.of(context).repository,
      session: widget.session,
      postId: widget.postId,
      postAuthorId: widget.postAuthorId,
    )..start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _reply(CommunityComment root, String toName) {
    if (!c.replyTo(root, toName: toName)) CommunityNavigation.requireAccount(context, widget.session);
  }

  Future<bool> _send(String text) async {
    final replying = c.replyingToName != null;
    final result = await c.send(text);
    if (result == SendResult.failed && mounted) {
      final l10n = AppLocalizations.of(context)!;
      showCommunityError(context, replying ? l10n.failedToPostReply : l10n.failedToPostComment);
    }
    return result == SendResult.sent;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(l10n.comments,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Divider(color: AppColors.textLight.withOpacity(0.2), height: 1),
            Expanded(child: _list(l10n)),
            Divider(color: AppColors.textLight.withOpacity(0.2), height: 1),
            if (c.canWrite)
              AddCommentBar(
                replyToUserName: c.replyingToName,
                isSending: c.isSending,
                onCancelReply: c.cancelReply,
                onSend: _send,
              )
            else
              _GuestPrompt(onTap: () => CommunityNavigation.requireAccount(context, widget.session)),
          ],
        ),
      ),
    );
  }

  Widget _list(AppLocalizations l10n) {
    if (c.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
    }
    if (c.comments.isEmpty) {
      return Center(
        key: const Key('no-comments'),
        child: Text(l10n.noCommentsYet, style: TextStyle(color: AppColors.textLight.withOpacity(0.7))),
      );
    }
    return ListView.separated(
      itemCount: c.comments.length,
      itemBuilder: (context, i) {
        final comment = c.comments[i];
        return CommentTile(
          key: ValueKey('comment-${comment.id}'),
          comment: comment,
          controller: c,
          onOpenProfile: widget.onOpenProfile,
          onReply: (name) => _reply(comment, name),
        );
      },
      separatorBuilder: (_, _) => Divider(color: AppColors.textLight.withOpacity(0.1), height: 1, indent: 72),
    );
  }
}

class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const Key('login-to-interact'),
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(AppLocalizations.of(context)!.loginToInteract.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
