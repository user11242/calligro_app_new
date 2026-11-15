import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/people_controllers.dart';
import '../../domain/models/community_models.dart';
import '../community_scope.dart';
import '../widgets/follow_button.dart';

/// Find people by name (debounced). Tapping a result opens their profile.
class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key, required this.session, required this.onOpenProfile});

  final CommunitySession session;
  final void Function(String userId, String role) onOpenProfile;

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  UserSearchController? _controller;
  UserSearchController get c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= UserSearchController(users: CommunityScope.of(context).users);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          key: const Key('user-search'),
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
          cursorColor: AppColors.accentGold,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchByName,
            hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.7), fontSize: 18),
            border: InputBorder.none,
          ),
          onChanged: (q) {
            setState(() {}); // show / hide the clear button
            c.onQueryChanged(q);
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textLight),
              onPressed: () {
                _searchController.clear();
                c.query = '';
                c.searchNow();
                setState(() {});
              },
            ),
        ],
      ),
      body: ListenableBuilder(listenable: c, builder: (context, _) => _buildBody()),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (c.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
    }
    if (c.query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: AppColors.textLight.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(l10n.searchTeachersStudents, style: TextStyle(color: AppColors.textLight.withOpacity(0.7))),
          ],
        ),
      );
    }
    if (c.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: AppColors.textLight.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(l10n.noUsersFound, style: TextStyle(color: AppColors.textLight.withOpacity(0.7))),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: c.results.length,
      itemBuilder: (context, index) {
        final user = c.results[index];
        return _UserSearchTile(
          user: user,
          session: widget.session,
          onTap: () => widget.onOpenProfile(user.id, user.role),
        );
      },
      separatorBuilder: (context, index) =>
          Divider(color: AppColors.textLight.withOpacity(0.1), height: 1, indent: 16, endIndent: 16),
    );
  }
}

class _UserSearchTile extends StatelessWidget {
  const _UserSearchTile({required this.user, required this.session, required this.onTap});

  final CommunityUser user;
  final CommunitySession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String userId = user.id;
    final String userName = user.name.isEmpty ? 'User' : user.name;
    final String userImageUrl = user.photoUrl;
    final String userRole = user.role;
    final bool isCurrentUser = userId == session.userId;

    List<Widget> titleWidgets = [
      Flexible(
        child: Text(
          userName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    if (isCurrentUser) {
      titleWidgets.add(const SizedBox(width: 6.0));
      titleWidgets.add(
        Text(
          AppLocalizations.of(context)!.youLabel,
          style: TextStyle(
            color: AppColors.textLight.withOpacity(0.7),
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
        ),
      );
    }

    if (userRole == 'teacher') {
      titleWidgets.add(
        const Padding(
          padding: EdgeInsets.only(left: 6.0),
          child: Icon(Icons.assignment_ind, color: AppColors.accentGold, size: 16.0),
        ),
      );
    } else if (userRole == 'admin') {
      titleWidgets.add(
        const Padding(
          padding: EdgeInsets.only(left: 6.0),
          child: Icon(Icons.verified, color: AppColors.accentGold, size: 16.0),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: (userImageUrl.isNotEmpty)
            ? CachedNetworkImageProvider(userImageUrl)
            : null,
        backgroundColor: AppColors.goldGradientEnd,
        child: (userImageUrl.isEmpty)
            ? const Icon(Icons.person, color: AppColors.primary)
            : null,
      ),
      title: Row(children: titleWidgets),
      subtitle: Text(
        userRole == 'teacher'
            ? AppLocalizations.of(context)!.teacherRole
            : (userRole == 'admin' ? AppLocalizations.of(context)!.administrator : AppLocalizations.of(context)!.studentRole),
        style: TextStyle(
          color: AppColors.textLight.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
      trailing: isCurrentUser
          ? null
          : FollowButton(
              currentUserId: session.userId,
              targetUserId: userId,
              isPrimary: false,
            ),
      key: Key('search-result-$userId'),
      onTap: onTap,
    );
  }
}
