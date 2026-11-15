import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/core/widgets/profile_image_viewer.dart';
import 'package:calligro_app/core/widgets/rating_display.dart';
import 'package:calligro_app/features/community/presentation/widgets/follow_button.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/profile_controllers.dart';
import '../../domain/profile_models.dart';

/// Avatar, counters, name + badges, teacher details, bio and follow button.
/// What appears is decided by [ProfileController] (ProfilePolicy), not here.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.controller,
    required this.onOpenFollowList,
  });

  final ProfileController controller;
  final void Function(FollowListKind kind) onOpenFollowList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = controller;
    final p = c.profile!;
    final heroTag = c.isOwn && !c.publicView ? 'profile_me_${p.id}' : 'profile_${p.id}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                key: const Key('profile-avatar'),
                radius: 40,
                imageUrl: p.photoUrl,
                heroTag: heroTag,
                onTap: p.photoUrl.isEmpty ? null : () => showProfileImageDialog(context, p.photoUrl, heroTag),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(key: const Key('stat-posts'), label: l10n.posts, value: c.counts.posts),
                    _Stat(
                      key: const Key('stat-followers'),
                      label: l10n.followers,
                      value: p.followerCount,
                      onTap: () => onOpenFollowList(FollowListKind.followers),
                    ),
                    _Stat(
                      key: const Key('stat-following'),
                      label: l10n.following,
                      value: p.followingCount,
                      onTap: () => onOpenFollowList(FollowListKind.following),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                p.name.isNotEmpty ? p.name : (p.isTeacher ? l10n.user : l10n.student),
                key: const Key('profile-name'),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (p.isAdmin && !c.isOwn)
                const Icon(Icons.verified, key: Key('admin-verified'), color: AppColors.accentGold, size: 18),
              if (p.isTeacher && p.countryFlag.isNotEmpty) Text(p.countryFlag, style: const TextStyle(fontSize: 18)),
              _RoleBadge(profile: p),
              if (c.showCommission) _CommissionBadge(rate: p.commissionRate),
            ],
          ),
          if (p.isTeacher) ...[
            const SizedBox(height: 12),
            RatingDisplay(averageRating: p.averageRating, reviewCount: p.reviewCount, isCompact: false),
            if (p.spokenLanguages.isNotEmpty) ...[
              const SizedBox(height: 16),
              SpokenLanguages(languages: p.spokenLanguages),
            ],
          ],
          if (p.bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              p.bio,
              key: const Key('profile-bio'),
              softWrap: true,
              maxLines: c.isOwn && !p.isTeacher && !p.isAdmin ? 4 : null,
              overflow: c.isOwn && !p.isTeacher && !p.isAdmin ? TextOverflow.ellipsis : null,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
            ),
          ],
          if (c.showEmail && p.email.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(p.email, key: const Key('profile-email'), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          ],
          if (c.showFollow) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: FollowButton(currentUserId: c.viewer.userId, targetUserId: p.id)),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.label, required this.value, this.onTap});
  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.label, required this.color, this.icon, this.filled = true});
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(filled ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: filled ? color : Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, color: color, size: 14), const SizedBox(width: 5)],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (profile.isTeacher) {
      return _Badge(key: const Key('badge-teacher'), label: l10n.teacher, color: AppColors.accentGold, icon: Icons.assignment_ind);
    }
    if (profile.isAdmin) {
      return _Badge(
          key: const Key('badge-admin'), label: l10n.adminRole.toUpperCase(), color: AppColors.accentGold, icon: Icons.security);
    }
    return _Badge(key: const Key('badge-student'), label: l10n.studentBadge, color: Colors.white70, filled: false);
  }
}

class _CommissionBadge extends StatelessWidget {
  const _CommissionBadge({required this.rate});
  final double? rate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final r = rate;
    return r != null
        ? _Badge(
            key: const Key('badge-commission'),
            label: '${l10n.commissionLabel}: ${(r * 100).toStringAsFixed(0)}%',
            color: Colors.blueAccent,
            icon: Icons.percent,
          )
        : _Badge(
            key: const Key('badge-commission-pending'),
            label: l10n.waitingForAdminCommission,
            color: Colors.orange,
            icon: Icons.hourglass_empty,
          );
  }
}

/// Spoken-language chips (teacher profiles).
class SpokenLanguages extends StatelessWidget {
  const SpokenLanguages({super.key, required this.languages});
  final List<String> languages;

  static const _native = {
    'Arabic': 'العربية',
    'Turkish': 'Türkçe',
    'Bengali': 'বাংলা',
    'Urdu': 'اردو',
    'Farsi': 'فارسی',
    'Kurdish': 'کوردي',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.accentGold.withAlpha(25), shape: BoxShape.circle),
              child: const Icon(Icons.translate_rounded, size: 14, color: AppColors.accentGold),
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.spokenLanguages.toUpperCase(),
              style: TextStyle(
                  color: AppColors.accentGold.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final lang in languages)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withAlpha(25), Colors.white.withAlpha(10)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accentGold, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text(_native[lang] ?? lang,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
