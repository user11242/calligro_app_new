import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../domain/models/community_models.dart';
import '../community_navigation.dart';
import '../pages/add_post_page.dart';

/// "Share your masterpiece…" bar at the top of the feed.
class CreatePostBar extends StatelessWidget {
  const CreatePostBar({super.key, required this.session});

  final CommunitySession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      color: AppColors.primary,
      child: InkWell(
        key: const Key('create-post-bar'),
        onTap: () {
          if (CommunityNavigation.requireAccount(context, session)) {
            Navigator.push(context, MaterialPageRoute<bool>(builder: (_) => AddPostPage(session: session)));
          }
        },
        child: Row(
          children: [
            ProfileAvatar(radius: 20, imageUrl: session.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColors.textLight.withOpacity(0.2)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.shareMasterpiece,
                  style: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
