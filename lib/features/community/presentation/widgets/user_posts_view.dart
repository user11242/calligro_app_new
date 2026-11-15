import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/people_controllers.dart';
import '../../application/saved_posts_store.dart';
import '../../domain/models/community_models.dart';
import '../community_navigation.dart';
import '../community_scope.dart';
import '../community_session_gate.dart';
import 'post_card.dart';

/// A public profile's posts, live. [builder] gets the visible post count and the
/// ready-made post list, and places them (a header + list, or a tab).
class UserPostsView extends StatelessWidget {
  const UserPostsView({super.key, required this.userId, required this.builder, this.onOwnProfile});

  final String userId;
  final Widget Function(BuildContext context, int postCount, Widget postList) builder;
  final OwnProfileCallback? onOwnProfile;

  @override
  Widget build(BuildContext context) {
    return CommunitySessionGate(
      loading: builder(context, 0, const Center(child: CircularProgressIndicator(color: AppColors.accentGold))),
      builder: (context, session, saved) => _UserPosts(
        key: ValueKey('$userId-${session.userId}'),
        view: this,
        session: session,
        saved: saved,
      ),
    );
  }
}

class _UserPosts extends StatefulWidget {
  const _UserPosts({super.key, required this.view, required this.session, required this.saved});

  final UserPostsView view;
  final CommunitySession session;
  final SavedPostsStore saved;

  @override
  State<_UserPosts> createState() => _UserPostsState();
}

class _UserPostsState extends State<_UserPosts> {
  ProfilePostsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ProfilePostsController.byUser(widget.view.userId,
        repository: CommunityScope.of(context).repository, session: widget.session)
      ..start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final posts = c.posts;
        final Widget list = c.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
            : posts.isEmpty
                ? Center(
                    key: const Key('no-posts'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grid_view, size: 60, color: Colors.white10),
                        const SizedBox(height: 10),
                        Text(AppLocalizations.of(context)!.noPostsYet, style: const TextStyle(color: Colors.white38)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 40),
                    itemCount: posts.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: PostCard(
                        key: ValueKey('card-${posts[i].id}'),
                        post: posts[i],
                        session: widget.session,
                        saved: widget.saved,
                        onOwnProfile: widget.view.onOwnProfile,
                      ),
                    ),
                  );
        return widget.view.builder(context, posts.length, list);
      },
    );
  }
}
