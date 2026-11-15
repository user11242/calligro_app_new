import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/feed_controller.dart';
import '../../application/saved_posts_store.dart';
import '../../domain/models/community_models.dart';
import '../../domain/models/community_post.dart';
import '../community_navigation.dart';
import '../community_scope.dart';
import '../community_session_gate.dart';
import '../widgets/create_post_bar.dart';
import '../widgets/post_card.dart';
import 'add_post_page.dart';
import 'search_users_page.dart';

/// The community feed tab.
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key, this.onProfileTap});

  /// Opens the dashboard's own profile tab when the viewer taps themself.
  final OwnProfileCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return CommunitySessionGate(
      loading: const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
      ),
      builder: (context, session, saved) =>
          _CommunityFeed(key: ValueKey(session.userId), session: session, saved: saved, onOwnProfile: onProfileTap),
    );
  }
}

class _CommunityFeed extends StatefulWidget {
  const _CommunityFeed({super.key, required this.session, required this.saved, this.onOwnProfile});

  final CommunitySession session;
  final SavedPostsStore saved;
  final OwnProfileCallback? onOwnProfile;

  @override
  State<_CommunityFeed> createState() => _CommunityFeedState();
}

class _CommunityFeedState extends State<_CommunityFeed> {
  final _scroll = ScrollController();
  bool _isAtTop = true;
  CommunityFeedController? _controller;
  CommunityFeedController get c => _controller!;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final atTop = _scroll.offset <= 10;
      if (atTop != _isAtTop) setState(() => _isAtTop = atTop);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final services = CommunityScope.of(context);
    _controller = CommunityFeedController(
      repository: services.repository,
      follows: services.follows,
      users: services.users,
      session: widget.session,
    )..start();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _selectFilter(CommunityFilter f) async {
    if (await c.setFilter(f) == FilterResult.needsAccount && mounted) {
      CommunityNavigation.requireAccount(context, widget.session);
    }
  }

  Future<void> _refresh() async {
    await c.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  void _openProfile(String userId, String role) => CommunityNavigation.openProfile(context,
      session: widget.session, userId: userId, role: role, onOwnProfile: widget.onOwnProfile);

  void _openSearch() {
    if (!CommunityNavigation.requireAccount(context, widget.session)) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SearchUsersPage(session: widget.session, onOpenProfile: _openProfile),
      ),
    );
  }

  void _addPost() {
    if (!CommunityNavigation.requireAccount(context, widget.session)) return;
    Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => AddPostPage(session: widget.session)));
  }

  Widget _card(CommunityPost post) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PostCard(
          key: ValueKey('card-${post.id}'),
          post: post,
          session: widget.session,
          saved: widget.saved,
          onOwnProfile: widget.onOwnProfile,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.accentGold,
        backgroundColor: AppColors.cardBackground,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final pinned = c.pinned;
            return CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _appBar(l10n),
                SliverToBoxAdapter(child: CreatePostBar(session: widget.session)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      children: [
                        for (final f in CommunityFeedController.tabs)
                          _FilterChip(
                            key: Key('filter-${f.name}'),
                            label: communityFilterLabel(l10n, f),
                            selected: c.filter == f,
                            onTap: () => _selectFilter(f),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (pinned.isNotEmpty) SliverList.list(children: [for (final p in pinned) _card(p)]),
                ..._feed(l10n),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _feed(AppLocalizations l10n) {
    if (c.isLoading) {
      return const [
        SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.accentGold))),
      ];
    }
    if (c.hasError) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text(l10n.errorLoadingPosts, style: TextStyle(color: Colors.redAccent.shade100)),
          ),
        ),
      ];
    }
    final posts = c.posts;
    if (posts.isEmpty) {
      // Everything was pinned: the pinned section above already shows it.
      if (c.pinned.isNotEmpty && c.filter == CommunityFilter.all) return const [];
      return [
        SliverFillRemaining(
          child: Center(
            key: const Key('feed-empty'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_off, size: 48, color: AppColors.textLight.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  l10n.noPostsFoundForFilter(communityFilterLabel(l10n, c.filter)),
                  style: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [SliverList.builder(itemCount: posts.length, itemBuilder: (_, i) => _card(posts[i]))];
  }

  SliverAppBar _appBar(AppLocalizations l10n) {
    return SliverAppBar(
      backgroundColor: AppColors.primary,
      floating: true,
      snap: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: _isAtTop
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  key: const ValueKey('TitleCommunity'),
                  child: Text(l10n.community,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22)),
                )
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  key: const ValueKey('TitleBrand'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/app_icon.png', height: 28, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      const Text('CALLIGRO',
                          style: TextStyle(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: IconButton(
            key: const Key('feed-search'),
            icon: const Icon(Icons.search, color: AppColors.textLight),
            onPressed: _openSearch,
          ),
        ),
        _CollapsingAction(
          visible: !_isAtTop,
          child: PopupMenuButton<CommunityFilter>(
            icon: const Icon(Icons.filter_list, color: AppColors.textLight),
            color: AppColors.cardBackground,
            onSelected: _selectFilter,
            itemBuilder: (_) => [
              for (final f in CommunityFeedController.tabs)
                PopupMenuItem(
                  value: f,
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 16, color: c.filter == f ? AppColors.accentGold : Colors.transparent),
                      const SizedBox(width: 8),
                      Text(communityFilterLabel(l10n, f),
                          style: TextStyle(color: c.filter == f ? AppColors.accentGold : Colors.white)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _CollapsingAction(
          visible: !_isAtTop,
          child: IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.accentGold),
            onPressed: _addPost,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentGold : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? AppColors.accentGold : Colors.white.withOpacity(0.15)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// App-bar action that slides in once the feed is scrolled.
class _CollapsingAction extends StatelessWidget {
  const _CollapsingAction({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: visible ? 48 : 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: ClipRect(child: OverflowBox(minWidth: 0, maxWidth: 48, alignment: Alignment.center, child: child)),
      ),
    );
  }
}
