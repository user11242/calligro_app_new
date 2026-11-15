import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/post_controller.dart';
import '../../domain/models/community_post.dart';

enum PostMenuAction { pin, hide, edit, delete, report, block }

/// "PINNED POST" banner.
class PinnedBanner extends StatelessWidget {
  const PinnedBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withValues(alpha: 0.12),
          border: Border(bottom: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.25))),
        ),
        child: const Row(
          children: [
            Icon(Icons.push_pin, size: 13, color: AppColors.accentGold),
            SizedBox(width: 8),
            Text('PINNED POST',
                style: TextStyle(color: AppColors.accentGold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          ],
        ),
      );
}

/// Avatar, name + role badge, time / edited / pinned, and the ⋮ menu.
class PostHeader extends StatelessWidget {
  const PostHeader({
    super.key,
    required this.controller,
    required this.onAuthorTap,
    required this.onMenu,
  });

  final PostController controller;
  final VoidCallback onAuthorTap;
  final ValueChanged<PostMenuAction> onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final post = controller.post;
    final created = post.createdAt;
    final timeAgo = created != null
        ? timeago.format(created, locale: '${Localizations.localeOf(context).languageCode}_short')
        : l10n.justNow;
    final light = AppColors.textLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          InkWell(
            key: const Key('post-author'),
            onTap: onAuthorTap,
            child: Row(
              children: [
                ProfileAvatar(radius: 20, imageUrl: post.authorPhotoUrl),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(post.authorName,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        if (post.authorRole == 'teacher')
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.assignment_ind, key: Key('teacher-badge'), color: AppColors.accentGold, size: 18),
                          ),
                        if (post.authorRole == 'admin')
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified, key: Key('admin-badge'), color: AppColors.accentGold, size: 18),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(timeAgo, style: TextStyle(color: light.withValues(alpha: 0.7), fontSize: 12)),
                        if (post.isEdited) ...[
                          const SizedBox(width: 4),
                          Text('(${l10n.edited})',
                              style: TextStyle(color: light.withValues(alpha: 0.5), fontSize: 10, fontStyle: FontStyle.italic)),
                        ],
                        if (post.isPinned) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.push_pin, color: AppColors.accentGold, size: 14),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          if (controller.isDeleting)
            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold))
          else if (_items(controller).isNotEmpty)
            PopupMenuButton<PostMenuAction>(
              key: const Key('post-menu'),
              icon: const Icon(Icons.more_vert, color: AppColors.textLight),
              color: AppColors.cardBackground,
              onSelected: onMenu,
              itemBuilder: (_) => [for (final a in _items(controller)) _menuItem(context, a, post)],
            ),
        ],
      ),
    );
  }

  /// Which actions this viewer gets (decided by CommunityPolicy via the controller).
  static List<PostMenuAction> _items(PostController c) => [
        if (c.canPinOrHide) ...[PostMenuAction.pin, PostMenuAction.hide],
        if (c.canEdit) PostMenuAction.edit,
        if (c.canDelete) PostMenuAction.delete,
        if (c.canReportOrBlock) ...[PostMenuAction.report, PostMenuAction.block],
      ];

  PopupMenuItem<PostMenuAction> _menuItem(BuildContext context, PostMenuAction a, CommunityPost post) {
    final l10n = AppLocalizations.of(context)!;
    final (IconData icon, Color color, String label) = switch (a) {
      PostMenuAction.pin => (post.isPinned ? Icons.push_pin_outlined : Icons.push_pin, AppColors.accentGold, post.isPinned ? 'Unpin Post' : 'Pin Post'),
      PostMenuAction.hide => (
          post.isHidden ? Icons.visibility : Icons.visibility_off,
          post.isHidden ? Colors.greenAccent : Colors.orangeAccent,
          post.isHidden ? 'Unhide Post' : 'Hide Post'
        ),
      PostMenuAction.edit => (Icons.edit, AppColors.accentGold, l10n.edit),
      PostMenuAction.delete => (Icons.delete, Colors.redAccent, l10n.delete),
      PostMenuAction.report => (Icons.report, Colors.orange, l10n.reportPost),
      PostMenuAction.block => (Icons.block, Colors.redAccent, l10n.blockUser),
    };
    final textColor = switch (a) {
      PostMenuAction.pin || PostMenuAction.edit => AppColors.textPrimary,
      PostMenuAction.report => Colors.white,
      _ => color,
    };
    return PopupMenuItem(
      key: Key('menu-${a.name}'),
      value: a,
      child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(label, style: TextStyle(color: textColor))]),
    );
  }
}

/// Caption with "see more / show less" and "Translate / Show original".
class PostCaption extends StatefulWidget {
  const PostCaption({super.key, required this.translation});
  final CaptionTranslationController translation;

  @override
  State<PostCaption> createState() => _PostCaptionState();
}

class _PostCaptionState extends State<PostCaption> {
  static const _collapsedLines = 3;
  static const _style = TextStyle(color: AppColors.textLight, fontSize: 15);
  bool _expanded = false;

  bool _overflows(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style),
      maxLines: _collapsedLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: MediaQuery.sizeOf(context).width - 24);
    return painter.didExceedMaxLines;
  }

  Future<void> _onTranslateTap(TapDownDetails details) async {
    final t = widget.translation;
    if (t.isShowingTranslation) return t.showOriginal();
    final options = await t.targetLanguages();
    if (!mounted) return;
    const names = {'en': 'English', 'ar': 'العربية', 'tr': 'Türkçe'};
    final o = details.globalPosition;
    final lang = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(o.dx, o.dy, o.dx, o.dy),
      color: AppColors.cardBackground,
      items: [
        for (final l in options)
          PopupMenuItem(value: l, child: Text(names[l]!, style: const TextStyle(color: AppColors.textPrimary))),
      ],
    );
    if (lang != null) await t.translateTo(lang);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.translation,
      builder: (context, _) {
        final t = widget.translation;
        final overflow = _overflows(t.text);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.displayText,
                key: const Key('post-caption'),
                style: _style,
                maxLines: _expanded ? null : _collapsedLines,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (t.isTranslating)
                const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))
              else
                GestureDetector(
                  key: const Key('translate'),
                  onTapDown: _onTranslateTap,
                  child: Text(t.isShowingTranslation ? l10n.showOriginal : l10n.translate,
                      style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              if (overflow)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? l10n.showLess : l10n.seeMore, style: const TextStyle(color: AppColors.accentGold)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Admin-attached external link.
class PostLinkCard extends StatelessWidget {
  const PostLinkCard({super.key, required this.url, this.title});
  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final parsed = Uri.tryParse(url);
    final uri = parsed == null ? null : (parsed.hasScheme ? parsed : Uri.tryParse('https://$url'));
    final domain = (uri?.host.isNotEmpty ?? false) ? uri!.host : url;
    final display = (title?.trim().isNotEmpty ?? false) ? title!.trim() : domain;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: uri == null
            ? null
            : () => launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object _) => false),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.accentGold.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.link, color: AppColors.accentGold, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.6), fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, color: AppColors.accentGold, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Like · comment · share · save … and the "who liked" stack.
class PostActionsBar extends StatelessWidget {
  const PostActionsBar({
    super.key,
    required this.controller,
    required this.isSaved,
    required this.likeScale,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.onSave,
    required this.onLikers,
  });

  final PostController controller;
  final bool isSaved;
  final Animation<double> likeScale;
  final VoidCallback onLike, onComments, onShare, onSave, onLikers;

  @override
  Widget build(BuildContext context) {
    final liked = controller.isLiked;
    final likeColor = liked ? AppColors.accentGold : AppColors.textLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            key: const Key('like'),
            onTap: onLike,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                ScaleTransition(
                  scale: likeScale,
                  child: Icon(liked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, size: 20, color: likeColor),
                ),
                const SizedBox(width: 6),
                Text('${controller.likesCount}',
                    key: const Key('likes-count'),
                    style: TextStyle(color: likeColor, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          InkWell(
            key: const Key('comments'),
            onTap: onComments,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.textLight),
                const SizedBox(width: 6),
                Text('${controller.post.commentsCount}',
                    key: const Key('comments-count'), style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          InkWell(
            key: const Key('share'),
            onTap: onShare,
            borderRadius: BorderRadius.circular(4),
            child: const Icon(Icons.share_outlined, size: 20, color: AppColors.textLight),
          ),
          const SizedBox(width: 24),
          InkWell(
            key: const Key('save'),
            onTap: onSave,
            borderRadius: BorderRadius.circular(4),
            child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                size: 20, color: isSaved ? AppColors.accentGold : AppColors.textLight),
          ),
          const Spacer(),
          if (controller.likesCount > 0)
            InkWell(key: const Key('likers'), onTap: onLikers, child: const _ReactionStack())
          else
            const SizedBox(width: 50, height: 24), // keeps the row height stable
        ],
      ),
    );
  }
}

class _ReactionStack extends StatelessWidget {
  const _ReactionStack();

  Widget _bubble(Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(color: AppColors.cardBackground, shape: BoxShape.circle),
        child: CircleAvatar(radius: 10, backgroundColor: color, child: Icon(icon, size: 12, color: Colors.white)),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        height: 24,
        child: Stack(children: [
          Positioned(right: 0, child: _bubble(Colors.redAccent, Icons.favorite)),
          Positioned(right: 18, child: _bubble(Colors.blue, Icons.thumb_up)),
        ]),
      );
}
