import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:cloud_functions/cloud_functions.dart';

// -------------------------------------------------------------------------
// ----------------- COURSE SUMMARY PAGE (UPDATED UI) ----------------------
// -------------------------------------------------------------------------

class CourseSummaryPage extends StatefulWidget {
  final String courseName;
  final String teacherId;
  final String teacherName;
  final String teacherProfilePic;
  final String courseBanner; // Added banner
  final String courseType;
  final String ageCategory;
  final int maxStudents;
  final String courseDescription;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final String selectedTimeFormatted;
  final String selectedEndTimeFormatted;
  final List<String> selectedDays;
  final List<Map<String, dynamic>> requiredTools;
  final List<String> curriculumSteps;
  final double price;

  final Future<void> Function(Map<String, String>) onFinish;
  final VoidCallback onBack;

  const CourseSummaryPage({
    super.key,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.teacherProfilePic,
    required this.courseBanner, // Added to constructor
    required this.courseType,
    required this.ageCategory,
    required this.maxStudents,
    required this.courseDescription,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.selectedTimeFormatted,
    required this.selectedEndTimeFormatted,
    required this.selectedDays,
    required this.requiredTools,
    required this.curriculumSteps,
    required this.price,
    required this.onFinish,
    required this.onBack,
  });

  @override
  _CourseSummaryPageState createState() => _CourseSummaryPageState();
}

class _CourseSummaryPageState extends State<CourseSummaryPage> {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  Map<String, String>? classroomData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _triggerMeetGeneration();
  }

  void _showMessage(String title, String msg, MessengerType type) {
    if (!mounted) return;
    AppMessenger.showSnackBar(context, title: title, message: msg, type: type);
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

  String _getLocalizedAgeCategory(BuildContext context, String age) {
    final locale = Localizations.localeOf(context).languageCode;
    if (age == '7-10') {
      if (locale == 'ar') return '7-10 سنوات';
      if (locale == 'tr') return '7-10 Yaş Arası';
      return '7-10 Years Old';
    } else if (age == '11-16') {
      if (locale == 'ar') return '11-16 سنة';
      if (locale == 'tr') return '11-16 Yaş Arası';
      return '11-16 Years Old';
    } else if (age == '17+') {
      if (locale == 'ar') return '17+ سنة';
      if (locale == 'tr') return '17+ Yaş';
      return '17+ Years Old';
    }
    return age;
  }

  String _getLocalizedCourseType(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context)!;
    // Map Level Keys (which are passed as 'Type' in this context)
    if (type == 'Beginner') return l10n.beginner;
    if (type == 'Intermediate') return l10n.intermediate;
    if (type == 'Advanced') return l10n.advanced;

    // Retain mapping for Style names if they appear
    if (type == "Normal Pen Writing") return l10n.normalPenWriting;
    if (type == "Arabic Calligraphy") return l10n.arabicCalligraphy;

    switch (type) {
      case "Naskh":
        return l10n.naskh;
      case "Kufi":
        return l10n.kufi;
      case "Thuluth":
        return l10n.thuluth;
      case "Diwani":
        return l10n.diwani;
      case "Ruq'ah":
        return l10n.ruqah;
      case "Maghribi":
        return l10n.maghribi;
      case "Jali Thuluth":
        return l10n.jaliThuluth;
      case "Jali Diwani":
        return l10n.jaliDiwani;
      case "Persian (Ta'liq)":
        return l10n.persianTaliq;
      case "Muhaqqaq":
        return l10n.muhaqqaq;
      case "Rayhani":
        return l10n.rayhani;
      default:
        return type;
    }
  }

  Future<void> _triggerMeetGeneration() async {
    if (classroomData != null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final result = await _functions
          .httpsCallable('createCalligroClassroom')
          .call({'courseName': widget.courseName});

      final data = Map<String, dynamic>.from(result.data as Map);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (data['link'] != null) {
            classroomData = {
              'link': data['link'].toString(),
              'id': data['id']?.toString() ?? '',
              'password': data['password']?.toString() ?? '', // Capture password
            };
          } else {
            classroomData = null;
            _showMessage(
              AppLocalizations.of(context)!.error,
              AppLocalizations.of(context)!.failedToGenerateLink,
              MessengerType.error,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          classroomData = null;
          _isLoading = false;
        });
        _showMessage(
          AppLocalizations.of(context)!.error,
          "${AppLocalizations.of(context)!.error}: $e",
          MessengerType.error,
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final bool canFinish = !_isLoading && classroomData != null;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // --- PREVIEW HEADER ---
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    image: DecorationImage(
                      image: AssetImage(widget.courseBanner),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 20,
                          right: 20,
                          child: InkWell(
                            onTap: _showCoursePreview,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.remove_red_eye_rounded,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.preview.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 24,
                          right: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.courseName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildTopBadge(
                                    _getLocalizedCourseType(
                                      context,
                                      widget.courseType,
                                    ),
                                    AppColors.accentGold.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTopBadge(
                                    _getLocalizedAgeCategory(
                                      context,
                                      widget.ageCategory,
                                    ),
                                    Colors.orangeAccent.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTopBadge(
                                    "\$${widget.price}",
                                    Colors.white.withOpacity(0.2),
                                    isGlass: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- QUICK STATS GRID ---
                Row(
                  children: [
                    _buildGridCard(
                      icon: Icons.group_rounded,
                      label: AppLocalizations.of(context)!.maxStudents,
                      value: "${widget.maxStudents}",
                      accentColor: Colors.blueAccent,
                    ),
                    const SizedBox(width: 12),
                    _buildGridCard(
                      icon: Icons.timer_rounded,
                      label: AppLocalizations.of(context)!.time,
                      value: widget
                          .selectedTimeFormatted, // No longer splitting, show fullAM/PM
                      accentColor: Colors.purpleAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- CALLIGRO CLASSROOM CARD ---
                _buildClassroomCard(),
                const SizedBox(height: 32),

                // --- TEACHER CARD ---
                _buildSectionHeader(AppLocalizations.of(context)!.teacher),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentGold.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white12,
                          backgroundImage: widget.teacherProfilePic.isNotEmpty
                              ? NetworkImage(widget.teacherProfilePic)
                              : null,
                          child: widget.teacherProfilePic.isEmpty
                              ? const Icon(Icons.person, color: Colors.white54)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.teacherName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- DESCRIPTION SECTION ---
                _buildSectionHeader(AppLocalizations.of(context)!.details),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.courseDescription,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- SCHEDULE SECTION ---
                _buildSectionHeader(AppLocalizations.of(context)!.schedule),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            _buildScheduleItem(
                              Icons.calendar_month_rounded,
                              AppLocalizations.of(context)!.startDate,
                              _formatDate(widget.startDate),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white12,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                            _buildScheduleItem(
                              Icons.event_available_rounded,
                              AppLocalizations.of(context)!.endDate,
                              _formatDate(widget.endDate),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        color: Colors.white12,
                        height: 1,
                        indent: 24,
                        endIndent: 24,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            _buildScheduleItem(
                              Icons.access_time_filled_rounded,
                              AppLocalizations.of(context)!.time,
                              "${widget.selectedTimeFormatted} - ${widget.selectedEndTimeFormatted}",
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white12,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                            _buildScheduleItem(
                              Icons.repeat_on_rounded,
                              AppLocalizations.of(context)!.days,
                              widget.selectedDays
                                  .map((d) => _getLocalizedDay(context, d))
                                  .join(", "),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- CURRICULUM SECTION ---
                if (widget.curriculumSteps.isNotEmpty) ...[
                  _buildSectionHeader(
                    AppLocalizations.of(context)!.localeName == 'ar' ? 'نتائج التعلم' : 'Learning Outcomes',
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: widget.curriculumSteps.length,
                      itemBuilder: (context, index) {
                        return _buildCurriculumTimelineItem(
                          index,
                          widget.curriculumSteps[index],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // --- TOOLS SECTION ---
                if (widget.requiredTools.isNotEmpty) ...[
                  _buildSectionHeader(
                    AppLocalizations.of(context)!.toolsRequirements,
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: widget.requiredTools.map((tool) {
                      return _buildToolSummaryChip(tool['name'], tool['icon']);
                    }).toList(),
                  ),
                  const SizedBox(height: 48),
                ],

                // --- FINAL ACTIONS ---
                SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: widget.onBack,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            backgroundColor: Colors.white.withOpacity(0.05),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.edit,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              if (canFinish)
                                BoxShadow(
                                  color: AppColors.accentGold.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: canFinish
                                ? () async {
                                    setState(() => _isLoading = true);
                                    await widget.onFinish(classroomData!);
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.confirmAndPost.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER BUILDERS ---

  Widget _buildTopBadge(String text, Color color, {bool isGlass = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: isGlass ? Border.all(color: Colors.white24) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isGlass ? Colors.white : Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoursePreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.stars_rounded,
              color: AppColors.accentGold,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.preview,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "This is how your course will look to students. All details are set and ready for publication!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Got it",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.accentGold,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded, // Gold Star/Classroom icon
                  color: AppColors.accentGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Calligro Classroom", // Branded Name
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Secured Branded AI Engine",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGold),
              minHeight: 3,
              borderRadius: BorderRadius.circular(10),
            )
          else if (classroomData != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.2),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Classroom Ready",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton.icon(
              onPressed: _triggerMeetGeneration,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Retry"),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white30, size: 14),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumTimelineItem(int index, String text) {
    bool isLast = index == widget.curriculumSteps.length - 1;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: Colors.white10)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolSummaryChip(String label, String iconKey) {
    final Map<String, IconData> iconRegistry = {
      'brush': Icons.brush_rounded,
      'pen': Icons.edit_rounded,
      'paper': Icons.description_rounded,
      'ink': Icons.water_drop_rounded,
      'ruler': Icons.straighten_rounded,
      'book': Icons.menu_book_rounded,
      'laptop': Icons.laptop_rounded,
      'generic': Icons.check_circle_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconRegistry[iconKey] ?? Icons.check_circle_outline_rounded,
            color: AppColors.accentGold,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
