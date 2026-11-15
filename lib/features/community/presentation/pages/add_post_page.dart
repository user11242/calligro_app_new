import 'package:flutter/material.dart';

import '../../domain/models/community_models.dart';
import 'post_editor_page.dart';

/// "New post" screen. Pops `true` when the post was published.
class AddPostPage extends StatelessWidget {
  const AddPostPage({super.key, required this.session});

  final CommunitySession session;

  @override
  Widget build(BuildContext context) => PostEditorPage(session: session);
}
