import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../application/saved_posts_store.dart';
import '../domain/models/community_models.dart';
import 'community_scope.dart';

/// Loads the viewer once for a whole screen and owns the shared bookmark state,
/// so cards never read the user document themselves.
class CommunitySessionGate extends StatefulWidget {
  const CommunitySessionGate({super.key, required this.builder, this.loading});

  final Widget Function(BuildContext context, CommunitySession session, SavedPostsStore saved) builder;

  /// Shown while the viewer loads (defaults to a spinner on the app background).
  final Widget? loading;

  @override
  State<CommunitySessionGate> createState() => _CommunitySessionGateState();
}

class _CommunitySessionGateState extends State<CommunitySessionGate> {
  CommunitySession? _session;
  SavedPostsStore? _saved;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final services = CommunityScope.of(context);
    CommunitySession session;
    try {
      session = await services.sessions.currentSession();
    } catch (e) {
      debugPrint('Community session could not be loaded: $e');
      session = CommunitySession.guest;
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _saved = SavedPostsStore(repository: services.repository, userId: session.userId)..start();
    });
  }

  @override
  void dispose() {
    _saved?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return widget.loading ??
          const ColoredBox(
            color: AppColors.primary,
            child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
          );
    }
    return widget.builder(context, session, _saved!);
  }
}

/// Localized tab name for a feed filter.
String communityFilterLabel(AppLocalizations l10n, CommunityFilter filter) => switch (filter) {
      CommunityFilter.all => l10n.all,
      CommunityFilter.popular => l10n.popular,
      CommunityFilter.friends => l10n.friends,
      CommunityFilter.teachers => l10n.teachers,
      CommunityFilter.myPosts => l10n.myPosts,
      CommunityFilter.saved => l10n.saved,
    };
