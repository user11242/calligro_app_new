import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/widgets/auto_translated_text.dart';
import '../../../core/utils/course_utils.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../pages/course_details/course_details_page.dart';

// Enum to define course filter options
enum CourseFilter { all, active, upcoming, ended }

class TeacherCoursesTab extends StatefulWidget {
  const TeacherCoursesTab({super.key});

  @override
  State<TeacherCoursesTab> createState() => _TeacherCoursesTabState();
}

class _TeacherCoursesTabState extends State<TeacherCoursesTab> {
  String? _teacherId;
  bool _isTeacherIdLoading = true;
  CourseFilter _selectedFilter = CourseFilter.all;
  Stream<QuerySnapshot>? _coursesStream;

  @override
  void initState() {
    super.initState();
    _initTeacherData();
  }

  void _initTeacherData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _teacherId = user.uid;
      _isTeacherIdLoading = false;
      _initCoursesStream();
    } else {
      _fetchTeacherId(); // Fallback for edge cases
    }
  }

  void _initCoursesStream() {
    if (_teacherId != null) {
      _coursesStream = FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: _teacherId!)
          .snapshots();
    }
  }

  Future<void> _fetchTeacherId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (mounted) {
          setState(() {
            _teacherId = user.uid;
            _isTeacherIdLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _teacherId = null;
            _isTeacherIdLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _teacherId = null;
          _isTeacherIdLoading = false;
        });
      }
      print("Error fetching teacher ID: $e");
    }
  }

  CourseFilter _getCourseStatusFilter(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return CourseFilter.all;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    if (today.isBefore(startDay)) {
      return CourseFilter.upcoming;
    } else if (today.isAfter(endDay)) {
      return CourseFilter.ended;
    } else {
      return CourseFilter.active;
    }
  }

  String _getFilterName(CourseFilter filter) {
    switch (filter) {
      case CourseFilter.all:
        return AppLocalizations.of(context)!.all;
      case CourseFilter.active:
        return AppLocalizations.of(context)!.active;
      case CourseFilter.upcoming:
        return AppLocalizations.of(context)!.upcoming;
      case CourseFilter.ended:
        return AppLocalizations.of(context)!.ended;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.myCourses,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<CourseFilter>(
            color: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            onSelected: (CourseFilter result) {
              setState(() {
                _selectedFilter = result;
              });
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<CourseFilter>>[
                  _buildPopupMenuItem(CourseFilter.all, AppLocalizations.of(context)!.allCourses),
                  _buildPopupMenuItem(CourseFilter.active, AppLocalizations.of(context)!.activeCourses),
                  _buildPopupMenuItem(
                    CourseFilter.upcoming,
                    AppLocalizations.of(context)!.upcomingCourses,
                  ),
                  _buildPopupMenuItem(CourseFilter.ended, AppLocalizations.of(context)!.endedCourses),
                ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: AppColors.textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getFilterName(_selectedFilter),
                    style: const TextStyle(
                      color: AppColors.textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.textColor,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/addCourse');
            },
            tooltip: AppLocalizations.of(context)!.addNewCourse,
          ),
        ],
      ),
      body: Container(color: AppColors.primary, child: _buildBodyContent()),
    );
  }

  PopupMenuItem<CourseFilter> _buildPopupMenuItem(
    CourseFilter value,
    String text,
  ) {
    final bool isSelected = _selectedFilter == value;
    return PopupMenuItem<CourseFilter>(
      value: value,
      child: Row(
        children: [
          isSelected
              ? const Icon(Icons.check, color: AppColors.accentGold, size: 20)
              : const SizedBox(width: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColors.accentGold : AppColors.textColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isTeacherIdLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.textColor),
      );
    }

    if (_teacherId == null || _teacherId!.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.teacherIdNotFound,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    if (_coursesStream == null) {
      _initCoursesStream();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _coursesStream,
      builder: (context, courseSnapshot) {
        if (courseSnapshot.connectionState == ConnectionState.waiting && !courseSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.textColor),
          );
        } else if (courseSnapshot.hasError) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.errorFetchingCourses(courseSnapshot.error.toString()),
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final List<QueryDocumentSnapshot> courseDocs =
            courseSnapshot.data?.docs ?? [];

        final List<Map<String, dynamic>> allCoursesWithIds = courseDocs.map((
          doc,
        ) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'data': data, // Pass the whole data for CourseUtils
            'startDate': (data['startDate'] as Timestamp?)?.toDate(),
            'endDate': (data['endDate'] as Timestamp?)?.toDate(),
          };
        }).toList();
        final List<Map<String, dynamic>> filteredCourses = allCoursesWithIds
            .where((course) {
              if (_selectedFilter == CourseFilter.all) {
                return true;
              }
              final status = _getCourseStatusFilter(
                course['startDate'],
                course['endDate'],
              );
              return status == _selectedFilter;
            })
            .toList();

        if (filteredCourses.isEmpty) {
          String emptyMessage;
          String subMessage;
          IconData emptyIcon = Icons.school_outlined;

          if (allCoursesWithIds.isEmpty &&
              _selectedFilter == CourseFilter.all) {
            emptyMessage = AppLocalizations.of(context)!.noCoursesCreated;
            subMessage = AppLocalizations.of(context)!.tapPlusToGetStarted;
            emptyIcon = Icons.add_business;
          } else if (_selectedFilter != CourseFilter.all) {
            emptyMessage = AppLocalizations.of(context)!.noFilteredCoursesFound(_getFilterName(_selectedFilter));
            subMessage = AppLocalizations.of(context)!.trySelectingAllCourses;
            emptyIcon = Icons.filter_alt_off;
          } else {
            emptyMessage = AppLocalizations.of(context)!.noCoursesAvailable;
            subMessage = AppLocalizations.of(context)!.somethingWentWrong;
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, color: Colors.white24, size: 60),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  subMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.only(
              top: 20,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            itemCount: filteredCourses.length,
            itemBuilder: (context, index) {
              final course = filteredCourses[index];
              return _StyledCourseCard(
                courseId: course['id'],
                courseData: course['data'],
                startDate: course['startDate'],
                endDate: course['endDate'],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailsPage(
                        courseId: course['id'],
                        courseData: course['data'],
                      ),
                    ),
                  );
                },
              ).animate()
               .fadeIn(duration: 500.ms, delay: (index * 100).ms)
               .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
            },
          ),
        );
      },
    );
  }
}

class _StyledCourseCard extends StatelessWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onTap;

  const _StyledCourseCard({
    required this.courseId,
    required this.courseData,
    this.startDate,
    this.endDate,
    required this.onTap,
  });

  Map<String, dynamic> _getCourseDisplayStatus(BuildContext context) {
    if (startDate == null || endDate == null) {
      return {'text': 'Status Unknown', 'color': Colors.grey};
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final endDay = DateTime(endDate!.year, endDate!.month, endDate!.day);

    if (today.isBefore(startDay)) {
      return {
        'text': AppLocalizations.of(context)!.upcoming,
        'color': AppColors.accentGold,
        'icon': Icons.schedule_rounded
      };
    } else if (today.isAfter(endDay)) {
      return {
        'text': AppLocalizations.of(context)!.ended,
        'color': Colors.redAccent,
        'icon': Icons.event_available_rounded
      };
    } else {
      return {
        'text': AppLocalizations.of(context)!.active,
        'color': Colors.greenAccent,
        'icon': Icons.bolt_rounded
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getCourseDisplayStatus(context);
    final String title = CourseUtils.getLocalizedCourseName(context, courseData);
    final String bannerUrl = courseData['courseBanner'] ?? '';
    
    final dynamic studentsRaw = courseData['enrolledStudents'];
    final int studentCount = (studentsRaw is List) ? studentsRaw.length : (studentsRaw is num ? studentsRaw.toInt() : 0);
    final int maxStudents = courseData['maxStudents'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      height: 260,
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
          color: AppColors.cardBackground,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // Banner with adjusted height and zoom effect
                Positioned.fill(
                  child: bannerUrl.startsWith('http')
                      ? SmartImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(32),
                          placeholder: Container(color: Colors.white10),
                          errorWidget: const Icon(Icons.error),
                        )
                      : bannerUrl.startsWith('assets')
                          ? Image.asset(bannerUrl, fit: BoxFit.cover)
                          : Container(color: Colors.white10),
                ),
                
                // Multi-layered Gradient for depth
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.0, 0.4, 0.9],
                      ),
                    ),
                  ),
                ),

                // Content Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.4),
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title & Status Badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AutoTranslatedText(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildStatusBadge(statusInfo),
                              ],
                            ),
                            const SizedBox(height: 18),
                            
                            // Glass Info Row (Pills)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildInfoPill(
                                    context,
                                    Icons.calendar_month_rounded,
                                    startDate != null && endDate != null
                                        ? "${DateFormat('dd/MM', Localizations.localeOf(context).toString()).format(startDate!)} - ${DateFormat('dd/MM', Localizations.localeOf(context).toString()).format(endDate!)}"
                                        : "TBD",
                                  ),
                                  const SizedBox(width: 8),
                                  _buildInfoPill(
                                    context,
                                    Icons.access_time_filled_rounded,
                                    _formatTimeRange(context, courseData['startTime'], courseData['endTime']),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildInfoPill(
                                    context,
                                    Icons.group_rounded,
                                    "$studentCount/$maxStudents",
                                    iconColor: studentCount >= maxStudents ? Colors.redAccent : AppColors.accentGold,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Progress & Labels
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.enrolledStudentsCount(studentCount),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  "${((studentCount / (maxStudents > 0 ? maxStudents : 1)) * 100).toInt()}%",
                                  style: const TextStyle(
                                    color: AppColors.accentGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildPremiumProgressBar(studentCount, maxStudents),
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

  Widget _buildStatusBadge(Map<String, dynamic> status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (status['color'] as Color).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (status['color'] as Color).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status['icon'] as IconData, color: status['color'] as Color, size: 12),
          const SizedBox(width: 4),
          Text(
            (status['text'] as String).toUpperCase(),
            style: TextStyle(
              color: status['color'] as Color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(BuildContext context, IconData icon, String label, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor ?? AppColors.accentGold, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeRange(BuildContext context, dynamic start, dynamic end) {
    if (start == null || end == null) return "TBD";
    DateTime? startTime;
    DateTime? endTime;
    if (start is Timestamp) startTime = start.toDate();
    if (end is Timestamp) endTime = end.toDate();
    if (startTime != null && endTime != null) {
      final locale = Localizations.localeOf(context).toString();
      return "${DateFormat('h:mm a', locale).format(startTime)} - ${DateFormat('h:mm a', locale).format(endTime)}";
    }
    return "TBD";
  }

  Widget _buildPremiumProgressBar(int current, int max) {
    final double progress = (current / (max > 0 ? max : 1)).clamp(0.0, 1.0);
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentGold.withOpacity(0.6),
                    AppColors.accentGold,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGold.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
