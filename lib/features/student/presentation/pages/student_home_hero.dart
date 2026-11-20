part of 'student_home_page.dart';

/// Split out of student_home_page.dart (unchanged code).
extension _HeroSections on _StudentHomePageState {
  Widget _buildDynamicHeroSection(AppLocalizations l10n) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _enrolledCoursesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildAmbientVideoLoop(l10n),
          );
        }

        final now = DateTime.now();
        // Filter out ended courses
        final activeCourses = snapshot.data!.where((course) {
          final endDateData = course['endDate'];
          if (endDateData == null) return true; // Assume ongoing if no end date

          DateTime endDate;
          if (endDateData is Timestamp) {
            endDate = endDateData.toDate();
          } else if (endDateData is DateTime) {
            endDate = endDateData;
          } else {
            return true;
          }

          // Course is active if end date is in the future
          return endDate.isAfter(now);
        }).toList();

        // Next class (moves included) from the one schedule rule; "now" while one is live.
        DateTime? getNextSession(Map<String, dynamic> course) {
          final schedule = CourseSchedule.fromMap(course, fallbackOffset: now.timeZoneOffset);
          if (schedule.live(now) != null) return now;
          return schedule.next(now)?.start.toLocal();
        }

        // --- NEW: Sort courses by closeness to next session ---
        activeCourses.sort((a, b) {
          final nextA = getNextSession(a);
          final nextB = getNextSession(b);

          // If both have no predictable session, they tie
          if (nextA == null && nextB == null) return 0;
          // Null means it has no next session scheduled, push to the end
          if (nextA == null) return 1;
          if (nextB == null) return -1;

          // Compare dates (closer date comes first)
          return nextA.compareTo(nextB);
        });

        if (activeCourses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AmbientVideoPlayer(
              key: const ValueKey("hero_video_loop"),
              videoPath: 'assets/videos/numbers.m4v',
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height:
                  380, // Accommodates countdown timer, rescheduled banner, and localized text without overflow
              child: PageView.builder(
                controller: _heroPageController,
                itemCount: activeCourses.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSessionCountdownCard(activeCourses[index]),
                  );
                },
              ),
            ),
            if (activeCourses.length > 1) ...[
              const SizedBox(height: 12),
              _buildPageIndicator(activeCourses.length),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPageIndicator(int count) {
    return ListenableBuilder(
      listenable: _heroPageController,
      builder: (context, child) {
        int currentPage = 0;
        try {
          currentPage = _heroPageController.page?.round() ?? 0;
        } catch (_) {}

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: currentPage == index ? 18 : 6,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? AppColors.accentGold
                    : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSessionCountdownCard(Map<String, dynamic> course) {
    final banner = course['courseBanner'] ?? '';
    final l10n = AppLocalizations.of(context)!;
    // The next class, moves included: a moved one gets the tag and its new day/time.
    final nextClass = CourseSchedule.fromMap(course, fallbackOffset: DateTime.now().timeZoneOffset).next(DateTime.now());
    final moved = nextClass != null && nextClass.isRescheduled;

    // Local state for the button enable/disable
    final ValueNotifier<bool> isButtonEnabled = ValueNotifier<bool>(false);

    return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accentGold.withOpacity(0.1)),
            image: DecorationImage(
              image: banner.startsWith('assets')
                  ? AssetImage(banner) as ImageProvider
                  : CachedNetworkImageProvider(banner),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.7), // Darkened overlay as requested
                BlendMode.darken,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.nextSession.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.accentGold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    if (moved)
                      const RescheduledTag(compact: true)
                    else
                      const Icon(
                        Icons.auto_awesome,
                        color: AppColors.accentGold,
                        size: 20,
                      ),
                  ],
                ),
                if (moved) ...[
                  const SizedBox(height: 8),
                  Text(
                    formatSessionTime(context, nextClass.start, nextClass.end),
                    key: const Key('hero-moved-time'),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                ] else
                  const SizedBox(height: 14),
                AutoTranslatedText(
                  CourseUtils.getLocalizedCourseName(context, course),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: AppColors.accentGold.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accentGold.withOpacity(
                                      0.5,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: ProfileAvatar(
                                  radius: 14,
                                  imageUrl:
                                      (course['teacherPhoto'] ??
                                              course['teacherProfilePic'])
                                          ?.toString() ??
                                      '',
                                  placeholderIcon: Icons.person,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                course['teacherName'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.verified,
                                color: AppColors.accentGold.withOpacity(0.8),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: moved ? 12 : 16),
                _CountdownTimer(
                  course: course,
                  // Same window as the course page's join bar: 10 minutes before a
                  // class until 30 minutes after it ends (a moved class at its new time).
                  onTimerUpdate: (_) {
                    // JoinLock: the admins' remote switch (OFF = always enabled).
                    isButtonEnabled.value = JoinLock.homeButtonEnabled(
                        CourseSchedule.fromMap(course, fallbackOffset: DateTime.now().timeZoneOffset).joinCheck(DateTime.now()));
                  },
                ),
                SizedBox(height: moved ? 14 : 18),
                ValueListenableBuilder<bool>(
                  valueListenable: isButtonEnabled,
                  builder: (context, enabled, child) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: enabled
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CourseDetailsPage(
                                      courseId: course['id'],
                                      courseData: course,
                                      heroTag: 'hero_join_${course['id']}',
                                    ),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.videocam),
                        label: Text(
                          enabled ? l10n.joinClassNow : l10n.classNotStarted,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: enabled
                              ? AppColors.accentGold
                              : Colors.white.withOpacity(0.05),
                          foregroundColor: enabled
                              ? Colors.black
                              : Colors.white.withOpacity(0.3),
                          disabledBackgroundColor: Colors.white.withOpacity(
                            0.02,
                          ),
                          disabledForegroundColor: Colors.white.withOpacity(
                            0.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: enabled
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.05),
                            ),
                          ),
                          elevation: enabled ? 8 : 0,
                          shadowColor: AppColors.accentGold.withOpacity(0.3),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 400.ms)
        .slideY(begin: 0.1, curve: Curves.easeOut)
        .scaleXY(begin: 0.95, curve: Curves.easeOut);
  }


  Widget _buildAmbientVideoLoop(AppLocalizations l10n) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Video Player
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AmbientVideoPlayer(
              key: const ValueKey("hero_video_loop"),
              videoPath: 'assets/videos/numbers.m4v',
            ),
          ),

          // 2. Dark Overlay for Text Readability
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.95),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 3. Motivational Text & Action
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.heroTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  l10n.heroSubtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                      onPressed: () {
                        // Scroll to "Explore Courses"
                        widget.onGoToCourses?.call(null);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 12,
                        shadowColor: AppColors.accentGold.withOpacity(0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.heroButton,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 22),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 1100.ms)
                    .scale(begin: const Offset(0.95, 0.95)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1);
  }
}
