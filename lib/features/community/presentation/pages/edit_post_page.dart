import 'package:flutter/material.dart';

import '../../domain/models/community_models.dart';
import '../../domain/models/community_post.dart';
import 'post_editor_page.dart';

/// "Edit post" screen (author only). Pops `true` when the changes were saved.
class EditPostPage extends StatelessWidget {
  const EditPostPage({super.key, required this.post, required this.session});

  final CommunityPost post;
  final CommunitySession session;

  @override
  Widget build(BuildContext context) => PostEditorPage(session: session, post: post);
}
