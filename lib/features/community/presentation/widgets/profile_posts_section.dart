import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/people_controllers.dart';
import '../../application/saved_posts_store.dart';
import '../../domain/models/community_models.dart';
import '../community_navigation.dart';
import '../community_scope.dart';
import '../community_session_gate.dart';
import '../pages/profile_posts_page.dart';
import 'post_card.dart';

/// Which posts a profile section shows.
enum ProfilePostsKind { byUser, liked, saved }

/// First 3 posts on a profile tab, with "See all".
class ProfilePostsSection extends StatelessWidget {
  const ProfilePostsSection({
    super.key,
    required this.title,
    required this.kind,
    this.userId,
    this.onOwnProfile,
  }) : assert(kind != ProfilePostsKind.byUser || userId != null, 'byUser needs a userId');

  /// A user's posts.
  const ProfilePostsSection.byUser({super.key, required this.title, required String this.userId, this.onOwnProfile})
      : kind = ProfilePostsKind.byUser;

  /// The viewer's liked posts.
  const ProfilePostsSection.liked({super.key, required this.title, this.onOwnProfile})
      : kind = ProfilePostsKind.liked,
        userId = null;

  /// The viewer's saved posts.
  const ProfilePostsSection.saved({super.key, required this.title, this.onOwnProfile})
      : kind = ProfilePostsKind.saved,
        userId = null;

  final String title;
  final ProfilePostsKind kind;
  final String? userId;
  final OwnProfileCallback? onOwnProfile;

  static const previewCount = 3;

  @override
  Widget build(BuildContext context) {
    return CommunitySessionGate(
      loading: const _Spinner(),
      builder: (context, session, saved) => _Section(
        key: ValueKey('$kind-$userId-${session.userId}'),
        section: this,
        session: session,
        saved: saved,
      ),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({super.key, required this.section, required this.session, required this.saved});

  final ProfilePostsSection section;
  final CommunitySession session;
  final SavedPostsStore saved;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  ProfilePostsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final repo = CommunityScope.of(context).repository;
    final session = widget.session;
    _controller = switch (widget.section.kind) {
      ProfilePostsKind.byUser =>
        ProfilePostsController.byUser(widget.section.userId!, repository: repo, session: session),
      ProfilePostsKind.liked => ProfilePostsController.liked(repository: repo, session: session),
      ProfilePostsKind.saved => ProfilePostsController.saved(repository: repo, session: session),
    }
      ..start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _seeAll() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfilePostsPage(
          title: widget.section.title,
          controller: _controller!,
          session: widget.session,
          saved: widget.saved,
          onOwnProfile: widget.section.onOwnProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.isLoading) return const _Spinner();
        final posts = c.posts;
        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.grid_view, size: 40, color: Colors.white10),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.nothingToShow, style: const TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          );
        }
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            const SizedBox(height: 32),
            for (final post in posts.take(ProfilePostsSection.previewCount))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PostCard(
                  key: ValueKey('card-${post.id}'),
                  post: post,
                  session: widget.session,
                  saved: widget.saved,
                  onOwnProfile: widget.section.onOwnProfile,
                ),
              ),
            if (posts.length > ProfilePostsSection.previewCount)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: TextButton(
                  key: const Key('see-all'),
                  onPressed: _seeAll,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)!.seeAll,
                          style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.accentGold),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accentGold)),
      );
}
