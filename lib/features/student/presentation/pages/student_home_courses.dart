part of 'student_home_page.dart';

/// Split out of student_home_page.dart (unchanged code).
extension _CourseSections on _StudentHomePageState {
  Widget _buildSectionTitle(String title, VoidCallback onSeeAll) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              l10n.seeAll,
              style: const TextStyle(color: AppColors.accentGold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledCoursesList() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 300,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _enrolledCoursesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                l10n.noEnrolledCourses,
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            );
          }
          final courses = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: courses.length > 3 ? 3 : courses.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) =>
                _buildSimpleCourseCard(courses[index], heroPrefix: 'enrolled'),
          );
        },
      ),
    );
  }

  Widget _buildSimpleCourseCard(
    Map<String, dynamic> course, {
    required String heroPrefix,
  }) {
    final String heroTag = '${heroPrefix}_h_${course['id']}';
    final currentUser = (widget.auth ?? FirebaseAuth.instance).currentUser;
    final dynamic studentsRaw = course['enrolledStudents'];
    final List<dynamic> enrolledStudents = (studentsRaw is List)
        ? studentsRaw
        : [];
    final bool isEnrolled =
        currentUser != null && enrolledStudents.contains(currentUser.uid);
    final String banner = course['courseBanner'] ?? '';
    final double price = (course['price'] ?? 0).toDouble();
    final bool isFree = price == 0;
    final String level = _getCourseLevel(
      course['selectedCategory'] ?? 'Beginner',
    );
    final String teacherName = course['teacherName'] ?? 'Teacher';
    final String teacherPhoto = course['teacherProfilePic'] ?? '';
    final int studentCount = enrolledStudents.length;

    return GestureDetector(
      onTap: () {
        if (isEnrolled) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailsPage(
                courseId: course['id'],
                courseData: course,
                heroTag: heroTag,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoursePreviewPage(
                courseId: course['id'],
                courseData: course,
                heroTag: heroTag,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 25,
              spreadRadius: -5,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- Background Image ---
              Hero(
                tag: heroTag,
                child: SmartImage(
                  imageUrl: banner,
                  fit: BoxFit.cover,
                  errorWidget: Image.asset(
                    'assets/courses_backgrounds/normal_writing.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // --- Gradient Overlay ---
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // --- Top Badges & Schedule ---
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Level Badge
                        _buildMiniBadge(
                          level.toUpperCase(),
                          Colors.black.withOpacity(0.5),
                          isGlass: true,
                        ),

                        // Price Badge
                        if (!isEnrolled)
                          _buildMiniBadge(
                            isFree
                                ? AppLocalizations.of(
                                    context,
                                  )!.free.toUpperCase()
                                : "\$$price",
                            AppColors.accentGold,
                            textColor: Colors.black,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Schedule Badge
                    if (course['selectedDays'] != null &&
                        (course['selectedDays'] as List).isNotEmpty)
                      _buildScheduleBadge(course),
                    // The next class was moved: say so on the card too.
                    if (CourseSchedule.fromMap(course, fallbackOffset: DateTime.now().timeZoneOffset)
                            .next(DateTime.now())
                            ?.isRescheduled ??
                        false) ...[
                      const SizedBox(height: 6),
                      const RescheduledTag(compact: true),
                    ],
                  ],
                ),
              ),

              // --- Bottom Info Panel (Ultimate Glass) ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.9),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isEnrolled)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildEnrolledStatusBadge(),
                                ),
                              AutoTranslatedText(
                                    CourseUtils.getLocalizedCourseName(
                                      context,
                                      course,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      height: 1.1,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                  .animate()
                                  .fadeIn(delay: 200.ms)
                                  .slideX(begin: -0.1),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Teacher Avatar
                                  ProfileAvatar(
                                    radius: 14,
                                    imageUrl: teacherPhoto,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      teacherName,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Student Count
                                  if (studentCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.people_outline,
                                            color: AppColors.accentGold,
                                            size: 10,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            NumberFormat.decimalPattern(
                                              Localizations.localeOf(
                                                context,
                                              ).toString(),
                                            ).format(studentCount),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ).animate().fadeIn(delay: 400.ms),
                            ],
                          ),
                        ).animate().shimmer(
                          delay: 2000.ms,
                          duration: 1500.ms,
                          color: Colors.white.withOpacity(0.1),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(
      duration: 400.ms,
      curve: Curves.easeOutBack,
      begin: const Offset(0.9, 0.9),
    );
  }

  Widget _buildEnrolledStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.greenAccent[700]!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent[700]!.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent[400],
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context)!.enrolled.toUpperCase(),
            style: TextStyle(
              color: Colors.greenAccent[400],
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBadge(Map<String, dynamic> course) {
    final List<dynamic> days = course['selectedDays'] ?? [];
    if (days.isEmpty) return const SizedBox.shrink();

    final String locale = Localizations.localeOf(context).languageCode;
    String timeStr = "";
    if (course['startTime'] != null) {
      DateTime? startTime;
      if (course['startTime'] is Timestamp) {
        startTime = (course['startTime'] as Timestamp).toDate().toLocal();
      } else if (course['startTime'] is DateTime) {
        startTime = (course['startTime'] as DateTime).toLocal();
      }
      if (startTime != null) {
        timeStr = DateFormat.Hm(locale).format(startTime);
      }
    }

    final List<String> localizedDays = days
        .map((d) => _getLocalizedDayShort(context, d.toString()))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.accentGold,
                size: 12,
              ),
              const SizedBox(width: 6),
              Text(
                "${localizedDays.join(', ')}${timeStr.isNotEmpty ? ' • $timeStr' : ''}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
    );
  }

  String _getLocalizedDayShort(BuildContext context, String day) {
    final l10n = AppLocalizations.of(context)!;
    final d = day.toLowerCase();
    String translated = day;

    if (d.contains('sun')) {
      translated = l10n.sunday;
    } else if (d.contains('mon')) {
      translated = l10n.monday;
    } else if (d.contains('tue')) {
      translated = l10n.tuesday;
    } else if (d.contains('wed')) {
      translated = l10n.wednesday;
    } else if (d.contains('thu')) {
      translated = l10n.thursday;
    } else if (d.contains('fri')) {
      translated = l10n.friday;
    } else if (d.contains('sat')) {
      translated = l10n.saturday;
    }

    // For Arabic, "الأحد" can be shortened to "أحد" by removing "ال"
    if (Localizations.localeOf(context).languageCode == 'ar' &&
        translated.startsWith('ال')) {
      return translated.substring(2);
    }
    return translated;
  }

  Widget _buildMiniBadge(
    String text,
    Color color, {
    bool isGlass = false,
    Color textColor = Colors.white,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isGlass ? AppColors.primary.withOpacity(0.85) : color,
            borderRadius: BorderRadius.circular(10),
            border: isGlass
                ? Border.all(color: Colors.white.withOpacity(0.15))
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
    );
  }

  String _getCourseLevel(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('beginner')) return AppLocalizations.of(context)!.beginner;
    if (cat.contains('intermediate'))
      return AppLocalizations.of(context)!.intermediate;
    if (cat.contains('advanced')) return AppLocalizations.of(context)!.advanced;
    return category;
  }

  Widget _buildExploreCoursesList() {
    return SizedBox(
      height: 300,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _featuredCoursesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                "No courses found",
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            );
          }

          final currentUser = (widget.auth ?? FirebaseAuth.instance).currentUser;
          final courses = snapshot.data!.where((course) {
            final dynamic studentsRaw = course['enrolledStudents'];
            final List<dynamic> enrolledStudents = (studentsRaw is List)
                ? studentsRaw
                : [];
            final bool isEnrolled =
                currentUser != null &&
                enrolledStudents.contains(currentUser.uid);

            if (course['startDate'] != null) {
              DateTime? start;
              if (course['startDate'] is Timestamp) {
                start = (course['startDate'] as Timestamp).toDate();
              } else if (course['startDate'] is DateTime) {
                start = course['startDate'];
              }

              if (start != null) {
                final now = DateTime.now();
                // Hide started courses from non-enrolled students
                if (now.isAfter(start) && !isEnrolled) {
                  return false;
                }
              }
            }
            return true;
          }).toList();

          if (courses.isEmpty) {
            return Center(
              child: Text(
                "No courses found",
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: courses.length > 3 ? 3 : courses.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) =>
                _buildSimpleCourseCard(courses[index], heroPrefix: 'featured'),
          );
        },
      ),
    );
  }

  // --- Helper Methods ---
}
