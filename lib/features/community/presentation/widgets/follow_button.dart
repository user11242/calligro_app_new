import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/people_controllers.dart';
import '../../domain/models/community_models.dart';
import '../community_scope.dart';
import 'community_dialogs.dart';

/// Follow / Following button. Hidden for guests and on your own profile.
class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    this.isPrimary = true,
  });

  /// Empty for a guest.
  final String currentUserId;
  final String targetUserId;

  /// true = big filled button, false = small outlined one.
  final bool isPrimary;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  FollowController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= _create();
  }

  @override
  void didUpdateWidget(covariant FollowButton old) {
    super.didUpdateWidget(old);
    if (old.currentUserId != widget.currentUserId || old.targetUserId != widget.targetUserId) {
      _controller?.dispose();
      _controller = _create();
    }
  }

  FollowController _create() => FollowController(
        follows: CommunityScope.of(context).follows,
        session: CommunitySession(userId: widget.currentUserId),
        targetUserId: widget.targetUserId,
      )..start();

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!await _controller!.toggle() && mounted && !_controller!.isBusy) {
      showCommunityError(context, AppLocalizations.of(context)!.failedToSaveChanges);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    if (!c.isVisible) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.isBusy) {
          return SizedBox(
            width: widget.isPrimary ? 80 : 24,
            height: widget.isPrimary ? 36 : 24,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.isPrimary ? AppColors.primary : AppColors.accentGold,
              ),
            ),
          );
        }
        final l10n = AppLocalizations.of(context);
        final label = Text(c.isFollowing ? (l10n?.following ?? 'Following') : (l10n?.follow ?? 'Follow'));
        final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
        const key = Key('follow-button');
        if (widget.isPrimary) {
          return ElevatedButton(
            key: key,
            onPressed: _toggle,
            style: c.isFollowing
                ? ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.accentGold,
                    side: const BorderSide(color: AppColors.accentGold),
                    shape: shape,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  )
                : ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.primary,
                    shape: shape,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
            child: label,
          );
        }
        final color = c.isFollowing ? AppColors.accentGold : AppColors.textLight;
        return OutlinedButton(
          key: key,
          onPressed: _toggle,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: label,
        );
      },
    );
  }
}
