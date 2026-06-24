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

                    // 3. Visibility Check: Hide started courses from non-enrolled students
                    bool isStarted = false;
                    if (data['startDate'] != null) {
                      DateTime? start;
                      if (data['startDate'] is Timestamp) {
                        start = (data['startDate'] as Timestamp).toDate();
                      } else if (data['startDate'] is DateTime) {
                        start = data['startDate'];
                      }
                      
                      if (start != null) {
                        final now = DateTime.now();
                        // If course started (or starts today), and student is not enrolled, hide it
                        if (now.isAfter(start) && !isEnrolled) {
                          return false; 
                        }
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

  // --- WIDGET: The "Awesome" Course Card (Redesigned) ---
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
    final String ageCategory = data['ageCategory'] ?? '17+';

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
    DateTime? startDate;
    if (data['startDate'] != null) {
      if (data['startDate'] is Timestamp) {
        startDate = (data['startDate'] as Timestamp).toDate();
      } else if (data['startDate'] is DateTime) {
        startDate = data['startDate'];
      }
      if (startDate != null) {
        final difference = startDate.difference(DateTime.now()).inDays;
        if (difference >= 0) daysRemaining = difference;
      }
    }

    // Time formatting
    String? timeStr;
    if (data['startTime'] != null) {
      DateTime? time;
      if (data['startTime'] is Timestamp) {
        time = (data['startTime'] as Timestamp).toDate();
      } else if (data['startTime'] is DateTime) {
        time = data['startTime'];
      }
      if (time != null) {
        final locale = Localizations.localeOf(context).languageCode;
        timeStr = DateFormat.jm(locale).format(time);
      }
    }

    // Seats urgency (only when < 5 seats left)
    final bool isSeatsUrgent = maxStudents > 0 && (maxStudents - currentEnrollment) <= 4 && (maxStudents - currentEnrollment) >= 0;

    // Formatted schedule strings
    final String startStr = _formatDate(context, data['startDate']);
    final String endStr = _formatDate(context, data['endDate']);
    final String daysStr = _formatSelectedDays(context, data['selectedDays']);


    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ━━━ BANNER IMAGE ━━━
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Stack(
                    children: [
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
                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.45),
                                Colors.transparent,
                                const Color(0xFF161616).withOpacity(0.85),
                              ],
                              stops: const [0.0, 0.35, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Top badges: Level + Age (left) / Price or Enrolled (right)
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLevelBadge(levelLocalized, rawLevel),
                                const SizedBox(height: 6),
                                _buildAgeBadge(ageCategory, context),
                              ],
                            ),
                            _buildFloatingBadge(context, isEnrolled, priceTag, doc.id, title, data['teacherId'] ?? ''),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ━━━ CONTENT BODY ━━━
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── TEACHER IDENTITY BLOCK ──
                      _buildTeacherIdentityBlock(
                        teacherPic: teacherPic,
                        teacherName: teacherName,
                        teacherId: data['teacherId'],
                      ),

                      const SizedBox(height: 14),

                      // ── COURSE TITLE ──
                      AutoTranslatedText(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── UNIFIED SCHEDULE STRIP ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          children: [
                            // Row 1: Dates + Days
                            Row(
                              children: [
                                _buildScheduleItem(
                                  icon: Icons.calendar_today_rounded,
                                  iconColor: const Color(0xFF6C63FF),
                                  value: startStr.isNotEmpty && endStr.isNotEmpty
                                      ? '$startStr – $endStr'
                                      : '—',
                                ),
                                _buildScheduleDivider(),
                                _buildScheduleItem(
                                  icon: Icons.view_week_rounded,
                                  iconColor: const Color(0xFF00B4D8),
                                  value: daysStr.isNotEmpty ? daysStr : '—',
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            // Row 2: Time + Seats
                            Row(
                              children: [
                                _buildScheduleItem(
                                  icon: Icons.access_time_rounded,
                                  iconColor: AppColors.accentGold,
                                  value: timeStr ?? '—',
                                ),
                                _buildScheduleDivider(),
                                _buildScheduleItem(
                                  icon: Icons.people_alt_rounded,
                                  iconColor: isSeatsUrgent ? const Color(0xFFFF4D6D) : const Color(0xFF26D17A),
                                  value: '$currentEnrollment / $maxStudents',
                                  isUrgent: isSeatsUrgent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── COUNTDOWN BANNER ──
                      if (daysRemaining != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: daysRemaining == 0
                                  ? [const Color(0xFFFF4D6D), const Color(0xFFFF1744)]
                                  : daysRemaining <= 3
                                      ? [const Color(0xFFFF6B35), const Color(0xFFFF4D6D)]
                                      : [const Color(0xFF6C63FF), const Color(0xFF4D8BFF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: (daysRemaining == 0
                                        ? const Color(0xFFFF4D6D)
                                        : daysRemaining <= 3
                                            ? const Color(0xFFFF6B35)
                                            : const Color(0xFF6C63FF))
                                    .withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                daysRemaining == 0
                                    ? Icons.notifications_active_rounded
                                    : daysRemaining <= 3
                                        ? Icons.local_fire_department_rounded
                                        : Icons.event_available_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getCountdownLabel(context, daysRemaining),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── TEACHER IDENTITY BLOCK ──
  // Groups avatar, name, and spoken languages into one clear section
  Widget _buildTeacherIdentityBlock({
    required String teacherPic,
    required String teacherName,
    String? teacherId,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Teacher Avatar (larger, with gold ring)
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(1.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.accentGold, Color(0xFFB88A44)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF161616),
              border: Border.all(color: const Color(0xFF161616), width: 1.5),
              image: teacherPic.isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(teacherPic),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: teacherPic.isEmpty
                ? const Icon(Icons.person, color: Colors.white24, size: 22)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        // Name + Languages column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: AppColors.accentGold,
                      size: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Inline languages
              _buildInlineTeacherLanguages(teacherId),
            ],
          ),
        ),
      ],
    );
  }

  // ── INLINE LANGUAGES (inside teacher block) ──
  Widget _buildInlineTeacherLanguages(String? teacherId) {
    if (teacherId == null || teacherId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(teacherId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        final dynamic languagesRaw = userData['spokenLanguages'];
        List<String> languages = [];
        if (languagesRaw is List) {
          languages = List<String>.from(languagesRaw);
        }
        if (languages.isEmpty) return const SizedBox.shrink();

        return Row(
          children: [
            Icon(Icons.translate_rounded,
                color: Colors.white.withOpacity(0.35), size: 12),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                languages.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── SCHEDULE STRIP ITEMS ──
  Widget _buildScheduleItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    bool isUrgent = false,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 15),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUrgent ? const Color(0xFFFF4D6D) : Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleDivider() {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withOpacity(0.08),
    );
  }

  Widget _buildFloatingBadge(BuildContext context, bool isEnrolled, String priceTag, String courseId, String title, String teacherId) {
    if (isEnrolled) {
      return Container(
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



  Widget _buildAgeBadge(String ageCategory, BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    String yearsLabel = 'Years';
    if (locale == 'ar') yearsLabel = 'سنوات';
    if (locale == 'tr') yearsLabel = 'Yaş';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, color: AppColors.accentGold, size: 16),
              const SizedBox(width: 6),
              Text(
                "$ageCategory $yearsLabel",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String localizedLevel, String rawLevel) {
    Color badgeColor;
    if (rawLevel.toLowerCase() == 'beginner') {
      badgeColor = Colors.green.shade600;
    } else if (rawLevel.toLowerCase() == 'intermediate') {
      badgeColor = Colors.orange.shade600;
    } else if (rawLevel.toLowerCase() == 'advanced') {
      badgeColor = Colors.purple.shade600;
    } else {
      badgeColor = Colors.black.withOpacity(0.6); // Default fallback
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            localizedLevel.toUpperCase(),
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

