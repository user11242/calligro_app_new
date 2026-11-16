part of 'student_home_page.dart';

/// Split out of student_home_page.dart (unchanged code).
extension _HeaderSections on _StudentHomePageState {
  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context)!;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  Widget _buildPersonalizedHeader(
    AppLocalizations l10n,
    StudentUserModel student,
  ) {
    return Row(
      children: [
        // --- Hamburger Menu ---
        _buildHeaderIconButton(
          Icons.menu,
          () => _scaffoldKey.currentState?.openDrawer(),
        ).animate().fadeIn(delay: 200.ms).scale(),

        const SizedBox(width: 16),

        // --- Greeting & Name ---
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(context),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn(delay: 400.ms).slideX(),
              const SizedBox(height: 4),
              Text(
                widget.isGuestMode ? l10n.guest : student.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 600.ms).slideX(),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // --- Profile Image (Added back) ---
        GestureDetector(
          onTap: () {
            if (widget.onProfileTap != null) {
              widget.onProfileTap!();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentGold.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18, // Slightly smaller to fit with other icons
              backgroundColor: AppColors.cardBackground,
              backgroundImage:
                  (!widget.isGuestMode && student.photoUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(student.photoUrl)
                  : null,
              child: (widget.isGuestMode || student.photoUrl.isEmpty)
                  ? const Icon(
                      Icons.person,
                      color: AppColors.accentGold,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ).animate().fadeIn(delay: 700.ms).scale(),

        const SizedBox(width: 12),

        // --- Notifications with unread badge ---
        NotificationBellButton(
          isGuest: widget.isGuestMode,
          auth: widget.auth,
          firestore: widget.firestore,
        ).animate().fadeIn(delay: 800.ms).scale(),
      ],
    );
  }

  Widget _buildHeaderIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentGold, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2);
  }

  Widget _buildStatsRow(StudentUserModel student) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _enrolledCoursesStream,
      builder: (context, snapshot) {
        final courseCount = snapshot.data?.length ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildStatItem(
                Icons.auto_stories_rounded,
                courseCount.toString(),
                AppLocalizations.of(context)!.courses,
              ),
              const SizedBox(width: 16),
              // Replaced Certificates with Following
              _buildStatItem(
                Icons.people_outline,
                student.followingCount.toString(),
                AppLocalizations.of(context)!.following,
              ),
            ],
          ),
        );
      },
    );
  }
}
