import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/domain/course_board.dart';
import 'package:calligro_app/features/classroom/presentation/classroom_scope.dart';
import 'package:calligro_app/features/profile/presentation/pages/public_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';
import 'dart:ui';
import '../../../../core/message/app_messenger.dart';

// ✅ CORRECT IMPORTS
import '../course_details/announcements_board_page.dart';
import '../course_details/assignments_page.dart';
import 'package:calligro_app/features/meet/presentation/livekit_meet_service.dart';
import 'package:calligro_app/core/services/translation_service.dart';
import 'package:calligro_app/features/student/widgets/course_share_card.dart';
import 'package:calligro_app/core/utils/share_utils.dart';
import 'package:permission_handler/permission_handler.dart';


import 'package:calligro_app/features/teacher/pages/course_details/recordings_page.dart';

import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/features/teacher/pages/course_details/course_materials_page.dart';
import 'package:calligro_app/features/classroom/presentation/chat/course_chat_page.dart';
import 'package:calligro_app/features/classroom/presentation/chat/course_details_floating_bar.dart';

part 'course_details_overview.dart';
part 'course_details_schedule.dart';
part 'course_details_classroom.dart';
part 'course_details_students.dart';
part 'course_details_header.dart';
part 'course_details_texts.dart';

class CourseDetailsPage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final String? heroTag;

  const CourseDetailsPage({
    super.key,
    required this.courseId,
    required this.courseData,
    this.heroTag,
  });

  @override
  State<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends State<CourseDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State Variables
  bool isLoading = true;
  String userRole = 'student'; // Default to student
  String? courseTeacherId;

  List<String> _enrolledStudents = const [];

  /// The viewer's role in THIS course. Being a teacher of another course
  /// gives no teacher controls here (it used to: `userRole == 'teacher'`).
  CourseRole get _role => ClassroomAccess.roleOf(
        teacherId: courseTeacherId ?? (widget.courseData['teacherId'] as String? ?? ''),
        enrolledStudents: _enrolledStudents,
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        isAdmin: userRole == 'admin',
      );

  bool get isTeacher => _role == CourseRole.owner;

  static List<String> _ids(Object? v) => v is List ? [for (final e in v) if (e is String) e] : const [];

  String courseName = '';
  String? courseBanner;
  String courseDescription = '';
  String courseLevel = 'Beginner';
  String? calligroMeetLink;
  String? classroomPassword; // Added to store password
  int initialStudentCount = 0;
  DateTime? startDate;
  DateTime? endDate;
  DateTime? selectedTime;
  DateTime? endTime; // Added to store end time
  List<String> selectedDays = [];
  List<dynamic> requiredTools = [];
  List<String> curriculumSteps = []; // Added to store curriculum
  String? ageCategory; // Added to store student age category

  // Analysis Variables
  Map<String, List<DateTime>> sessionDates = {};
  int totalSessions = 0;
  String? expandedDay;
  final Map<String, GlobalKey> _dayKeys = {};
  final GlobalKey _shareKey = GlobalKey();

  // Dynamic Scheduling State
  Map<String, dynamic>? _rescheduledData;
  bool _isSavingReschedule = false;

  // Translation State
  bool _isTranslating = false;
  String? _translatedDescription;
  String? _translatedName;
  List<dynamic>? _translatedTools;
  List<String>? _translatedCurriculum;
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // Always 3 tabs (Overview, Schedule, Classroom)
    
    // ✅ Use addPostFrameCallback to safely access AppLocalizations.of(context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData(); 
        _checkUserRole();
        _fetchFullCourseData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠️ DO NOT call _loadInitialData() here!
    // didChangeDependencies() fires every time the Navigator updates its
    // InheritedWidget (e.g., when CalligroMeetPage is pushed/popped), which
    // was causing setState() → full rebuild → killing the meeting page.
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          userRole = doc.data()?['role'] ?? 'student';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- HELPER: Dynamic Course Name ---
  String _getLocalizedCourseName(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    if (!mounted) return data['courseName'] ?? 'Untitled';
    return CourseUtils.getLocalizedCourseName(context, data);
  }

  void _loadInitialData() {
    if (mounted) {
      setState(() {
        courseTeacherId = widget.courseData['teacherId'];
        _enrolledStudents = _ids(widget.courseData['enrolledStudents']);
        courseName = _getLocalizedCourseName(context, widget.courseData);
        courseBanner = widget.courseData['courseBanner'];
        calligroMeetLink =
            widget.courseData['calligroMeetLink'] ??
            widget.courseData['googleMeetLink'];
        initialStudentCount = widget.courseData['studentsEnrolled'] ?? 0;
        requiredTools =
            widget.courseData['requiredTools'] as List<dynamic>? ?? [];

        // FALLBACK: Try to populate schedule fields from widget.courseData if available
        startDate = (widget.courseData['startDate'] as Timestamp?)?.toDate();
        endDate = (widget.courseData['endDate'] as Timestamp?)?.toDate();
        selectedTime =
            (widget.courseData['startTime'] as Timestamp?)?.toDate() ??
            (widget.courseData['selectedTime'] as Timestamp?)?.toDate();
        classroomPassword =
            widget.courseData['classroomPassword']; // Sync from widget
        endTime = (widget.courseData['endTime'] as Timestamp?)?.toDate();
        selectedDays =
            (widget.courseData['selectedDays'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        curriculumSteps =
            (widget.courseData['curriculumSteps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        ageCategory = widget.courseData['ageCategory'];
      });
    }
  }

  Future<void> _fetchFullCourseData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          courseTeacherId = data['teacherId'] ?? courseTeacherId;
          _enrolledStudents = _ids(data['enrolledStudents']);
          courseName = _getLocalizedCourseName(context, data);
          courseBanner = data['courseBanner'] ?? courseBanner;
          courseDescription =
              data['courseDescription'] ??
              AppLocalizations.of(context)!.noDescriptionProvided;
          courseLevel =
              data['selectedCategory'] ??
              data['levelColor'] ??
              AppLocalizations.of(context)!.beginner;
          calligroMeetLink =
              data['calligroMeetLink'] ??
              data['googleMeetLink']; // Support both keys
          classroomPassword = data['classroomPassword']; // Fetch password
          requiredTools = data['requiredTools'] as List<dynamic>? ?? [];

          // POPULATE ALL SCHEDULE FIELDS
          startDate = (data['startDate'] as Timestamp?)?.toDate();
          endDate = (data['endDate'] as Timestamp?)?.toDate();
          selectedTime =
              (data['startTime'] as Timestamp?)?.toDate() ??
              (data['selectedTime'] as Timestamp?)?.toDate();
          endTime = (data['endTime'] as Timestamp?)?.toDate();
          selectedDays =
              (data['selectedDays'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          curriculumSteps =
              (data['curriculumSteps'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          ageCategory = data['ageCategory'];
        });

        _calculateSessionBreakdown();
        _checkTranslationAvailability();

        // Start listening to dynamic overrides
        _listenToOverrides();
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: "${AppLocalizations.of(context)!.error}: $e",
          type: MessengerType.error,
        );
      }
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateSessionBreakdown() {
    if (startDate == null || endDate == null || selectedDays.isEmpty) return;

    sessionDates.clear();
    totalSessions = 0;
    _dayKeys.clear();

    for (var day in selectedDays) {
      sessionDates[day] = [];
      _dayKeys[day] = GlobalKey();
    }

    DateTime current = startDate!;
    DateTime endLoop = endDate!.add(const Duration(days: 1));

    while (current.isBefore(endLoop)) {
      String dayName = DateFormat('EEEE').format(current);
      if (selectedDays.contains(dayName)) {
        sessionDates[dayName]?.add(current);
        totalSessions++;
      }
      current = current.add(const Duration(days: 1));
    }
  }

  void _toggleDayExpansion(String dayName) {
    setState(() {
      expandedDay = (expandedDay == dayName) ? null : dayName;
    });
  }

  Future<void> _checkTranslationAvailability() async {
    // Collect things that might need translation
    bool needsTranslation = false;

    // 1. Description
    if (_translatedDescription == null) {
      final standardLocalized = _localizeDescription(courseDescription);
      if (standardLocalized == courseDescription) needsTranslation = true;
    }

    // 2. Name (if it's not a standard template)
    if (_translatedName == null && courseName.isNotEmpty) {
      needsTranslation = true;
    }

    // 3. Tools (if any are not in our lookup)
    if (_translatedTools == null && requiredTools.isNotEmpty) {
      for (var tool in requiredTools) {
        String name = tool is Map ? (tool['name'] ?? '') : tool.toString();
        if (_localizeContent(name) == name) {
          needsTranslation = true;
          break;
        }
      }
    }

    // 4. Curriculum
    if (_translatedCurriculum == null && curriculumSteps.isNotEmpty) {
      for (var step in curriculumSteps) {
        if (_localizeContent(step) == step) {
          needsTranslation = true;
          break;
        }
      }
    }

    if (needsTranslation) {
      _translateAllContent();
    }
  }

  Future<void> _translateAllContent() async {
    if (_isTranslating) return;
    setState(() => _isTranslating = true);

    try {
      final currentLocale = Localizations.localeOf(context).languageCode;
      final targetLang = _translationService.getLanguage(currentLocale);
      if (targetLang == null) return;

      // Helper to translate single string
      Future<String?> translate(String text) async {
        if (text.isEmpty) return null;
        return await _translationService.translate(
          text: text,
          target: currentLocale,
        );
      }

      // Translate Name
      String? newName = await translate(courseName);

      // Translate Description
      String? newDesc;
      if (_localizeDescription(courseDescription) == courseDescription) {
        newDesc = await translate(courseDescription);
      }

      // Translate Tools
      List<dynamic>? newTools;
      if (requiredTools.isNotEmpty) {
        List<dynamic> trans = [];
        for (var tool in requiredTools) {
          String name = tool is Map ? (tool['name'] ?? '') : tool.toString();
          if (_localizeContent(name) == name) {
            String? tName = await translate(name);
            if (tName != null) {
              trans.add(tool is Map ? {...tool, 'name': tName} : tName);
              continue;
            }
          }
          trans.add(tool);
        }
        newTools = trans;
      }

      // Translate Curriculum
      List<String>? newCurr;
      if (curriculumSteps.isNotEmpty) {
        List<String> trans = [];
        for (var step in curriculumSteps) {
          if (_localizeContent(step) == step) {
            String? tStep = await translate(step);
            if (tStep != null) {
              trans.add(tStep);
              continue;
            }
          }
          trans.add(step);
        }
        newCurr = trans;
      }

      if (mounted) {
        setState(() {
          if (newName != null) _translatedName = newName;
          if (newDesc != null) _translatedDescription = newDesc;
          if (newTools != null) _translatedTools = newTools;
          if (newCurr != null) _translatedCurriculum = newCurr;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  void _listenToOverrides() {
    FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data() as Map<String, dynamic>;

            // Auto-expire reschedule if it was for a previous day
            var rescheduleData = data['rescheduledSession'];
            if (rescheduleData != null &&
                rescheduleData['originalDate'] != null) {
              final originalDate = (rescheduleData['originalDate'] as Timestamp)
                  .toDate();
              final now = DateTime.now();
              if (originalDate.year != now.year ||
                  originalDate.month != now.month ||
                  originalDate.day != now.day) {
                rescheduleData = null; // Ignore it, it's expired
              }
            }

            setState(() {
              _rescheduledData = rescheduleData;
            });
          }
        });
  }

  Future<void> _showRescheduleDialog() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedTime ?? DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentGold,
              onPrimary: Colors.black,
              surface: AppColors.primary,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentGold,
              ),
            ),
            dialogTheme: DialogThemeData(backgroundColor: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final newStartTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      // Assume 1 hour session for simplicity in this mockup or pick end time too
      final newEndTime = newStartTime.add(const Duration(hours: 1));

      setState(() => _isSavingReschedule = true);
      try {
        // The server tells the students (once).
        final result = await ClassroomScope.of(context).board.reschedule(
              widget.courseId,
              _role,
              SessionChange(originalDate: now, newStart: newStartTime, newEnd: newEndTime),
            );
        if (!result.ok) throw Exception(result.message ?? result.outcome.name);
        if (!mounted) return;

        _showMessage(
          AppLocalizations.of(context)!.success,
          AppLocalizations.of(context)!.sessionRescheduledSuccess,
          MessengerType.success,
        );
      } catch (e) {
        _showMessage(
          AppLocalizations.of(context)!.error,
          "${AppLocalizations.of(context)!.error}: $e",
          MessengerType.error,
        );
      }
      setState(() => _isSavingReschedule = false);
    }
  }

  Future<void> _cancelReschedule() async {
    setState(() => _isSavingReschedule = true);
    try {
      final result = await ClassroomScope.of(context).board.cancelReschedule(widget.courseId, _role);
      if (!result.ok) throw Exception(result.message ?? result.outcome.name);
      _showMessage(
        AppLocalizations.of(context)!.success,
        AppLocalizations.of(context)!.sessionBackToNormal,
        MessengerType.info,
      );
    } catch (e) {
      _showMessage(
        AppLocalizations.of(context)!.error,
        "${AppLocalizations.of(context)!.error}: $e",
        MessengerType.error,
      );
    }
    setState(() => _isSavingReschedule = false);
  }

  void _showMessage(String title, String msg, MessengerType type) {
    if (!mounted) return;
    AppMessenger.showSnackBar(context, title: title, message: msg, type: type);
  }

  final AdminService _adminService = AdminService();


  @override
  Widget build(BuildContext context) {
    final Color levelColor = _getLevelColor(courseLevel);

    return Scaffold(
      backgroundColor: AppColors.primary,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: CourseDetailsFloatingBar(
        isTeacher: isTeacher,
        onLiveSessionPressed: _launchClassroom,
        onChatPressed: _openCourseChat,
      ),
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 280.0,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (userRole == 'admin')
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        size: 18,
                        color: Colors.amber,
                      ),
                    ),
                    tooltip: 'Send Course Notification',
                    onPressed: _showAdminNotificationDialog,
                  ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    await ShareUtils.shareWidgetAsImage(
                      boundaryKey: _shareKey,
                      text:
                          "Registering for my course '${CourseUtils.getLocalizedCourseName(context, widget.courseData)}' on Calligro!",
                      subject: "Calligraphy Course",
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: widget.heroTag ?? 'course_h_${widget.courseId}',
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (courseBanner != null && courseBanner!.isNotEmpty)
                          ? (courseBanner!.startsWith('http')
                                ? SmartImage(
                                    imageUrl: courseBanner!,
                                    fit: BoxFit.cover,
                                    placeholder: Container(
                                      color: AppColors.accentGold.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                    errorWidget: Container(
                                      color: AppColors.accentGold.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    courseBanner!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              color: AppColors.accentGold
                                                  .withOpacity(0.1),
                                            ),
                                  ))
                          : Container(
                              color: AppColors.accentGold.withOpacity(0.1),
                            ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.primary.withOpacity(0.2),
                              AppColors.primary.withOpacity(0.9),
                              AppColors.primary,
                            ],
                            stops: const [0.0, 0.4, 0.8, 1.0],
                          ),
                        ),
                      ),
                      _buildGlassHeader(levelColor),
                      // Hidden Share Card for capturing
                      Positioned(
                        left: -2000, // Way off screen
                        child: RepaintBoundary(
                          key: _shareKey,
                          child: CourseShareCard(
                            courseData: widget.courseData,
                            teacherName:
                                widget.courseData['teacherName'] ??
                                'Master Artist',
                            teacherProfilePic:
                                widget.courseData['teacherProfilePic'] ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // --- 2. FIXED STICKY TABS (MODERN PILL STYLE) ---
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                Container(
                  height: 70,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.white60,
                      indicator: BoxDecoration(
                        color: AppColors.accentGold,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGold.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        fontFamily: 'Urbanist',
                        letterSpacing: 0.5,
                      ),
                      tabs: [
                        Tab(
                          text: AppLocalizations.of(
                            context,
                          )!.overview.toUpperCase(),
                        ),
                        Tab(
                          text: AppLocalizations.of(
                            context,
                          )!.schedule.toUpperCase(),
                        ),
                        Tab(
                          text: AppLocalizations.of(
                            context,
                          )!.classroom.toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildScheduleTab(),
            _buildClassroomTab(),
          ],
        ),
      ),
    );
  }

}

// --- ✅ UPDATED DELEGATE TO FIX GEOMETRY ERROR ---
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate(this.child);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.primary, child: child);
  }

  @override
  double get maxExtent => child is PreferredSizeWidget
      ? (child as PreferredSizeWidget).preferredSize.height
      : 70;

  @override
  double get minExtent => child is PreferredSizeWidget
      ? (child as PreferredSizeWidget).preferredSize.height
      : 70;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

