import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/people_controllers.dart';
import '../../domain/models/community_models.dart';
import '../community_scope.dart';
import 'follow_button.dart';

/// Opens "who liked this" (60% high, grows to 90% while searching).
Future<void> showLikersSheet(
  BuildContext context, {
  required Set<String> likerIds,
  required String postAuthorId,
  required CommunitySession session,
  required void Function(String userId, String role) onOpenProfile,
}) {
  final sheetController = DraggableScrollableController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => LikersBottomSheet(
        sheetController: sheetController,
        scrollController: scrollController,
        likerIds: likerIds,
        postAuthorId: postAuthorId,
        session: session,
        onOpenProfile: (userId, role) {
          Navigator.of(sheetContext).pop();
          onOpenProfile(userId, role);
        },
      ),
    ),
  ).whenComplete(sheetController.dispose);
}

class LikersBottomSheet extends StatefulWidget {
  const LikersBottomSheet({
    super.key,
    required this.likerIds,
    required this.postAuthorId,
    required this.session,
    required this.onOpenProfile,
    this.sheetController,
    this.scrollController,
  });

  final Set<String> likerIds;
  final String postAuthorId;
  final CommunitySession session;
  final void Function(String userId, String role) onOpenProfile;
  final DraggableScrollableController? sheetController;
  final ScrollController? scrollController;

  @override
  State<LikersBottomSheet> createState() => _LikersBottomSheetState();
}

class _LikersBottomSheetState extends State<LikersBottomSheet> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  LikersController? _controller;
  LikersController get c => _controller!;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= LikersController(users: CommunityScope.of(context).users, session: widget.session)
      ..load(widget.likerIds);
  }

  @override
  void dispose() {
    _search.dispose();
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final sheet = widget.sheetController;
    if (sheet == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !sheet.isAttached) return;
      sheet.animateTo(_focus.hasFocus ? 0.9 : 0.6,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // A Material (not a painted Container) so the list tiles' tap ripple shows.
    return Material(
      color: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      clipBehavior: Clip.antiAlias,
      child: Column(
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
          Text(l10n.likes,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                key: const Key('likers-search'),
                controller: _search,
                focusNode: _focus,
                onChanged: (v) => c.filter = v,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.searchLikes,
                  hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
                  icon: Icon(Icons.search, color: AppColors.textLight.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Divider(color: AppColors.textLight.withOpacity(0.2), height: 1),
          Expanded(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                if (c.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
                }
                final users = c.visible;
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _search.text.isEmpty ? l10n.noLikesYet : l10n.noUsersFound,
                      style: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
                    ),
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  itemCount: users.length,
                  itemBuilder: (context, i) => _LikerTile(
                    user: users[i],
                    session: widget.session,
                    isPostAuthor: users[i].id == widget.postAuthorId,
                    onTap: () => widget.onOpenProfile(users[i].id, users[i].role),
                  ),
                  separatorBuilder: (_, _) =>
                      Divider(color: AppColors.textLight.withOpacity(0.1), height: 1, indent: 72),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  const _LikerTile({required this.user, required this.session, required this.isPostAuthor, required this.onTap});

  final CommunityUser user;
  final CommunitySession session;
  final bool isPostAuthor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMe = user.id == session.userId;
    final tag = isMe
        ? Text(l10n.youLabel,
            style: TextStyle(color: AppColors.textLight.withOpacity(0.7), fontWeight: FontWeight.normal, fontSize: 14))
        : isPostAuthor
            ? Text(l10n.authorLabel,
                style: TextStyle(
                    color: AppColors.accentGold.withOpacity(0.8), fontWeight: FontWeight.normal, fontSize: 14))
            : null;
    return ListTile(
      key: Key('liker-${user.id}'),
      leading: ProfileAvatar(radius: 20, imageUrl: user.photoUrl),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.name.isEmpty ? l10n.user : user.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          if (tag != null) ...[const SizedBox(width: 6), tag],
          if (user.isTeacher)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.assignment_ind, color: AppColors.accentGold, size: 16),
            ),
        ],
      ),
      trailing: isMe ? null : FollowButton(currentUserId: session.userId, targetUserId: user.id, isPrimary: false),
      onTap: onTap,
    );
  }
}
