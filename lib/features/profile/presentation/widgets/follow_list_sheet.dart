import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/features/community/presentation/widgets/follow_button.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/profile_controllers.dart';
import '../../domain/profile_models.dart';
import '../profile_scope.dart';

/// Opens a followers / following list (60% high, 90% while searching).
/// [onTap] gets the tapped person after the sheet has closed.
Future<void> showFollowListSheet(
  BuildContext context, {
  required String userId,
  required FollowListKind kind,
  required String title,
  required ProfileViewer viewer,
  required void Function(FollowListEntry person) onTap,
}) {
  final sheetController = DraggableScrollableController();
  FollowListEntry? tapped;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: 0.6,
      minChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => FollowListSheet(
        userId: userId,
        kind: kind,
        title: title,
        viewer: viewer,
        sheetController: sheetController,
        scrollController: scrollController,
        onTap: (person) {
          tapped = person;
          Navigator.of(sheetContext).pop();
        },
      ),
    ),
  ).whenComplete(() {
    sheetController.dispose();
    if (tapped != null) onTap(tapped!);
  });
}

class FollowListSheet extends StatefulWidget {
  const FollowListSheet({
    super.key,
    required this.userId,
    required this.kind,
    required this.title,
    required this.viewer,
    required this.onTap,
    this.sheetController,
    this.scrollController,
  });

  final String userId;
  final FollowListKind kind;
  final String title;
  final ProfileViewer viewer;
  final void Function(FollowListEntry person) onTap;
  final DraggableScrollableController? sheetController;
  final ScrollController? scrollController;

  @override
  State<FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<FollowListSheet> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  FollowListController? _controller;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      final sheet = widget.sheetController;
      if (sheet == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !sheet.isAttached) return;
        sheet.animateTo(_focus.hasFocus ? 0.9 : 0.6, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= FollowListController(
      userId: widget.userId,
      kind: widget.kind,
      viewer: widget.viewer,
      repository: ProfileScope.of(context).followLists,
    )..load();
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = _controller!;
    // A Material (not a painted Container) so the tiles' tap ripple shows.
    return Material(
      color: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: AppColors.textLight.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
          ),
          Text(widget.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                key: const Key('follow-list-search'),
                controller: _search,
                focusNode: _focus,
                onChanged: (v) => c.filter = v,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '${l10n?.searchUsers ?? 'Search'} ${widget.title}...',
                  hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
                  icon: Icon(Icons.search, color: AppColors.textLight.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Divider(color: AppColors.textLight.withOpacity(0.2), height: 1),
          Expanded(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                if (c.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
                final people = c.visible;
                if (people.isEmpty) {
                  return Center(
                    child: Text(
                      _search.text.isEmpty ? (l10n?.nothingToShow ?? 'Nothing to show') : (l10n?.noUsersFound ?? 'No users found'),
                      style: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
                    ),
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  itemCount: people.length,
                  itemBuilder: (context, i) => _PersonTile(
                    person: people[i],
                    viewer: widget.viewer,
                    onTap: () => widget.onTap(people[i]),
                  ),
                  separatorBuilder: (_, _) => Divider(color: AppColors.textLight.withOpacity(0.1), height: 1, indent: 72),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.viewer, required this.onTap});
  final FollowListEntry person;
  final ProfileViewer viewer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMe = person.id == viewer.userId;
    return ListTile(
      key: Key('person-${person.id}'),
      leading: ProfileAvatar(radius: 20, imageUrl: person.photoUrl),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              person.name.isEmpty ? (l10n?.user ?? 'User') : person.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            Text(l10n?.youLabel ?? '(You)', style: TextStyle(color: AppColors.textLight.withOpacity(0.7), fontSize: 14)),
          ],
          if (person.isTeacher)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.assignment_ind, color: AppColors.accentGold, size: 16),
            ),
        ],
      ),
      trailing: isMe ? null : FollowButton(currentUserId: viewer.userId, targetUserId: person.id, isPrimary: false),
      onTap: onTap,
    );
  }
}
