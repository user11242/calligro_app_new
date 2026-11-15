import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/people_controllers.dart';
import '../../application/saved_posts_store.dart';
import '../../domain/models/community_models.dart';
import '../community_navigation.dart';
import '../widgets/post_card.dart';

/// "See all" for a profile section. Shares the section's live controller.
class ProfilePostsPage extends StatelessWidget {
  const ProfilePostsPage({
    super.key,
    required this.title,
    required this.controller,
    required this.session,
    required this.saved,
    this.onOwnProfile,
  });

  final String title;
  final ProfilePostsController controller;
  final CommunitySession session;
  final SavedPostsStore saved;
  final OwnProfileCallback? onOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          final posts = controller.posts;
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_view, size: 60, color: Colors.white10),
                  const SizedBox(height: 10),
                  Text(AppLocalizations.of(context)!.nothingToShow, style: const TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, i) => PostCard(
              key: ValueKey('card-${posts[i].id}'),
              post: posts[i],
              session: session,
              saved: saved,
              onOwnProfile: onOwnProfile,
            ),
          );
        },
      ),
    );
  }
}
