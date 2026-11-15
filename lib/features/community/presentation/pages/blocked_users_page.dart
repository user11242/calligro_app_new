import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/people_controllers.dart';
import '../../domain/models/community_models.dart';
import '../community_scope.dart';
import '../community_session_gate.dart';
import '../widgets/community_dialogs.dart';

/// Settings → Blocked users.
class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.blockedUsersTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: CommunitySessionGate(
        builder: (context, session, _) => session.isGuest
            ? const Center(child: Text('Not logged in', style: TextStyle(color: Colors.white)))
            : _BlockedList(session: session),
      ),
    );
  }
}

class _BlockedList extends StatefulWidget {
  const _BlockedList({required this.session});
  final CommunitySession session;

  @override
  State<_BlockedList> createState() => _BlockedListState();
}

class _BlockedListState extends State<_BlockedList> {
  BlockedUsersController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = CommunityScope.of(context);
    _controller ??=
        BlockedUsersController(repository: services.repository, users: services.users, session: widget.session)
          ..start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _unblock(String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _controller!.unblock(userId);
    if (!mounted) return;
    ok ? showCommunitySuccess(context, l10n.userUnblockedSuccess) : showCommunityError(context, l10n.failedToUnblockUser);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
        if (c.users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 64, color: AppColors.textLight.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(l10n.noBlockedUsers, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: c.users.length,
          itemBuilder: (context, i) {
            final user = c.users[i];
            return Container(
              key: Key('blocked-${user.id}'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  ProfileAvatar(radius: 20, imageUrl: user.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.name.isEmpty ? 'Unknown User' : user.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  OutlinedButton(
                    key: Key('unblock-${user.id}'),
                    onPressed: () => _unblock(user.id),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentGold),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(l10n.unblockUser, style: const TextStyle(color: AppColors.accentGold, fontSize: 13)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
