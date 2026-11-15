import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/saved_posts_store.dart';
import '../../application/single_post_controller.dart';
import '../../domain/models/community_models.dart';
import '../community_navigation.dart';
import '../community_scope.dart';
import '../community_session_gate.dart';
import '../widgets/post_card.dart';

/// One post opened from a link or notification.
class SinglePostPage extends StatelessWidget {
  const SinglePostPage({super.key, required this.postId, this.onProfileTap});

  final String postId;
  final OwnProfileCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.post),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CommunitySessionGate(
        builder: (context, session, saved) =>
            _SinglePost(postId: postId, session: session, saved: saved, onOwnProfile: onProfileTap),
      ),
    );
  }
}

class _SinglePost extends StatefulWidget {
  const _SinglePost({required this.postId, required this.session, required this.saved, this.onOwnProfile});

  final String postId;
  final CommunitySession session;
  final SavedPostsStore saved;
  final OwnProfileCallback? onOwnProfile;

  @override
  State<_SinglePost> createState() => _SinglePostState();
}

class _SinglePostState extends State<_SinglePost> {
  SinglePostController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = CommunityScope.of(context);
    _controller ??= SinglePostController(
      repository: services.repository,
      users: services.users,
      session: widget.session,
      postId: widget.postId,
    )..start();
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
        if (c.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
        final post = c.post;
        if (post == null) {
          return Center(
            key: const Key('post-not-found'),
            child: Text(AppLocalizations.of(context)!.nothingToShow, style: const TextStyle(color: AppColors.textLight)),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: PostCard(post: post, session: widget.session, saved: widget.saved, onOwnProfile: widget.onOwnProfile),
        );
      },
    );
  }
}
