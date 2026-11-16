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

        // --- NEW: Calculate Next Session Helper ---
        DateTime? getNextSession(Map<String, dynamic> course) {
          final startTimeData = course['startTime'];
          final selectedDays = List<String>.from(course['selectedDays'] ?? []);

          if (startTimeData == null || selectedDays.isEmpty) return null;

          DateTime startTime;
          if (startTimeData is Timestamp) {
            startTime = startTimeData.toDate().toLocal();
          } else if (startTimeData is DateTime) {
            startTime = startTimeData.toLocal();
          } else {
            return null;
          }

          // Check if course hasn't started yet
          final startDateData = course['startDate'];
          DateTime? startDate;
          if (startDateData is Timestamp) {
            startDate = startDateData.toDate().toLocal();
          } else if (startDateData is DateTime) {
            startDate = startDateData.toLocal();
          }

          if (startDate != null && startDate.isAfter(now)) {
            return startDate;
          }

          final dayFormat = DateFormat('EEEE', 'en_US');

          for (int i = -1; i < 7; i++) {
            final checkDate = now.add(Duration(days: i));
            final dayName = dayFormat.format(checkDate);

            if (selectedDays.contains(dayName)) {
              final localStartTime = startTime.toLocal();
              final sessionTime = DateTime(
                checkDate.year,
                checkDate.month,
                checkDate.day,
                localStartTime.hour,
                localStartTime.minute,
              );

              Duration sessionDuration = const Duration(minutes: 90);
              if (course['endTime'] != null) {
                DateTime? endDateTime;
                if (course['endTime'] is Timestamp) {
                  endDateTime = (course['endTime'] as Timestamp).toDate();
                } else if (course['endTime'] is DateTime)
                  endDateTime = course['endTime'];

                DateTime? originalStartDateTime;
                if (course['startTime'] is Timestamp) {
                  originalStartDateTime = (course['startTime'] as Timestamp)
                      .toDate();
                } else if (course['startTime'] is DateTime)
                  originalStartDateTime = course['startTime'];

                if (endDateTime != null && originalStartDateTime != null) {
                  sessionDuration = endDateTime.difference(
                    originalStartDateTime,
                  );
                  if (sessionDuration.inMinutes <= 0)
                    sessionDuration = const Duration(minutes: 90);
                }
              }

              final sessionEndTime = sessionTime.add(sessionDuration);

              // If it's live right now, treat it as the most urgent (next session is essentially 'now')
              if (now.isAfter(sessionTime) && now.isBefore(sessionEndTime)) {
                return now;
              }

              if (sessionTime.isAfter(now)) {
                return sessionTime;
              }
            }
          }
          return null;
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
                  360, // Increased to accommodate Arabic text without overflow
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
    final meetLink =
        course['calligroMeetLink'] ??
        course['googleMeetLink'] ??
        ''; // Support both
    final l10n = AppLocalizations.of(context)!;

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
            padding: const EdgeInsets.all(20),
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
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.accentGold,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 20),
                _CountdownTimer(
                  course: course,
                  onTimerUpdate: (remaining) {
                    isButtonEnabled.value = remaining <= Duration.zero;
                  },
                ),
                const SizedBox(height: 20),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

  Future<void> _launchClass(String? url) async {
    if (url == null || url.isEmpty) return;

    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    try {
      final Uri uri = Uri.parse(cleanUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not launch meeting link")),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch meeting link: $e")),
        );
      }
    }
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
