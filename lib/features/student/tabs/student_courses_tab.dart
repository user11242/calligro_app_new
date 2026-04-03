import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../pages/course_preview_page.dart';
import '../../teacher/pages/course_details/course_details_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Added Import
import '../../../core/widgets/auto_translated_text.dart';
import 'package:calligro_app/core/utils/guest_guard.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import '../../rating/widgets/course_completion_rating_dialog.dart';

class StudentCoursesTab extends StatefulWidget {
  final String? initialFilter;
  final int navigationTrigger;
  const StudentCoursesTab({
    super.key,
    this.initialFilter,
    this.navigationTrigger = 0,
  });

  @override
  State<StudentCoursesTab> createState() => _StudentCoursesTabState();
}

class _StudentCoursesTabState extends State<StudentCoursesTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  String _selectedFilter = ""; // Initialized in didChangeDependencies
  late Stream<QuerySnapshot> _coursesStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _coursesStream = FirebaseFirestore.instance
        .collection('courses')
        .snapshots()
        .handleError((e) {
          debugPrint('Error fetching courses: $e');
        });
  }

  // The categories for our "Smart Filter" system
  List<String> _getFilters(AppLocalizations l10n) => [
    l10n.all,
    l10n.myCourses,
    l10n.thuluth,
    l10n.naskh,
    l10n.diwani,
    l10n.kufi,
    l10n.ruqah,
    l10n.beginner,
    l10n.advanced,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedFilter.isEmpty) {
      _selectedFilter = widget.initialFilter ?? AppLocalizations.of(context)!.all;
    }
  }

  @override
  void didUpdateWidget(covariant StudentCoursesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationTrigger != oldWidget.navigationTrigger) {
      setState(() {
        _selectedFilter = widget.initialFilter ?? AppLocalizations.of(context)!.all;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- HEADER SECTION (Search & Filter) ---
            _buildHeader(),

            // --- COURSE LIST SECTION ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _coursesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState(AppLocalizations.of(context)!.noCoursesFound);
                  }

                  // --- FILTRATION LOGIC ---
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final String normalizedQuery = CourseUtils.prepareForSearch(_searchText);

                  final courses = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // 1. Construct Search Corpus for this course
                    final String rawName = data['courseName'] ?? "";
                    final String localizedTitle = CourseUtils.getLocalizedCourseName(context, data);
                    final String teacher = data['teacherName'] ?? "";
                    final String description = data['description'] ?? "";
                    final String style = data['calligraphyStyle'] ?? "";
                    final String level = data['selectedCategory'] ?? ""; // 'Beginner', etc.

                    // Check enrollment status
                    final dynamic studentsRaw = data['enrolledStudents'];
                    final List<dynamic> enrolledStudents = (studentsRaw is List) ? studentsRaw : [];
                    final bool isEnrolled = currentUser != null && enrolledStudents.contains(currentUser.uid);

                    // SEARCH MATCHING: Combines multiple fields and normalizes them
                    bool matchesSearch = true;
                    if (normalizedQuery.isNotEmpty) {
                      final String searchCorpus = CourseUtils.prepareForSearch(
                        "$rawName $localizedTitle $teacher $description $style"
                      );
                      matchesSearch = searchCorpus.contains(normalizedQuery);
                    }

                    // 2. Chip Filter Match
                    bool matchesFilter = true;
                    final l10n = AppLocalizations.of(context)!;
                    if (_selectedFilter != l10n.all) {
                      if (_selectedFilter == l10n.myCourses) {
                        // Show only enrolled courses
                        matchesFilter = isEnrolled;
                      } else if (_selectedFilter == l10n.beginner ||
                          _selectedFilter == l10n.advanced) {
                        // Filter by Level
                        matchesFilter = level == (_selectedFilter == l10n.beginner ? "Beginner" : "Advanced");
                      } else {
                        // Filter by Style (Thuluth, etc.)
                        String selectedStyle = "All";
                        if (_selectedFilter == l10n.thuluth) {
                          selectedStyle = "Thuluth";
                        } else if (_selectedFilter == l10n.naskh) {
                          selectedStyle = "Naskh";
                        } else if (_selectedFilter == l10n.diwani) {
                          selectedStyle = "Diwani";
                        } else if (_selectedFilter == l10n.kufi) {
                          selectedStyle = "Kufi";
                        } else if (_selectedFilter == l10n.ruqah) {
                          selectedStyle = "Ruq'ah";
                        }
                        
                        matchesFilter = style == selectedStyle;
                      }
                    }

                    return matchesSearch && matchesFilter;
                  }).toList();

                  if (courses.isEmpty) {
                    final l10n = AppLocalizations.of(context)!;
                    // Show special empty state for "My Courses" filter
                    if (_selectedFilter == l10n.myCourses) {
                      return _buildEmptyState(
                        l10n.noEnrolledCourses,
                        subtitle: l10n.browseCoursesToEnroll,
                      );
                    }
                    return _buildEmptyState(l10n.noCoursesMatchFilter);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(
                      top: 10,
                      left: 16,
                      right: 16,
                      bottom: 100,
                    ),
                    itemCount: courses.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final doc = courses[index];
                      return _buildAwesomeCourseCard(context, doc);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER: Dynamic Course Name ---
  String _getLocalizedCourseName(BuildContext context, Map<String, dynamic> data) {
    return CourseUtils.getLocalizedCourseName(context, data);
  }

  String _formatDate(BuildContext context, dynamic timestamp) {
    if (timestamp == null) return "";
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    }
    if (date == null) return "";
    
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat.MMMd(locale).format(date);
  }

  // --- WIDGET: Header with Search & Chips ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.findYourCourse,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Glassmorphic Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchText = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchCourseHint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.accentGold,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _getFilters(AppLocalizations.of(context)!).map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                  onTap: () {
                    final l10n = AppLocalizations.of(context)!;
                    if (filter == l10n.myCourses) {
                      if (!GuestGuard.check(context, isGuest: FirebaseAuth.instance.currentUser == null)) {
                        return;
                      }
                    }
                    setState(() => _selectedFilter = filter);
                  },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentGold
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentGold
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: The "Awesome" Course Card ---
  Widget _buildAwesomeCourseCard(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final String bannerUrl = data['courseBanner'] ?? '';
    final String title = _getLocalizedCourseName(context, data);
    final String teacherName = data['teacherName'] ?? 'Unknown Teacher';
    final String teacherPic = data['teacherProfilePic'] ?? '';
    final String rawLevel = data['selectedCategory'] ?? 'Beginner';
    final l10n = AppLocalizations.of(context)!;
    final String levelLocalized = CourseUtils.getLocalizedLevel(context, rawLevel);

    final double price = (data['price'] ?? 0).toDouble();
    final String priceTag = price == 0 ? l10n.free : "\$${price.toStringAsFixed(0)}";

    final dynamic studentsRaw = data['enrolledStudents'];
    final List<dynamic> enrolledStudents = (studentsRaw is List) ? studentsRaw : [];
    final int currentEnrollment = enrolledStudents.length;
    final int maxStudents = (data['maxStudents'] ?? 0);

    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isEnrolled = currentUser != null && enrolledStudents.contains(currentUser.uid);

    // --- COUNTDOWN LOGIC ---
    int? daysRemaining;
    if (data['startDate'] != null) {
      DateTime? start;
      if (data['startDate'] is Timestamp) {
        start = (data['startDate'] as Timestamp).toDate();
      } else if (data['startDate'] is DateTime) {
        start = data['startDate'];
      }
      if (start != null) {
        final now = DateTime.now();
        final difference = start.difference(now).inDays;
        if (difference >= 0) {
          daysRemaining = difference;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      height: 290, // Increased height for more breathing room
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isEnrolled) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseDetailsPage(
                      courseId: doc.id,
                      courseData: data,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CoursePreviewPage(
                      courseId: doc.id,
                      courseData: data,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              children: [
                // Background Banner
                Positioned.fill(
                  child: Hero(
                    tag: 'course_img_${doc.id}',
                    child: bannerUrl.startsWith('assets')
                        ? Image.asset(bannerUrl, fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: bannerUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.cardBackground),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.cardBackground,
                              child: const Icon(Icons.error, color: Colors.white24),
                            ),
                          ),
                  ),
                ),

                // Gradual Gradient Overlay (Unified and deep)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.8),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Price or Enrolled Badge
                Positioned(
                  top: 20,
                  right: 20,
                  child: _buildFloatingBadge(context, isEnrolled, priceTag, doc.id, title, data['teacherId'] ?? ''),
                ),

                // Level Badge
                Positioned(
                  top: 20,
                  left: 20,
                  child: _buildLevelBadge(levelLocalized),
                ),

                // Content Overlay (Premium Glassmorphism)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                              width: 0.8,
                            ),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AutoTranslatedText(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 12), // Tighter spacing
                            
                            // NEW: Countdown and Date Row (More prominent)
                            if (daysRemaining != null || data['startDate'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    if (daysRemaining != null)
                                      _buildInfoPill(
                                        context,
                                        Icons.timer_outlined,
                                        _getCountdownLabel(context, daysRemaining),
                                        isSpecial: true,
                                      ),
                                    if (data['startDate'] != null)
                                      _buildInfoPill(
                                        context,
                                        Icons.calendar_today_rounded,
                                        () {
                                          final dateStr = _formatDate(context, data['startDate']);
                                          final daysStr = _formatSelectedDays(context, data['selectedDays']);
                                          return daysStr.isNotEmpty ? "$dateStr • $daysStr" : dateStr;
                                        }(),
                                      ),
                                  ],
                                ),
                              ),

                            Row(
                              children: [
                                // Instructor Info
                                Expanded(
                                  child: Row(
                                    children: [
                                      _buildPremiumAvatar(teacherPic),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  l10n.instructor.toUpperCase(),
                                                  style: TextStyle(
                                                    color: AppColors.accentGold.withOpacity(0.6),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.verified, color: AppColors.accentGold, size: 11),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              teacherName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Enrollment Stats (Visual Progress Style)
                                _buildEnrollmentStat(context, currentEnrollment, maxStudents),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBadge(BuildContext context, bool isEnrolled, String priceTag, String courseId, String title, String teacherId) {
    if (isEnrolled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRatingTrigger(context, courseId, title, teacherId),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.green, Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!.enrolled.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentGold,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        priceTag,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildRatingTrigger(BuildContext context, String courseId, String title, String teacherId) {
    return GestureDetector(
      onTap: () {
        showCourseCompletionRatingDialog(
          context: context,
          courseId: courseId,
          courseName: title,
          teacherId: teacherId,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accentGold.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: const Icon(Icons.star_rate_rounded, color: AppColors.accentGold, size: 18),
      ),
    );
  }

  Widget _buildLevelBadge(String level) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            level.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumAvatar(String url) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.accentGold, Color(0xFFB88A44)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.cardBackground, width: 2),
          image: url.isNotEmpty
              ? DecorationImage(
                  image: CachedNetworkImageProvider(url),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: url.isEmpty ? const Icon(Icons.person, color: Colors.white24, size: 24) : null,
      ),
    );
  }

  Widget _buildEnrollmentStat(BuildContext context, int current, int max) {
    bool isUrgent = max - current <= 3 && max > 0;
    double progress = max > 0 ? current / max : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group_rounded,
                color: isUrgent ? Colors.redAccent : AppColors.accentGold,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                "$current/$max",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Subtle Progress Bar
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUrgent 
                      ? [Colors.redAccent, Colors.red] 
                      : [AppColors.accentGold, const Color(0xFFB88A44)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCountdownLabel(BuildContext context, int days) {
    final locale = Localizations.localeOf(context).languageCode;
    if (days == 0) {
      return locale == 'ar' ? "تبدأ اليوم" : "Starts Today";
    }
    return locale == 'ar' ? "تبدأ بعد $days أيام" : "Starts in $days days";
  }

  String _formatSelectedDays(BuildContext context, dynamic selectedDays) {
    if (selectedDays == null || selectedDays is! List || selectedDays.isEmpty) return "";
    
    final locale = Localizations.localeOf(context).languageCode;
    
    // Map of full English names to short translated names
    final Map<String, String> dayTranslations = locale == 'ar' ? {
      'Monday': 'الاثنين',
      'Tuesday': 'الثلاثاء',
      'Wednesday': 'الأربعاء',
      'Thursday': 'الخميس',
      'Friday': 'الجمعة',
      'Saturday': 'السبت',
      'Sunday': 'الأحد',
    } : {
      'Monday': 'Mon',
      'Tuesday': 'Tue',
      'Wednesday': 'Wed',
      'Thursday': 'Thu',
      'Friday': 'Fri',
      'Saturday': 'Sat',
      'Sunday': 'Sun',
    };

    List<String> translatedDays = [];
    for (var day in selectedDays) {
      if (day is String) {
        translatedDays.add(dayTranslations[day] ?? day.substring(0, 3));
      }
    }

    return translatedDays.join(", ");
  }

  Widget _buildInfoPill(BuildContext context, IconData icon, String label, {bool isSpecial = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSpecial 
          ? AppColors.accentGold.withOpacity(0.15) 
          : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpecial 
            ? AppColors.accentGold.withOpacity(0.4) 
            : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            color: isSpecial ? AppColors.accentGold : Colors.white70, 
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSpecial ? AppColors.accentGold : Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, {String? subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
