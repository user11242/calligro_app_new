import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/community/presentation/widgets/profile_posts_section.dart';
import 'package:calligro_app/features/community/presentation/widgets/user_posts_view.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/profile_controllers.dart';
import '../../domain/profile_models.dart';
import '../../domain/profile_policy.dart';
import '../profile_navigation.dart';
import '../widgets/follow_list_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/teacher_tabs.dart';

/// Header + tabs of any profile (own tab or public page), driven by [ProfileController].
class ProfileBody extends StatelessWidget {
  const ProfileBody({super.key, required this.controller, this.topBar, this.onOwnProfile, this.onLeaveForOwnProfile});

  final ProfileController controller;

  /// "Profile" title + settings on the own-profile tab.
  final Widget? topBar;
  final OwnProfileCallback? onOwnProfile;

  /// On a public page: close it before switching to the viewer's own profile tab.
  final VoidCallback? onLeaveForOwnProfile;

  void _openFollowList(BuildContext context, FollowListKind kind) {
    final l10n = AppLocalizations.of(context)!;
    final c = controller;
    showFollowListSheet(
      context,
      userId: c.profileId,
      kind: kind,
      title: kind == FollowListKind.followers ? l10n.followers : l10n.following,
      viewer: c.viewer,
      onTap: (person) {
        switch (ProfilePolicy.followListTap(viewer: c.viewer, shownProfileId: c.profileId, tappedId: person.id)) {
          case FollowListTapResult.closeOnly:
            break;
          case FollowListTapResult.openOwnProfile:
            if (c.isOwn && !c.publicView) break; // already there
            onLeaveForOwnProfile?.call();
            onOwnProfile?.call(person.id, person.role);
          case FollowListTapResult.openTheirProfile:
            ProfileNavigation.open(context,
                viewer: c.viewer, userId: person.id, role: person.role, onOwnProfile: onOwnProfile);
        }
      },
    );
  }

  String _label(AppLocalizations l10n, ProfileTab t) => switch (t) {
        ProfileTab.courses => l10n.courses,
        ProfileTab.reviews => l10n.reviews,
        ProfileTab.posts => l10n.posts,
        ProfileTab.myPosts => l10n.myPosts,
        ProfileTab.saved => l10n.saved,
        ProfileTab.liked => l10n.liked,
      };

  String _count(ProfileTab t) {
    final n = controller.counts;
    return switch (t) {
      ProfileTab.courses => '${n.courses}',
      ProfileTab.reviews => '★',
      ProfileTab.posts || ProfileTab.myPosts => '${n.posts}',
      ProfileTab.saved => '${n.saved}',
      ProfileTab.liked => '${n.liked}',
    };
  }

  Widget _content(BuildContext context, ProfileTab t) {
    final l10n = AppLocalizations.of(context)!;
    final c = controller;
    Widget scroll(Widget child) => SingleChildScrollView(child: child);
    return switch (t) {
      ProfileTab.courses => TeacherCoursesTab(teacherId: c.profileId, viewer: c.viewer),
      ProfileTab.reviews => TeacherReviewsTab(teacherId: c.profileId),
      ProfileTab.posts =>
        UserPostsView(userId: c.profileId, onOwnProfile: onOwnProfile, builder: (_, _, list) => list),
      ProfileTab.myPosts => scroll(ProfilePostsSection.byUser(title: l10n.myPosts, userId: c.profileId)),
      ProfileTab.saved => scroll(ProfilePostsSection.saved(title: l10n.saved)),
      ProfileTab.liked => scroll(ProfilePostsSection.liked(title: l10n.liked)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        if (c.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
        if (c.notFound) {
          return Center(
            key: const Key('profile-not-found'),
            child: Text(l10n.userNotFound, style: const TextStyle(color: Colors.white)),
          );
        }
        final tabs = c.tabs;
        final header = ProfileHeader(controller: c, onOpenFollowList: (k) => _openFollowList(context, k));
        final single = tabs.length == 1;
        return DefaultTabController(
          key: ValueKey(tabs.join()),
          length: tabs.length,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              if (topBar != null) SliverToBoxAdapter(child: topBar),
              SliverToBoxAdapter(child: header),
              if (single)
                SliverToBoxAdapter(child: _SectionTitle(title: _label(l10n, tabs.single), count: c.counts.posts))
              else
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      key: const Key('profile-tabs'),
                      isScrollable: tabs.length > 2,
                      tabAlignment: tabs.length > 2 ? TabAlignment.center : null,
                      indicatorColor: AppColors.accentGold,
                      labelColor: AppColors.accentGold,
                      unselectedLabelColor: AppColors.textLight,
                      tabs: [
                        for (final t in tabs) Tab(key: Key('tab-${t.name}'), text: '${_label(l10n, t)} (${_count(t)})'),
                      ],
                    ),
                  ),
                ),
            ],
            body: single
                ? _content(context, tabs.single)
                : TabBarView(children: [for (final t in tabs) _content(context, t)]),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Colors.white10),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.grid_view, color: AppColors.accentGold, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(AppLocalizations.of(context)!.postsCount(count),
                  style: TextStyle(color: AppColors.textLight.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: AppColors.primary, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar;
}
