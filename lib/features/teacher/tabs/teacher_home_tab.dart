import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import '../../../../core/theme/colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'dart:ui';
import '../pages/add_course/add_course_dashboard.dart';
import '../pages/settings/payout_settings_page.dart';
import '../pages/finance/teacher_finance_page.dart';
import '../../student/pages/gallery_page.dart';
import '../../../core/widgets/auto_translated_text.dart';
import '../pages/course_details/course_details_page.dart';
import '../pages/notifications/notifications_page.dart';

// --- HELPER WIDGETS ---

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.cardBackground,
              AppColors.cardBackground.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accentGold, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.textLight, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color bgColor;
  final Color fgColor;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.bgColor = AppColors.cardBackground,
    this.fgColor = AppColors.textLight,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: bgColor == AppColors.cardBackground
              ? Border.all(color: Colors.white10)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fgColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// --- MAIN PAGE ---

class TeacherHomeTab extends StatefulWidget {
  final void Function(int, {String? successMessage}) onNavigate;
  final String userName;
  final String userProfileImage;
  final int courseCount;
  final bool hasPayoutInfo;

  const TeacherHomeTab({
    super.key,
    required this.onNavigate,
    required this.userName,
    required this.userProfileImage,
    required this.courseCount,
    required this.hasPayoutInfo,
  });

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _localProfileImage;
  Stream<DocumentSnapshot>? _userStream;
  Stream<QuerySnapshot>? _coursesStream;
  late PageController _heroPageController;

  static bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController();
    _initStreams();
  }

  @override
  void dispose() {
    _heroPageController.dispose();
    super.dispose();
  }

  void _initStreams() {
    if (currentUserId.isNotEmpty) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .snapshots();
      _coursesStream = FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: currentUserId)
          .snapshots();
    }
  }

  bool _isActiveOrUpcoming(DateTime? endDate) {
    if (endDate == null) return false;
    return endDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // ✅ CHANGED: Completely disabled blocking screen to force dashboard access
    // if (!_termsAccepted) {
    //   return _buildBlockingScreen();
    // }

    // --- ANIMATION LOGIC START ---
    final bool shouldAnimate = !_hasAnimated;
    if (shouldAnimate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasAnimated = true;
      });
    }
    // --- ANIMATION LOGIC END ---

    return SafeArea(
      // 1. First Stream: Listen to USER changes (Name, Photo)
      child: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          // --- LIVE USER DATA ---
          String liveName = widget.userName;
          String livePhotoUrl = _localProfileImage ?? widget.userProfileImage;

          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            if (userData['name'] != null) liveName = userData['name'];
            if (userData['photoUrl'] != null) {
              livePhotoUrl = userData['photoUrl'];
            }
          }

          // 2. Second Stream: Listen to COURSES
          return StreamBuilder<QuerySnapshot>(
            stream: _coursesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accentGold),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              int liveCourseCount = 0;
              int totalActiveStudents = 0;
              double totalEarnings = 0.0;

              List<Map<String, dynamic>> scheduleList = [];
              final now = DateTime.now();


              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;

                // --- EARNINGS CALCULATION ---
                final double price = (data['price'] ?? 0.0).toDouble();
                final int count =
                    data['enrolledCount'] ??
                    (data['enrolledStudents'] as List?)?.length ??
                    0;
                final double totalCourseRevenue = price * count;
                final double teacherShare = totalCourseRevenue * 0.65;

                totalEarnings += teacherShare;

                DateTime? endDate;
                if (data['endDate'] != null) {
                  endDate = (data['endDate'] is Timestamp)
                      ? (data['endDate'] as Timestamp).toDate().toLocal()
                      : null;
                }

                if (_isActiveOrUpcoming(endDate)) {
                  liveCourseCount++;
                  if (data['enrolledStudents'] is List) {
                    totalActiveStudents +=
                        (data['enrolledStudents'] as List).length;
                  } else {
                    totalActiveStudents +=
                        (data['studentsEnrolled'] as int? ?? 0);
                  }

                  DateTime? startDate = (data['startDate'] is Timestamp)
                      ? (data['startDate'] as Timestamp).toDate().toLocal()
                      : null;
                  DateTime? timeOnly = (data['selectedTime'] is Timestamp)
                      ? (data['selectedTime'] as Timestamp).toDate().toLocal()
                      : null;
                  DateTime? finalClassTime;

                  if (startDate != null && timeOnly != null) {
                    finalClassTime = DateTime(
                      startDate.year,
                      startDate.month,
                      startDate.day,
                      timeOnly.hour,
                      timeOnly.minute,
                    );
                  } else {
                    finalClassTime = startDate ?? timeOnly;
                  }

                  if (finalClassTime != null) {
                    while (finalClassTime!.isBefore(
                      now.subtract(const Duration(minutes: 90)),
                    )) {
                      finalClassTime = finalClassTime.add(
                        const Duration(days: 7),
                      );
                    }
                    if (endDate != null &&
                        finalClassTime.isBefore(
                          endDate.add(const Duration(days: 1)),
                        )) {
                      scheduleList.add({
                        'data': data,
                        'time': finalClassTime,
                        'id': doc.id,
                      });
                    }
                  }
                }
              }

              scheduleList.sort(
                (a, b) =>
                    (a['time'] as DateTime).compareTo(b['time'] as DateTime),
              );


              // --- WIDGETS ---

              // --- UPDATED HEADER WITH NOTIFICATION CONTAINER ---
              Widget headerWidget = Row(
                children: [
                  GestureDetector(
                    onTap: () => widget.onNavigate(3),
                    child: ProfileAvatar(imageUrl: livePhotoUrl, radius: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.welcomeName(liveName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.teachBeautiful,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification Button in Container
                  Container(
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
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );

              Widget statsWidget = Row(
                children: [
                  StatCard(
                    icon: Icons.assignment_ind,
                    value: liveCourseCount.toString(),
                    label: l10n.activeCourses,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    icon: Icons.groups,
                    value: totalActiveStudents.toString(),
                    label: l10n.activeStudents,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    icon: Icons.account_balance_wallet,
                    value: "\$${totalEarnings.toStringAsFixed(0)}",
                    label: l10n.earnings,
                  ),
                ],
              );

              Widget happeningText = Text(
                l10n.happeningNext,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              );

              Widget focusCard;
              if (scheduleList.isNotEmpty) {
                focusCard = Column(
                  children: [
                    SizedBox(
                      height:
                          350, // Reduced from 380 to make it slightly smaller
                      child: PageView.builder(
                        controller: _heroPageController,
                        itemCount: scheduleList.length,
                        itemBuilder: (context, index) {
                          final course = scheduleList[index];
                          final bool courseIsLive =
                              (course['time'] as DateTime)
                                      .difference(now)
                                      .inMinutes >
                                  -90 &&
                              (course['time'] as DateTime)
                                      .difference(now)
                                      .inMinutes <
                                  30;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: _buildDynamicFocusCard(
                              context,
                              course['id'], // Pass the ID separately
                              course['data'],
                              course['time'],
                              courseIsLive,
                              shouldAnimate,
                            ),
                          );
                        },
                      ),
                    ),
                    if (scheduleList.length > 1) ...[
                      const SizedBox(height: 12),
                      _buildPageIndicator(scheduleList.length),
                    ],
                  ],
                );
              } else {
                focusCard = _buildRelaxCard(context);
              }

              Widget quickActionsText = Text(
                l10n.quickActions,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              );

              List<Widget> quickActionButtons = [
                QuickActionButton(
                  icon: Icons.add_circle_outline,
                  label: l10n.newCourse,
                  bgColor: AppColors.accentGold,
                  fgColor: Colors.black,
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddCourseDashboardPage(),
                      ),
                    );
                    if (result == true && context.mounted) {
                      widget.onNavigate(
                        1,
                        successMessage: AppLocalizations.of(
                          context,
                        )!.coursePublished,
                      );
                    }
                  },
                ),
                QuickActionButton(
                  icon: Icons.attach_money,
                  label: l10n.finance,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TeacherFinancePage(),
                      ),
                    );
                  },
                ),
                QuickActionButton(
                  icon: Icons.dashboard_outlined,
                  label: l10n.manageCourses,
                  onPressed: () => widget.onNavigate(1),
                ),
                QuickActionButton(
                  icon: Icons.image_outlined,
                  label: l10n.gallery,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GalleryPage(),
                    ),
                  ),
                ),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header
                    shouldAnimate
                        ? headerWidget
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slideY(begin: -0.2, end: 0)
                        : headerWidget,

                    const SizedBox(height: 24),

                    if (!widget.hasPayoutInfo) _buildPayoutWarning(context),

                    const SizedBox(height: 24),
                    shouldAnimate
                        ? statsWidget
                              .animate()
                              .fadeIn(delay: 200.ms, duration: 600.ms)
                              .slideX(begin: -0.1, end: 0)
                        : statsWidget,

                    const SizedBox(height: 32),

                    // 3. Happening Next Text
                    shouldAnimate
                        ? happeningText.animate().fadeIn(delay: 300.ms)
                        : happeningText,

                    const SizedBox(height: 16),

                    // 4. Focus Card
                    shouldAnimate
                        ? focusCard
                              .animate()
                              .fadeIn(delay: 400.ms, duration: 600.ms)
                              .scale(
                                begin: const Offset(0.95, 0.95),
                                end: const Offset(1, 1),
                              )
                        : focusCard,

                    const SizedBox(height: 32),

                    // 5. Quick Actions Text
                    shouldAnimate
                        ? quickActionsText.animate().fadeIn(delay: 500.ms)
                        : quickActionsText,

                    const SizedBox(height: 16),

                    // 6. Quick Actions Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.6,
                      children: shouldAnimate
                          ? quickActionButtons
                                .animate(interval: 100.ms)
                                .fadeIn(duration: 500.ms)
                                .slideY(begin: 0.2, end: 0)
                          : quickActionButtons,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDynamicFocusCard(
    BuildContext context,
    String courseId,
    Map<String, dynamic> data,
    DateTime time,
    bool isLive,
    bool shouldAnimateEntrance,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final courseDate = DateTime(time.year, time.month, time.day);
    final timeStr = DateFormat(
      'h:mm a',
      Localizations.localeOf(context).toString(),
    ).format(time);

    String dateLabel;
    if (isLive) {
      dateLabel = l10n.started;
    } else {
      if (courseDate.isAtSameMomentAs(today)) {
        dateLabel = l10n.todayAt(timeStr);
      } else if (courseDate.isAtSameMomentAs(
        today.add(const Duration(days: 1)),
      )) {
        dateLabel = l10n.tomorrowAt(timeStr);
      } else {
        dateLabel = DateFormat(
          'EEE, d MMM • h:mm a',
          Localizations.localeOf(context).toString(),
        ).format(time);
      }
    }

    Widget? timerWidget;
    if (!isLive) {
      final diff = time.difference(DateTime.now());
      if (diff.inSeconds > 0) {
        timerWidget = _CountdownTimer(target: time);
      }
    }

    Widget liveBadge = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isLive
                ? Colors.red.withOpacity(0.8)
                : AppColors.accentGold.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLive) ...[
                const Icon(Icons.circle, color: Colors.white, size: 8)
                    .animate(onPlay: (c) => c.repeat())
                    .fade(duration: 800.ms, begin: 0.5, end: 1),
                const SizedBox(width: 6),
              ],
              Text(
                isLive ? l10n.liveNowCaps : l10n.upcomingCaps,
                style: TextStyle(
                  color: isLive ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isLive && shouldAnimateEntrance) {
      liveBadge = liveBadge.animate().shimmer(
        duration: 1500.ms,
        color: Colors.white54,
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Hero(
                tag: 'course_image_${data['courseId']}',
                child:
                    data['courseBanner'] != null &&
                        data['courseBanner'].toString().startsWith('assets')
                    ? Image.asset(data['courseBanner'], fit: BoxFit.cover)
                    : SmartImage(
                        imageUrl: data['courseBanner'] ?? '',
                        fit: BoxFit.cover,
                        errorWidget: const Icon(Icons.error),
                      ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 280),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      liveBadge,
                      if (!isLive) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                l10n.happeningNext,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Middle Section: Name and Timer
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AutoTranslatedText(
                          CourseUtils.getLocalizedCourseName(context, data),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (timerWidget != null) ...[
                          const SizedBox(height: 16),
                          timerWidget,
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Button
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CourseDetailsPage(
                              courseId: courseId, // Use the passed courseId
                              courseData: data,
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        isLive
                            ? Icons.flash_on_rounded
                            : Icons.rocket_launch_rounded,
                        size: 20,
                      ),
                      label: Text(
                        isLive ? l10n.joinClassNow : l10n.prepareClass,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutWarning(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.payoutSettings,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.actionRequiredPayout, // We might need to add this to l10n or use a hardcoded string if missing
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PayoutSettingsPage(),
                ),
              );
            },
            child: Text(
              l10n.setupNow,
              style: const TextStyle(
                color: AppColors.accentGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.allCaughtUp,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noClassesScheduled,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
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
}

class _CountdownTimer extends StatefulWidget {
  final DateTime target;

  const _CountdownTimer({required this.target});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    if (widget.target.isAfter(now)) {
      if (mounted) {
        setState(() {
          _timeLeft = widget.target.difference(now);
        });
      }
    } else {
      _timer.cancel();
      if (mounted) {
        setState(() {
          _timeLeft = Duration.zero;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == Duration.zero) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours.remainder(24);
    final minutes = _timeLeft.inMinutes.remainder(60);
    final seconds = _timeLeft.inSeconds.remainder(60);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (days > 0) ...[
                _buildTimeUnit(days.toString(), l10n.daysShort),
                _buildDivider(),
              ],
              _buildTimeUnit(hours.toString().padLeft(2, '0'), l10n.hoursShort),
              _buildDivider(),
              _buildTimeUnit(
                minutes.toString().padLeft(2, '0'),
                l10n.minutesShort,
              ),
              _buildDivider(),
              _buildTimeUnit(
                seconds.toString().padLeft(2, '0'),
                l10n.secondsShort,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 32, // Much larger font for prominent feel
            height: 1.1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.accentGold,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ), // More breathing room
      child: Container(
        height: 30,
        width: 1,
        color: Colors.white.withOpacity(0.15),
      ),
    );
  }
}
