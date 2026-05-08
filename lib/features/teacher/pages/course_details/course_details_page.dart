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
import '../../../student/pages/public_profile/public_student_profile_page.dart';
import 'package:calligro_app/core/services/translation_service.dart';
import 'package:calligro_app/features/student/widgets/course_share_card.dart';
import 'package:calligro_app/core/utils/share_utils.dart';
import '../../services/jitsi_meet_service.dart';

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

  // Analysis Variables
  Map<String, List<DateTime>> sessionDates = {};
  int totalSessions = 0;
  String? expandedDay;
  final Map<String, GlobalKey> _dayKeys = {};
  final GlobalKey _shareKey = GlobalKey();

  // Dynamic Scheduling State
  Map<String, dynamic>? _rescheduledData;
  String? _teacherStatusMessage;
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
    _checkUserRole();
    // _loadInitialData() moved to didChangeDependencies directly or via a flag if needed,
    // but typically safe to call there for localization updates.
    _fetchFullCourseData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadInitialData();
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
        courseName = _getLocalizedCourseName(context, widget.courseData);
        courseBanner = widget.courseData['courseBanner'];
        calligroMeetLink = widget.courseData['calligroMeetLink'] ?? widget.courseData['googleMeetLink'];
        initialStudentCount = widget.courseData['studentsEnrolled'] ?? 0;
        requiredTools =
            widget.courseData['requiredTools'] as List<dynamic>? ?? [];

        // FALLBACK: Try to populate schedule fields from widget.courseData if available
        startDate = (widget.courseData['startDate'] as Timestamp?)?.toDate();
        endDate = (widget.courseData['endDate'] as Timestamp?)?.toDate();
        selectedTime =
            (widget.courseData['startTime'] as Timestamp?)?.toDate() ??
            (widget.courseData['selectedTime'] as Timestamp?)?.toDate();
        classroomPassword = widget.courseData['classroomPassword']; // Sync from widget
        endTime = (widget.courseData['endTime'] as Timestamp?)?.toDate();
        selectedDays = (widget.courseData['selectedDays'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        curriculumSteps =
            (widget.courseData['curriculumSteps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
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
          courseName = _getLocalizedCourseName(context, data);
          courseBanner = data['courseBanner'] ?? courseBanner;
          courseDescription =
              data['courseDescription'] ??
              AppLocalizations.of(context)!.noDescriptionProvided;
          courseLevel =
              data['selectedCategory'] ??
              data['levelColor'] ??
              AppLocalizations.of(context)!.beginner;
          calligroMeetLink = data['calligroMeetLink'] ?? data['googleMeetLink']; // Support both keys
          classroomPassword = data['classroomPassword']; // Fetch password
          requiredTools = data['requiredTools'] as List<dynamic>? ?? [];

          // POPULATE ALL SCHEDULE FIELDS
          startDate = (data['startDate'] as Timestamp?)?.toDate();
          endDate = (data['endDate'] as Timestamp?)?.toDate();
          selectedTime = (data['startTime'] as Timestamp?)?.toDate() ??
              (data['selectedTime'] as Timestamp?)?.toDate();
          endTime = (data['endTime'] as Timestamp?)?.toDate();
          selectedDays = (data['selectedDays'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          curriculumSteps = (data['curriculumSteps'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
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


  Future<void> _launchClassroom() async {
    final l10n = AppLocalizations.of(context)!;
    if (calligroMeetLink != null && calligroMeetLink!.isNotEmpty) {
      debugPrint("DEBUG: Classroom logic triggered. Link: $calligroMeetLink");
      final isTeacher = userRole == 'teacher';

      // 🚨 LEGACY DETECTOR: Check if this is an old Google Meet link
      if (calligroMeetLink!.contains("meet.google.com") || calligroMeetLink!.contains("http")) {
        if (mounted) {
          AppMessenger.showSnackBar(
            context,
            title: isTeacher ? "Legacy Link Detected" : "Classroom Unavailable",
            message: isTeacher 
              ? "This course is using an old Google Meet link. Please create a new course or regenerate the link to use 'Calligro Classroom'."
              : "The teacher hasn't upgraded this classroom yet. Please contact them.",
            type: MessengerType.info,
          );
        }
        return;
      }
      
      /* 🚫 SMART GATING DISABLED AT USER REQUEST (For testing and ad-hoc sessions)
      if (!isTeacher) {
        // Smart Gating Logic for Students
        final now = DateTime.now();
        
        // 1. Get Effective Start Time (Rescheduled or Original)
        DateTime effectiveStart;
        if (_rescheduledData != null && _rescheduledData!['newStartTime'] != null) {
          effectiveStart = (_rescheduledData!['newStartTime'] as Timestamp).toDate();
        } else if (selectedTime != null) {
          effectiveStart = DateTime(now.year, now.month, now.day, selectedTime!.hour, selectedTime!.minute);
        } else {
          effectiveStart = now; 
        }

        // 2. Define Buffers
        final earlyBuffer = effectiveStart.subtract(const Duration(minutes: 10));
        final gracePeriodEnd = effectiveStart.add(const Duration(minutes: 120)); // Increased for flexibility

        // Day Check
        if (selectedDays.isNotEmpty) {
          final todayName = DateFormat('EEEE').format(now);
          if (!selectedDays.contains(todayName)) {
            _showMessage(
              l10n.tooEarly, 
              "There is no session scheduled for today. Please check the schedule tab.",
              MessengerType.info,
            );
            return;
          }
        }

        if (now.isBefore(earlyBuffer)) {
          _showMessage(l10n.tooEarly, "The classroom will open 10 minutes before the session starts.", MessengerType.info);
          return;
        }
        
        if (now.isAfter(gracePeriodEnd)) {
          _showMessage(l10n.classEnded, "The live session for today has concluded or the grace period has expired.", MessengerType.info);
          return;
        }
      }
      */

      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? "User";
      final userEmail = user?.email ?? "";
      final userAvatar = user?.photoURL ?? "";

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: "Starting Classroom",
          message: "Please wait while we connect to Calligro Classroom...",
          type: MessengerType.info,
        );
      }

      try {
        // Adding a timeout because Jitsi can sometimes hang on simulators
        await JitsiMeetService().joinMeeting(
          roomName: calligroMeetLink!, // Using the branded field
          userName: userName,
          userEmail: userEmail,
          avatarUrl: userAvatar,
          password: classroomPassword, // ✅ SECURITY: Automatic unlock for enrolled users
          isModerator: isTeacher,
        ).timeout(const Duration(seconds: 10), onTimeout: () {
          throw Exception("The meeting service timed out. This often happens on simulators without camera support.");
        });
      } catch (e) {
        if (mounted) {
          AppMessenger.showSnackBar(
            context,
            title: "Launch Error",
            message: "Could not launch classroom: $e",
            type: MessengerType.error,
          );
        }
      }
    } else {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: userRole == 'teacher' 
            ? "Classroom Not Set" 
            : AppLocalizations.of(context)!.noMeetingLink,
          message: userRole == 'teacher'
            ? "Please go to Course Summary to generate your classroom link first."
            : AppLocalizations.of(context)!.noMeetingLinkSet,
          type: MessengerType.info,
        );
      }
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Beginner':
        return Colors.tealAccent;
      case 'Intermediate':
        return Colors.orangeAccent;
      case 'Advanced':
        return Colors.purpleAccent;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color levelColor = _getLevelColor(courseLevel);

    return Scaffold(
      backgroundColor: AppColors.primary,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _launchClassroom,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ).copyWith(elevation: WidgetStateProperty.all(0)),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.greenAccent, Colors.green.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.video_camera_front,
                      size: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      userRole == 'teacher'
                          ? AppLocalizations.of(context)!.startLiveSession
                          : AppLocalizations.of(context)!.joinLiveSession,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Urbanist',
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                              color: AppColors.accentGold.withOpacity(
                                0.1,
                              ),
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
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
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

  Widget _buildOverviewTab() {
    final l10n = AppLocalizations.of(context)!;
    List<Widget> children = [
      _buildSectionTitle(l10n.description, Icons.menu_book),
      const SizedBox(height: 12),
      Text(
        _translatedDescription ?? _localizeDescription(courseDescription),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 15,
          height: 1.6,
        ),
      ),
      if (_isTranslating)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(
                  context,
                )!.translating, // Silent translation in progress
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 32),
    ];

    // --- TOOLS SECTION ---
    if (requiredTools.isNotEmpty) {
      children.add(_buildSectionTitle(l10n.toolsRequirements, Icons.brush));
      children.add(const SizedBox(height: 16));
      children.add(
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: (_translatedTools ?? requiredTools).map((tool) {
            String name = '';
            String iconKey = '';
            if (tool is Map) {
              name = tool['name'] ?? '';
              iconKey = tool['icon'] ?? 'generic';
            } else {
              name = tool.toString();
              iconKey = 'generic';
            }
            return _buildToolChip(name, iconKey);
          }).toList(),
        ),
      );
      children.add(const SizedBox(height: 32));
    }

    children.addAll([
      _buildSectionTitle(l10n.localeName == 'ar' ? 'نتائج التعلم' : 'Learning Outcomes', Icons.map),
      const SizedBox(height: 16),
      _buildCurriculumTimeline(),
    ]);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildScheduleTab() {
    final String locale = Localizations.localeOf(context).toString();
    final DateFormat dateFormatter = DateFormat.yMMMd(locale);
    final DateFormat timeFormatter = DateFormat.jm(locale);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn(
                          AppLocalizations.of(context)!.startDate,
                          startDate,
                          dateFormatter,
                          Icons.calendar_month_rounded,
                        ),
                        Container(
                          height: 50,
                          width: 1.5,
                          color: Colors.white12,
                        ),
                        _buildInfoColumn(
                          AppLocalizations.of(context)!.endDate,
                          endDate,
                          dateFormatter,
                          Icons.event_available_rounded,
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Divider(color: Colors.white10, thickness: 1.5),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn(
                          AppLocalizations.of(context)!.startTime,
                          selectedTime,
                          timeFormatter,
                          Icons.access_time_filled_rounded,
                        ),
                        Container(
                          height: 50,
                          width: 1.5,
                          color: Colors.white12,
                        ),
                        _buildInfoColumn(
                          AppLocalizations.of(context)!.endTime,
                          endTime,
                          timeFormatter,
                          Icons.update_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (selectedDays.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.sessionBreakdown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGold.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.totalClasses(totalSessions).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: sessionDates.entries.map((entry) {
                if (entry.value.isEmpty) return const SizedBox.shrink();
                final dayName = entry.key;
                final dates = entry.value;
                final isExpanded = expandedDay == dayName;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? AppColors.accentGold.withOpacity(0.05)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isExpanded
                          ? AppColors.accentGold.withOpacity(0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () => _toggleDayExpansion(dayName),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: isExpanded
                                ? AppColors.accentGold
                                : Colors.white54,
                          ),
                        ),
                        title: Text(
                          _getLocalizedDay(context, dayName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? AppColors.accentGold.withOpacity(0.1)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: isExpanded
                                ? AppColors.accentGold
                                : Colors.white30,
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: isExpanded
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: dates
                                        .map(
                                          (date) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.05,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.1),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 12,
                                                  color: AppColors.accentGold,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  dateFormatter.format(date),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _getLocalizedDay(BuildContext context, String day) {
    final l10n = AppLocalizations.of(context)!;
    switch (day) {
      case 'Sunday':
        return l10n.sunday;
      case 'Monday':
        return l10n.monday;
      case 'Tuesday':
        return l10n.tuesday;
      case 'Wednesday':
        return l10n.wednesday;
      case 'Thursday':
        return l10n.thursday;
      case 'Friday':
        return l10n.friday;
      case 'Saturday':
        return l10n.saturday;
      default:
        return day;
    }
  }

  Widget _buildGlassHeader(Color levelColor) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: levelColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    CourseUtils.getLocalizedLevel(
                      context,
                      courseLevel,
                    ).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _translatedName ?? courseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    fontFamily: 'Urbanist',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _localizeContent(String text) {
    final l10n = AppLocalizations.of(context)!;

    // 1. Normalize input (trim spaces)
    final trimmedText = text.trim();

    // 2. Define the lookup map (Reverse Mapping)
    // Key: Standard text in AR/EN/TR => Value: Localized string getter
    final Map<String, String> lookup = {
      // --- TOOLS ---
      // Bamboo Pen
      'Bamboo Pen': l10n.bambooPen,
      'Kamış Kalem': l10n.bambooPen,
      'قلم قصب (بامبو)': l10n.bambooPen,
      // Metal Nib
      'Metal Nib': l10n.metalNib,
      'Metal Uç': l10n.metalNib,
      'قلم معدني (Slater)': l10n.metalNib,
      'قلم معدني': l10n.metalNib,
      // Likka
      'Likka (Silk)': l10n.likkaSilk,
      'Lika (İpek)': l10n.likkaSilk,
      'ليقة (حرير)': l10n.likkaSilk,
      // Glossy Paper
      'Glossy Paper': l10n.glossyPaper,
      'Kuşe Kağıt': l10n.glossyPaper,
      'ورق مقهر (Lined/Glossy)': l10n.glossyPaper,
      'ورق مقهر': l10n.glossyPaper,
      // Ink
      'Ink': l10n.ink,
      'Mürekkep': l10n.ink,
      'حبر (Ecoline/Schmincke)': l10n.ink,
      'حبر': l10n.ink,
      // Ballpoint
      'Ballpoint Pen': l10n.ballpointPen,
      'Tükenmez Kalem': l10n.ballpointPen,
      'قلم جاف': l10n.ballpointPen,
      // Gel Pen
      'Gel Pen (0.5mm)': l10n.gelPen,
      'Jel Kalem (0.5mm)': l10n.gelPen,
      'قلم جل (0.5mm)': l10n.gelPen,
      // Notebook
      'Lined Notebook': l10n.linedNotebook,
      'Çizgili Defter': l10n.linedNotebook,
      'دفتر مسطر': l10n.linedNotebook,
      // Pencil/Eraser
      'Pencil & Eraser': l10n.pencilEraser,
      'Kurşun Kalem ve Silgi': l10n.pencilEraser,
      'قلم رصاص وممحاة': l10n.pencilEraser,
      // Correction Tape
      'Correction Tape': l10n.correctionTape,
      'Daksil': l10n.correctionTape,
      'مصحح (Correction Tape)': l10n.correctionTape,

      // --- CURRICULUM MODULES (Beginner Calligraphy) ---
      'Intro to Tools': l10n.introToTools,
      'Araçlara Giriş': l10n.introToTools,
      'مقدمة عن الأدوات': l10n.introToTools,
      'Holding the Pen': l10n.holdingThePen,
      'Kalem Tutuşu': l10n.holdingThePen,
      'طريقة مسك القلم': l10n.holdingThePen,
      'Dots (Nuqta)': l10n.dotsNuqta,
      'Noktalar (Mizan)': l10n.dotsNuqta,
      'النقط والميزان': l10n.dotsNuqta,
      'Letter Alif': l10n.letterAlif,
      'Elif Harfi': l10n.letterAlif,
      'حرف الألف': l10n.letterAlif,
      'Letters Ba-Ra': l10n.lettersBaRa,
      'Be-Ra Harfleri': l10n.lettersBaRa,
      'حروف الباء - الراء': l10n.lettersBaRa,

      // --- CURRICULUM MODULES (Intermediate Calligraphy) ---
      'Review Basics': l10n.reviewBasics,
      'Temellerin Gözden Geçirilmesi': l10n.reviewBasics,
      'مراجعة الأساسيات': l10n.reviewBasics,
      'Complex Connections': l10n.complexConnections,
      'Karmaşık Bağlantılar': l10n.complexConnections,
      'اتصالات الحروف المركبة': l10n.complexConnections,
      'Sentence Structure': l10n.sentenceStructure,
      'Cümle Yapısı': l10n.sentenceStructure,
      'tarkib (تركيب الجمل)': l10n.sentenceStructure,
      'تركيب الجمل': l10n.sentenceStructure,
      'Ink Control': l10n.inkControl,
      'Mürekkep Kontrolü': l10n.inkControl,
      'التحكم بالحبر': l10n.inkControl,

      // --- CURRICULUM MODULES (Advanced Calligraphy) ---
      'Composition Rules': l10n.compositionRules,
      'Kompozisyon Kuralları': l10n.compositionRules,
      'قواعد التكوين': l10n.compositionRules,
      'Jali (Large Scale)': l10n.jaliLargeScale,
      'Celi (Büyük Ölçekli)': l10n.jaliLargeScale,
      'الكتابة الجلية (Jali)': l10n.jaliLargeScale,
      'Gold Leaf': l10n.goldLeaf,
      'Altın Varak': l10n.goldLeaf,
      'التذهيب (Gold Leaf)': l10n.goldLeaf,
      'Masterpiece Creation': l10n.masterpieceCreation,
      'Eser Oluşturma': l10n.masterpieceCreation,
      'إنجاز اللوحة النهائية': l10n.masterpieceCreation,

      // --- CURRICULUM MODULES (Beginner Handwriting) ---
      'Hand Posture': l10n.handPosture,
      'El Duruşu': l10n.handPosture,
      'وضعية اليد والجلوس': l10n.handPosture,
      'Paper Position': l10n.paperPosition,
      'Kağıt Pozisyonu': l10n.paperPosition,
      'وضعية الورقة': l10n.paperPosition,
      'Basic Shapes': l10n.basicShapes,
      'Temel Şekiller': l10n.basicShapes,
      'الأشكال الأساسية': l10n.basicShapes,
      'Lowercase a-m': l10n.lowercaseAM,
      'Küçük Harfler a-m': l10n.lowercaseAM,
      'الحروف الصغيرة a-m': l10n.lowercaseAM,
      'Lowercase n-z': l10n.lowercaseNZ,
      'Küçük Harfler n-z': l10n.lowercaseNZ,
      'الحروف الصغيرة n-z': l10n.lowercaseNZ,

      // --- CURRICULUM MODULES (Intermediate Handwriting) ---
      'Connecting Letters': l10n.connectingLetters,
      'Harf Bağlantıları': l10n.connectingLetters,
      'وصل الحروف': l10n.connectingLetters,
      'Word Spacing': l10n.wordSpacing,
      'Kelime Boşlukları': l10n.wordSpacing,
      'المسافات بين الكلمات': l10n.wordSpacing,
      'Line Consistency': l10n.lineConsistency,
      'Satır Tutarlılığı': l10n.lineConsistency,
      'الاستقامة على السطر': l10n.lineConsistency,
      'Speed Writing': l10n.speedWriting,
      'Hızlı Yazma': l10n.speedWriting,
      'الكتابة السريعة': l10n.speedWriting,

      // --- CURRICULUM MODULES (Advanced Handwriting) ---
      'Cursive Style': l10n.cursiveStyle,
      'Bitişik El Yazısı Stili': l10n.cursiveStyle,
      'الكتابة المتصلة (Cursive)': l10n.cursiveStyle,
      'Signature Design': l10n.signatureDesign,
      'İmza Tasarımı': l10n.signatureDesign,
      'تصميم التوقيع': l10n.signatureDesign,
      'Fountain Pen Basics': l10n.fountainPenBasics,
      'Dolma Kalem Temelleri': l10n.fountainPenBasics,
      'أساسيات قلم الحبر السائل': l10n.fountainPenBasics,
      'Business Handwriting': l10n.businessHandwriting,
      'İş El Yazısı': l10n.businessHandwriting,
      'الكتابة الرسمية للأعمال': l10n.businessHandwriting,

      // --- LEGACY / THULUTH DEFAULTS ---
      'Intro to Thuluth': l10n.introToThuluth,
      'Sülüs\'e Giriş': l10n.introToThuluth,
      'مقدمة في خط الثلث': l10n.introToThuluth,
      'Letter Alif & Baa': l10n.letterAlifBaa,
      'Elif ve Ba Harfleri': l10n.letterAlifBaa,
      'حرف الألف والباء': l10n.letterAlifBaa,
      'Joint Letters': l10n.jointLetters,
      'Bitişik Harfler': l10n.jointLetters,
      'الحروف المتصلة': l10n.jointLetters,
      'Sentences': l10n.sentences,
      'Cümleler': l10n.sentences,
      'كتابة الجمل': l10n.sentences,
      'Final Project': l10n.finalProject,
      'Final Projesi': l10n.finalProject,
      'المشروع النهائي': l10n.finalProject,
    };

    return lookup[trimmedText] ?? text;
  }

  String _localizeDescription(String text) {
    if (text.isEmpty) return text;
    final l10n = AppLocalizations.of(context)!;
    final t = text.trim();

    // writingType logic from widget.courseData
    final wType = (widget.courseData['writingType'] as String? ?? "").trim();
    final cStyle = (widget.courseData['calligraphyStyle'] as String? ?? "")
        .trim();

    // Standard Description Substring Checks
    // We check for unique phrases from the Standard Descriptions in AR/EN/TR
    bool contains(List<String> fragments) {
      for (final f in fragments) {
        if (t.contains(f)) return true;
      }
      return false;
    }

    // --- NORMAL PEN WRITING ---
    if ([
      "Normal Pen Writing",
      "Normal Kalem Yazısı",
      "الكتابة بالقلم العادي",
    ].contains(wType)) {
      // Beginner Normal
      if (contains([
        "Transform your handwriting",
        "El yazınızı sıfırdan",
        "حول خط يدك من الصفر",
      ])) {
        return l10n.beginnerDescriptionNormal;
      }
      // Intermediate Normal
      if (contains([
        "Unlock the next level",
        "sonraki seviyenin kilidini",
        "افتح المستوى التالي",
      ])) {
        return l10n.intermediateDescriptionNormal;
      }
      // Advanced Normal
      if (contains([
        "Master the finest details",
        "en ince detaylarında",
        "أتقن أدق تفاصيل",
      ])) {
        return l10n.advancedDescriptionNormal;
      }
    }
    // --- CALLIGRAPHY ---
    else {
      // Reuse logic from _getLocalizedCourseName (simplified)
      String localizedStyle = cStyle;
      if (['Thuluth', 'Sülüs', 'الثلث'].contains(cStyle)) {
        localizedStyle = l10n.thuluth;
      } else if (['Naskh', 'Nesih', 'النسخ'].contains(cStyle)) {
        localizedStyle = l10n.naskh;
      } else if (['Diwani', 'Divani', 'الديواني'].contains(cStyle)) {
        localizedStyle = l10n.diwani;
      } else if (['Kufi', 'Kufic', 'الكوفي', 'كوفي'].contains(cStyle)) {
        localizedStyle = l10n.kufi;
      } else if ([
        'Ruq\'ah',
        'Ruqah',
        'Rika',
        'الرقعة',
        'رقعة',
      ].contains(cStyle)) {
        localizedStyle = l10n.ruqah;
      } else if (['Jali Thuluth', 'Celi Sülüs', 'ثلث جلي'].contains(cStyle)) {
        localizedStyle = l10n.jaliThuluth;
      } else if ([
        'Jali Diwani',
        'Celi Divani',
        'ديواني جلي',
      ].contains(cStyle)) {
        localizedStyle = l10n.jaliDiwani;
      } else if ([
        'Persian (Ta\'liq)',
        'Nestalik (Farsça)',
        'نستعليق (فارسي)',
      ].contains(cStyle)) {
        localizedStyle = l10n.persianTaliq;
      } else if (['Ijaza', 'İcazet', 'إجازة'].contains(cStyle)) {
        localizedStyle = l10n.ijaza;
      } else if (['Muhaqqaq', 'Muhakkak', 'محقق'].contains(cStyle)) {
        localizedStyle = l10n.muhaqqaq;
      } else if (['Rayhani', 'Reyhani', 'ريحاني'].contains(cStyle)) {
        localizedStyle = l10n.rayhani;
      } else {
        localizedStyle = l10n.arabicCalligraphy;
      }

      // Beginner Calligraphy
      if (contains([
        "Embark on your journey",
        "yolculuğunuza başlayın",
        "ابدأ رحلتك في خط",
      ])) {
        return l10n.beginnerDescriptionCalligraphy(localizedStyle);
      }
      // Intermediate Calligraphy
      if (contains([
        "Expand your artistic capabilities",
        "yeteneklerinizi genişletin",
        "وسع قدراتك الفنية",
      ])) {
        return l10n.intermediateDescriptionCalligraphy(localizedStyle);
      }
      // Advanced Calligraphy
      if (contains([
        "Attain the highest level",
        "seviyesine ulaşın",
        "أعلى مستويات المهارة",
      ])) {
        return l10n.advancedDescriptionCalligraphy(localizedStyle);
      }
    }

    return text; // Return original if no standard template detected
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

  Widget _buildClassroomTab() {
    final bool isTeacher = userRole == 'teacher';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDynamicSchedulingCard(),
          const SizedBox(height: 32),
          _buildTeacherMessageCard(),
          const SizedBox(height: 32),
          _buildSectionTitle(
            isTeacher
                ? AppLocalizations.of(context)!.toolsRequirements
                : AppLocalizations.of(context)!.assignments,
            isTeacher
                ? Icons.auto_awesome_mosaic_rounded
                : Icons.folder_special_rounded,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (isTeacher) ...[
                Expanded(
                  child: _buildActionCard(
                    title: AppLocalizations.of(context)!.announcements,
                    subtitle: AppLocalizations.of(context)!.classBoard,
                    icon: Icons.campaign_rounded,
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnnouncementsBoardPage(
                          courseId: widget.courseId,
                          courseName: courseName,
                          isTeacher: isTeacher,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: _buildActionCard(
                  title: isTeacher
                      ? AppLocalizations.of(context)!.assignments
                      : AppLocalizations.of(context)!.myAssignments,
                  subtitle: isTeacher
                      ? AppLocalizations.of(context)!.submissions
                      : AppLocalizations.of(
                          context,
                        )!.submitYourWork, // New subtitle for student
                  icon: Icons.folder_special_rounded,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignmentsPage(
                        courseId: widget.courseId,
                        isTeacher: isTeacher,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isTeacher) ...[
            const SizedBox(height: 40),
            const SizedBox(height: 8),
            Text(
              "View and manage your enrolled students.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            _buildEnrolledStudentsList(),
          ],
        ],
      ),
    );
  }

  void _listenToOverrides() {
    FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _rescheduledData = data['rescheduledSession'];
          _teacherStatusMessage = data['teacherStatusMessage'];
        });
      }
    });
  }

  Widget _buildDynamicSchedulingCard() {
    final bool isTeacher = userRole == 'teacher';
    final hasReschedule = _rescheduledData != null;

    if (!isTeacher && !hasReschedule) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hasReschedule
            ? Colors.orangeAccent.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: hasReschedule
              ? Colors.orangeAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_send_rounded,
                color: hasReschedule ? Colors.orangeAccent : Colors.white60,
              ),
              const SizedBox(width: 12),
              Text(
                hasReschedule ? "SESSION RESCHEDULED" : "TODAY'S SCHEDULE",
                style: TextStyle(
                  color: hasReschedule ? Colors.orangeAccent : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasReschedule) ...[
            Text(
              "The teacher has moved today's session.",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "New Time: ${DateFormat.jm().format((_rescheduledData!['newStartTime'] as Timestamp).toDate())}",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ] else
            const Text(
              "Session is on time as planned.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          if (isTeacher) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showRescheduleDialog,
                icon: Icon(
                  hasReschedule ? Icons.edit_calendar : Icons.more_time,
                  size: 18,
                ),
                label: _isSavingReschedule 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        hasReschedule ? "Update Reschedule" : "Reschedule Today",
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasReschedule ? Colors.orangeAccent : AppColors.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            if (hasReschedule)
              TextButton(
                onPressed: _cancelReschedule,
                child: const Text(
                  "Cancel Reschedule",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeacherMessageCard() {
    final bool isTeacher = userRole == 'teacher';
    if (!isTeacher && (_teacherStatusMessage == null || _teacherStatusMessage!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accentGold),
              SizedBox(width: 12),
              Text(
                "TEACHER'S MESSAGE",
                style: TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _teacherStatusMessage ?? "No message from the teacher for today.",
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
          if (isTeacher) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _showTeacherMessageDialog,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text("Update Message"),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentGold,
                  backgroundColor: AppColors.accentGold.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRescheduleDialog() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedTime ?? DateTime.now()),
    );

    if (picked != null) {
      final now = DateTime.now();
      final newStartTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      // Assume 1 hour session for simplicity in this mockup or pick end time too
      final newEndTime = newStartTime.add(const Duration(hours: 1));

      setState(() => _isSavingReschedule = true);
      try {
        await FirebaseFirestore.instance.collection('courses').doc(widget.courseId).update({
          'rescheduledSession': {
            'originalDate': Timestamp.fromDate(now), // Effectively today
            'newStartTime': Timestamp.fromDate(newStartTime),
            'newEndTime': Timestamp.fromDate(newEndTime),
          }
        });
        _showMessage("Success", "Session rescheduled. Students will see the update.", MessengerType.success);
      } catch (e) {
        _showMessage("Error", "Failed to reschedule: $e", MessengerType.error);
      }
      setState(() => _isSavingReschedule = false);
    }
  }

  Future<void> _cancelReschedule() async {
    setState(() => _isSavingReschedule = true);
    try {
      await FirebaseFirestore.instance.collection('courses').doc(widget.courseId).update({
        'rescheduledSession': FieldValue.delete(),
      });
      _showMessage("Cancelled", "Session is back to original schedule.", MessengerType.info);
    } catch (e) {
      _showMessage("Error", "Failed to cancel: $e", MessengerType.error);
    }
    setState(() => _isSavingReschedule = false);
  }

  Future<void> _showTeacherMessageDialog() async {
    final controller = TextEditingController(text: _teacherStatusMessage);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: const Text("Teacher Status Message", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g. I will be 15 mins late. Please review the previous lesson.",
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('courses').doc(widget.courseId).update({
                'teacherStatusMessage': controller.text,
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentGold, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildToolChip(String label, String iconKey) {
    final Map<String, IconData> iconRegistry = {
      'brush': Icons.brush,
      'pen': Icons.create,
      'paper': Icons.article,
      'ink': Icons.water_drop,
      'generic': Icons.check_circle_outline,
      'star': Icons.star,
      'build': Icons.build,
      'palette': Icons.palette,
      'hand': Icons.front_hand,
      'book': Icons.book,
      'school': Icons.assignment_ind,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconRegistry[iconKey] ?? Icons.check_circle_outline,
                  color: AppColors.accentGold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _localizeContent(label),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Urbanist',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurriculumTimeline() {
    final modules =
        _translatedCurriculum ??
        (curriculumSteps.isNotEmpty
            ? curriculumSteps
            : [
                AppLocalizations.of(context)!.introToThuluth,
                AppLocalizations.of(context)!.letterAlifBaa,
                AppLocalizations.of(context)!.jointLetters,
                AppLocalizations.of(context)!.sentences,
                AppLocalizations.of(context)!.finalProject,
              ]);
    return Column(
      children: List.generate(modules.length, (index) {
        final isLast = index == modules.length - 1;
        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.accentGold.withOpacity(0.5),
                              Colors.white10,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.module(index + 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _localizeContent(modules[index]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Urbanist',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 150,
      ), // Changed from fixed height to minHeight and slightly increased
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withOpacity(0.1),
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ), // Reduced horizontal padding slightly
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min, // Allow column to be as small as possible
              children: [
                Container(
                  padding: const EdgeInsets.all(10), // Reduced from 12
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24, // Reduced from 28
                  ),
                ),
                const SizedBox(
                  height: 20,
                ), // Explicit spacing instead of Spacer
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18, // Reduced from 20
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11, // Reduced from 12
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    DateTime? date,
    DateFormat formatter,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            date != null
                ? formatter.format(date)
                : AppLocalizations.of(context)!.notAvailableShort,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledStudentsList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox();
        if (!snapshot.hasData) return const SizedBox();
        final courseData = snapshot.data!.data() as Map<String, dynamic>?;
        if (courseData == null) return const SizedBox();
        final dynamic studentsRaw = courseData['enrolledStudents'];
        final List<String> enrolledStudentIds = (studentsRaw is List)
            ? List<String>.from(studentsRaw.whereType<String>())
            : [];

        if (enrolledStudentIds.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.person_outline, color: Colors.white24, size: 32),
                SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.noStudentsEnrolledYet,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          );
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchStudentDetails(enrolledStudentIds),
          builder: (context, studentDetailsSnapshot) {
            if (!studentDetailsSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              );
            }
            final students = studentDetailsSnapshot.data!;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final student = students[index];
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PublicStudentProfilePage(userId: student['uid']),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'student_pic_${student['uid']}',
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentGold.withOpacity(
                                    0.3,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child:
                                    (student['profilePic'] != null &&
                                        student['profilePic']
                                            .toString()
                                            .isNotEmpty)
                                    ? SmartImage(
                                        imageUrl: student['profilePic'],
                                        fit: BoxFit.cover,
                                        placeholder: Container(
                                          color: AppColors.accentGold
                                              .withOpacity(0.1),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.accentGold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: _buildDefaultAvatar(
                                          student['name'],
                                        ),
                                      )
                                    : _buildDefaultAvatar(student['name']),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        student['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  student['email'] ?? 'No Email',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                                if (student['createdAt'] != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 10,
                                        color: AppColors.accentGold.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${AppLocalizations.of(context)!.studentSince} ${DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(student['createdAt'])}",
                                        style: TextStyle(
                                          color: AppColors.accentGold
                                              .withOpacity(0.6),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildDefaultAvatar(String? name) {
    return Container(
      color: AppColors.accentGold,
      child: Center(
        child: Text(
          (name ?? 'U')[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchStudentDetails(
    List<String> studentIds,
  ) async {
    if (studentIds.isEmpty) return [];
    const int batchSize = 10;
    List<Future<QuerySnapshot>> futures = [];
    for (int i = 0; i < studentIds.length; i += batchSize) {
      final List<String> batch = studentIds.sublist(
        i,
        (i + batchSize > studentIds.length) ? studentIds.length : i + batchSize,
      );
      futures.add(
        FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get(),
      );
    }
    final l10n = AppLocalizations.of(context)!;
    List<QuerySnapshot> snapshots = await Future.wait(futures);
    List<Map<String, dynamic>> students = [];
    for (var snapshot in snapshots) {
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        students.add({
          'uid': doc.id,
          'name': data['fullName'] ?? data['name'] ?? l10n.unknownStudent,
          'email': data['email'] ?? l10n.noEmail,
          'profilePic': data['photoUrl'] ?? data['profilePic'],
          'createdAt': (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        });
      }
    }
    return students;
  }

  void _showMessage(String title, String msg, MessengerType type) {
    if (!mounted) return;
    AppMessenger.showSnackBar(context, title: title, message: msg, type: type);
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
