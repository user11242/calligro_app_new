import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/post_controller.dart';
import '../../application/saved_posts_store.dart';
import '../../domain/models/community_models.dart';
import '../../domain/models/community_post.dart';
import '../community_navigation.dart';
import '../community_scope.dart';
import '../pages/edit_post_page.dart';
import 'comments_bottom_sheet.dart';
import 'community_dialogs.dart';
import 'likers_bottom_sheet.dart';
import 'post_card_parts.dart';
import 'post_image_carousel.dart';

/// One post in a feed or on a profile. All state and rules live in [PostController].
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.session,
    required this.saved,
    this.onOwnProfile,
  });

  final CommunityPost post;

  /// The viewer (loaded once by the screen, not once per card).
  final CommunitySession session;
  final SavedPostsStore saved;
  final OwnProfileCallback? onOwnProfile;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  PostController? _controller;
  CaptionTranslationController? _translation;
  late final AnimationController _likeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 150))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _likeAnim.reverse();
    });
  late final Animation<double> _likeScale =
      Tween<double>(begin: 1, end: 1.3).animate(CurvedAnimation(parent: _likeAnim, curve: Curves.easeOut));

  PostController get c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) _createControllers();
  }

  void _createControllers() {
    final services = CommunityScope.of(context);
    _controller?.dispose();
    _controller = PostController(
      post: widget.post,
      session: widget.session,
      repository: services.repository,
      media: services.media,
    );
    _translation?.dispose();
    _translation = CaptionTranslationController(text: widget.post.caption, translator: services.translator);
  }

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    if (old.session.userId != widget.session.userId || old.session.role != widget.session.role) {
      _createControllers();
    } else if (old.post != widget.post) {
      c.syncPost(widget.post);
      if (old.post.caption != widget.post.caption) {
        _translation!.dispose();
        _translation = CaptionTranslationController(
            text: widget.post.caption, translator: CommunityScope.of(context).translator);
      }
    }
  }

  @override
  void dispose() {
    _likeAnim.dispose();
    _controller?.dispose();
    _translation?.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────
  void _openProfile(String userId, String role) => CommunityNavigation.openProfile(context,
      session: widget.session, userId: userId, role: role, onOwnProfile: widget.onOwnProfile);

  Future<void> _like() async {
    if (!CommunityNavigation.requireAccount(context, widget.session)) return;
    _likeAnim.forward();
    await c.toggleLike();
  }

  Future<void> _save() async {
    if (!CommunityNavigation.requireAccount(context, widget.session)) return;
    if (!await widget.saved.toggle(c.post.id) && mounted) {
      showCommunityError(context, 'Failed to update saved status');
    }
  }

  void _share() {
    final l10n = AppLocalizations.of(context)!;
    final p = c.post;
    var text = '${l10n.postedBy(p.authorName)}\n\n${p.caption}'
        '\n\n${l10n.viewOnCalligro}: https://calligroacademy.com/post/${p.id}';
    if (p.imageUrls.isNotEmpty) text += '\n\n${l10n.checkOutImage} ${p.imageUrls.first}';
    SharePlus.instance.share(ShareParams(text: '$text\n\n${l10n.sentFromCalligro}'));
  }

  Future<void> _onMenu(PostMenuAction action) async {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case PostMenuAction.edit:
        final updated = await Navigator.push<bool>(
            context, MaterialPageRoute(builder: (_) => EditPostPage(post: c.post, session: widget.session)));
        if (updated == true && mounted) showCommunitySuccess(context, l10n.postUpdated);
      case PostMenuAction.delete:
        if (!await confirmCommunityAction(context, title: l10n.deletePost, body: l10n.areYouSure, confirmLabel: l10n.delete)) {
          return;
        }
        if (!await c.delete() && mounted) showCommunityError(context, l10n.failedToDelete(c.lastError ?? ''));
      case PostMenuAction.pin:
        final wasPinned = c.post.isPinned;
        if (await c.togglePinned()) {
          if (mounted) showCommunitySuccess(context, wasPinned ? 'Post unpinned.' : 'Post pinned to top.');
        } else if (mounted) {
          showCommunityError(context, 'Failed to pin post: ${c.lastError}');
        }
      case PostMenuAction.hide:
        final wasHidden = c.post.isHidden;
        if (await c.toggleHidden()) {
          if (mounted) showCommunitySuccess(context, wasHidden ? 'Post is now visible.' : 'Post hidden from community feed.');
        } else if (mounted) {
          showCommunityError(context, 'Failed to update post visibility: ${c.lastError}');
        }
      case PostMenuAction.report:
        if (await c.report() && mounted) showCommunitySuccess(context, l10n.postReportedSuccess);
      case PostMenuAction.block:
        if (!await confirmCommunityAction(context,
            title: l10n.blockUserConfirmTitle, body: l10n.blockUserConfirmBody, confirmLabel: l10n.block)) {
          return;
        }
        if (await c.blockAuthor() && mounted) showCommunitySuccess(context, l10n.userBlockedSuccess);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([c, widget.saved]),
      builder: (context, _) {
        final post = c.post;
        return Container(
          key: Key('post-${post.id}'),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.isPinned) const PinnedBanner(),
                PostHeader(
                  controller: c,
                  onAuthorTap: () => _openProfile(post.authorId, post.authorRole),
                  onMenu: _onMenu,
                ),
                if (post.caption.isNotEmpty) PostCaption(translation: _translation!),
                if (post.imageUrls.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: PostImageCarousel(imageUrls: post.imageUrls)),
                if (post.hasLink)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: PostLinkCard(url: post.linkUrl!.trim(), title: post.linkTitle),
                  ),
                const Divider(height: 1, color: Colors.white10),
                PostActionsBar(
                  controller: c,
                  isSaved: widget.saved.isSaved(post.id),
                  likeScale: _likeScale,
                  onLike: _like,
                  onComments: () => showCommentsSheet(context,
                      post: post, session: widget.session, onOpenProfile: _openProfile),
                  onShare: _share,
                  onSave: _save,
                  onLikers: () => showLikersSheet(context,
                      likerIds: c.likerIds, postAuthorId: post.authorId, session: widget.session, onOpenProfile: _openProfile),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
