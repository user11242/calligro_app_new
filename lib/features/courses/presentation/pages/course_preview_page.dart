import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/utils/guest_guard.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import 'package:calligro_app/core/utils/rating_utils.dart';
import 'package:calligro_app/core/widgets/auto_translated_text.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';

import 'package:calligro_app/features/courses/presentation/widgets/course_share_card.dart';
import 'package:calligro_app/core/utils/share_utils.dart';
import 'package:calligro_app/features/classroom/presentation/pages/course_details_page.dart';

import '../../application/course_controllers.dart';
import '../../application/course_purchases.dart';
import '../../domain/course_models.dart';
import '../course_scope.dart';
import 'purchase_success_page.dart';


class CoursePreviewPage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final String? heroTag;

  const CoursePreviewPage({
    super.key,
    required this.courseId,
    required this.courseData,
    this.heroTag,
  });

  @override
  State<CoursePreviewPage> createState() => _CoursePreviewPageState();
}

class _CoursePreviewPageState extends State<CoursePreviewPage> {
  final GlobalKey _shareKey = GlobalKey();
  CoursePreviewController? _preview;
  late CourseServices _services;
  PurchaseStage _lastStage = PurchaseStage.idle;

  CoursePurchases get _purchases => _services.purchases;
  String get _uid => _services.currentUid();

  /// The live course document (falls back to what the caller passed in).
  Map<String, dynamic> get courseData => _preview?.course?.raw ?? widget.courseData;

  bool get _isProcessing => _purchases.statusOf(widget.courseId).isBusy;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preview != null) return;
    _services = CourseScope.of(context);
    _preview = CoursePreviewController(
      repository: _services.courses,
      courseId: widget.courseId,
      uid: _uid,
      initial: Course.fromMap(widget.courseId, widget.courseData),
    )..start();
    _purchases.addListener(_onPurchaseChanged);
  }

  @override
  void dispose() {
    _purchases.removeListener(_onPurchaseChanged);
    _preview?.dispose();
    super.dispose();
  }

  /// Reacts to THIS course's purchase status (the flow itself lives app-wide).
  void _onPurchaseChanged() {
    if (!mounted) return;
    final status = _purchases.statusOf(widget.courseId);
    if (status.stage == _lastStage) return;
    _lastStage = status.stage;
    final l10n = AppLocalizations.of(context)!;
    switch (status.stage) {
      case PurchaseStage.enrolled:
        _purchases.clear(widget.courseId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseSuccessPage(courseId: widget.courseId, courseData: courseData),
          ),
        );
      case PurchaseStage.failed:
        _purchases.clear(widget.courseId);
        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: _purchaseErrorText(status, l10n),
          type: MessengerType.error,
        );
      case PurchaseStage.cancelled:
        _purchases.clear(widget.courseId);
      case PurchaseStage.idle || PurchaseStage.buying || PurchaseStage.verifying:
        break;
    }
  }

  String _purchaseErrorText(PurchaseStatus s, AppLocalizations l10n) => switch (s.code) {
        'failed-precondition' => s.message ?? l10n.somethingWentWrong,
        'already-exists' => s.message ?? l10n.somethingWentWrong,
        _ => s.message ?? l10n.somethingWentWrong,
      };

  Future<void> _onMainButton() async {
    final action = _preview?.action;
    final course = _preview?.course;
    if (action == null || course == null) return;
    switch (action) {
      case CourseAction.open || CourseAction.manage:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailsPage(courseId: widget.courseId, courseData: courseData),
          ),
        );
      case CourseAction.soldOut:
        break;
      case CourseAction.buy || CourseAction.enrollFree:
        if (!GuestGuard.check(context, isGuest: _uid.isEmpty, returnTo: '/studentDashboard')) return;
        final result = action == CourseAction.buy ? await _purchases.buy(course) : await _purchases.enrollFree(course);
        if (result == BuyResult.failed && mounted) _onPurchaseChanged();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_preview!, _purchases]),
        builder: (context, _) => _buildPage(context),
      );

  Widget _buildPage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bannerUrl = courseData['courseBanner'] ?? '';
    final price = (courseData['price'] ?? 0).toDouble();
    final isFree = price == 0;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. TOP HEADER
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await ShareUtils.shareWidgetAsImage(
                                boundaryKey: _shareKey,
                                text:
                                    "Check out this calligraphy course: ${CourseUtils.getLocalizedCourseName(context, courseData)} on Calligro!",
                                subject: "Calligraphy Course",
                              );
                            },
                            icon: const Icon(
                              Icons.share_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. CINEMATIC BANNER
              SliverToBoxAdapter(
                child: Container(
                  height: 460,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Image
                        Hero(
                          tag: widget.heroTag ?? 'course_img_${widget.courseId}',
                          child: bannerUrl.startsWith('assets')
                              ? Image.asset(bannerUrl, fit: BoxFit.cover)
                              : SmartImage(
                                imageUrl: bannerUrl,
                                fit: BoxFit.cover,
                                placeholder: Container(color: Colors.grey[900]),
                                errorWidget: const Icon(Icons.error),
                              ),
                        ),

                        // Deep cinematic gradient
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.black.withValues(alpha: 0.85),
                                  Colors.black.withValues(alpha: 0.95),
                                ],
                                stops: const [0.0, 0.3, 0.65, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Price badge — top right
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              isFree ? l10n.free.toUpperCase() : "\$${price.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        // Bottom content — course title + teacher info + metadata chips
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Builder(
                            builder: (context) {
                              final t = _preview?.teacher;
                              final String name = (t != null && t.name.isNotEmpty) ? t.name : (courseData['teacherName'] ?? 'Master Artist');
                              final String photo = (t != null && t.photoUrl.isNotEmpty) ? t.photoUrl : (courseData['teacherProfilePic'] ?? '');
                              final double avgRating = t?.averageRating ?? 0;
                              final String flag = t?.countryFlag ?? '';
                              final List<String> languages = t?.spokenLanguages ?? const [];

                              return ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(32),
                                  bottomRight: Radius.circular(32),
                                ),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.3),
                                          Colors.black.withValues(alpha: 0.6),
                                        ],
                                      ),
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Course Title
                                        Text(CourseUtils.getLocalizedCourseName(context, courseData),
                                          textAlign: TextAlign.start,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            height: 1.2,
                                            letterSpacing: -0.3,
                                          ),
                                        ),

                                        const SizedBox(height: 14),

                                        // Teacher Row
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(1.5),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppColors.accentGold, width: 1.5),
                                              ),
                                              child: ProfileAvatar(
                                                radius: 22,
                                                imageUrl: photo,
                                                backgroundColor: Colors.grey[900],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      if (flag.isNotEmpty) ...[
                                                        const SizedBox(width: 6),
                                                        Text(flag, style: const TextStyle(fontSize: 16)),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Rating pill
                                            if (avgRating > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accentGold.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.star_rounded, color: AppColors.accentGold, size: 16),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      RatingUtils.formatRating(avgRating),
                                                      style: const TextStyle(
                                                        color: AppColors.accentGold,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),

                                        const SizedBox(height: 14),

                                        // Metadata chips row — Level + Age + Languages
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildMetaChip(
                                              Icons.signal_cellular_alt_rounded,
                                              _getLocalizedLevel(context, courseData['selectedCategory'] ?? 'Beginner'),
                                            ),
                                            if (courseData['ageCategory'] != null)
                                              _buildMetaChip(
                                                Icons.face_rounded,
                                                _getLocalizedAgeCategory(context, courseData['ageCategory']?.toString() ?? ''),
                                              ),
                                            if (languages.isNotEmpty)
                                              _buildMetaChip(
                                                Icons.translate_rounded,
                                                "${l10n.spokenLanguages}: ${languages.take(3).map((lang) {
                                                  if (lang == "Arabic") return "العربية";
                                                  if (lang == "English") return "EN";
                                                  if (lang == "Turkish") return "TR";
                                                  if (lang == "Bengali") return "BN";
                                                  if (lang == "Urdu") return "UR";
                                                  if (lang == "Farsi") return "FA";
                                                  if (lang == "Kurdish") return "KU";
                                                  return lang;
                                                }).join(' · ')}",
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. COURSE DETAILS
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                            final t = _preview?.teacher;
                            final avgRating = t?.averageRating ?? 0.0;
                            final courseCount = t?.courseCount ?? 0;
                            final totalStudents = t?.totalStudents ?? 0;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.symmetric(
                                  horizontal: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMinimalStat(
                                    totalStudents.toString(),
                                    l10n.students.toUpperCase(),
                                  ),
                                  _buildStatVerticalDivider(),
                                  _buildMinimalStat(
                                    RatingUtils.formatRating(avgRating),
                                    l10n.rating.toUpperCase(),
                                    icon: Icons.star_rounded,
                                  ),
                                  _buildStatVerticalDivider(),
                                  _buildMinimalStat(
                                    courseCount.toString(),
                                    l10n.courses.toUpperCase(),
                                  ),
                                ],
                              ),
                            );
                      },
                    ),
                    const SizedBox(height: 32),
                    _buildPremiumHeader(l10n.description, icon: Icons.info_outline),
                    const SizedBox(height: 16),
                    AutoTranslatedText(
                      courseData['courseDescription'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildPremiumHeader(
                      l10n.schedule,
                      icon: Icons.event_note_outlined,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.accentGold,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.sessionTimeZoneNote,
                              style: TextStyle(
                                color: AppColors.accentGold.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildGridItem(
                                  context,
                                  l10n.startDate,
                                  _formatTimestamp(
                                    context,
                                    courseData['startDate'],
                                  ),
                                  Icons.calendar_today_rounded,
                                ),
                              ),
                              Container(
                                height: 48,
                                width: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              Expanded(
                                child: _buildGridItem(
                                  context,
                                  l10n.endDate,
                                  courseData['endDate'] != null
                                      ? _formatTimestamp(
                                        context,
                                        courseData['endDate'],
                                      )
                                      : l10n.tbd,
                                  Icons.calendar_month_rounded,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(color: Colors.white10),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildGridItem(
                                  context,
                                  l10n.startTime,
                                  _formatTimestamp(
                                    context,
                                    courseData['startTime'],
                                    isTime: true,
                                  ),
                                  Icons.access_time_filled_rounded,
                                ),
                              ),
                              Container(
                                height: 48,
                                width: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              Expanded(
                                child: _buildGridItem(
                                  context,
                                  l10n.endTime,
                                  _formatTimestamp(
                                    context,
                                    courseData['endTime'],
                                    isTime: true,
                                  ),
                                  Icons.history_toggle_off_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildModernInfoRow(
                            Icons.view_week_rounded,
                            l10n.weeklySession,
                            _getLocalizedDays(
                              context,
                              courseData['selectedDays'] as List<dynamic>?,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildPremiumHeader(
                      l10n.localeName == 'ar' ? 'نتائج التعلم' : 'Learning Outcomes'.toUpperCase(),
                      icon: Icons.auto_stories_outlined,
                    ),
                    const SizedBox(height: 24),
                    _buildPremiumCurriculum(courseData, l10n),
                    const SizedBox(height: 40),
                    _buildPremiumHeader(
                      l10n.toolsRequirements.toUpperCase(),
                      icon: Icons.draw_outlined,
                    ),
                    const SizedBox(height: 24),
                    _buildToolsList(courseData, l10n),
                    const SizedBox(height: 40),
                    const SizedBox(height: 150),
                  ]),
                ),
              ),
            ],
          ),

          // 4. PERSISTENT ENROLL BAR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                28,
                20,
                28,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0),
                    AppColors.primary,
                    AppColors.primary,
                  ],
                  stops: const [0, 0.4, 1.0],
                ),
              ),
              child: Builder(
                builder: (context) {
                  final action = _preview?.action;
                  final bool isEnrolled = action == CourseAction.open || action == CourseAction.manage;
                  final bool isFull = action == CourseAction.soldOut;
                  if (isFull && !isEnrolled) {
                    return ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 20, color: Colors.white38),
                          const SizedBox(width: 12),
                          Text(
                            l10n.soldOut.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ElevatedButton(
                    key: const Key('course-main-button'),
                    onPressed: _isProcessing ? null : _onMainButton,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isEnrolled ? Colors.green : AppColors.accentGold,
                      foregroundColor: isEnrolled ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 15,
                      shadowColor: (isEnrolled ? Colors.green : AppColors.accentGold)
                          .withValues(alpha: 0.4),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (isEnrolled
                                      ? l10n.goToCourse
                                      : l10n.enrollNow)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              isEnrolled
                                  ? Icons.play_circle_fill
                                  : Icons.arrow_forward_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: -2000,
            child: RepaintBoundary(
              key: _shareKey,
              child: CourseShareCard(
                courseData: courseData,
                teacherName: courseData['teacherName'] ?? 'Master Artist',
                teacherProfilePic: courseData['teacherProfilePic'] ?? '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalStat(String value, String label, {IconData? icon}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.accentGold, size: 16),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildPremiumHeader(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.accentGold.withValues(alpha: 0.6), size: 20),
          const SizedBox(width: 12),
        ],
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: Divider(color: AppColors.accentGold.withValues(alpha: 0.2))),
      ],
    );
  }

  Widget _buildPremiumCurriculum(Map<String, dynamic> data, AppLocalizations l10n) {
    final List<dynamic> lessons =
        data['curriculumSteps'] ?? data['lessons'] ?? data['sections'] ?? [];
    if (lessons.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Text(
          l10n.curriculumTbd,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 14,
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: List.generate(lessons.length, (index) {
        final title = lessons[index] is Map
            ? (lessons[index]['title'] ?? 'Section')
            : lessons[index].toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Text(
                (index + 1) < 10 ? "0${index + 1}" : "${index + 1}",
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: AutoTranslatedText(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white24,
                size: 18,
              ),
            ],
          ),
        );
      }),
    );
  }

  static const Map<String, IconData> _iconRegistry = {
    'pen': Icons.edit,
    'brush': Icons.brush,
    'paper': Icons.article,
    'ink': Icons.water_drop,
    'ruler': Icons.straighten,
    'book': Icons.menu_book,
    'laptop': Icons.laptop,
    'generic': Icons.star_border,
    'architecture': Icons.architecture_rounded,
    'build': Icons.build_rounded,
  };

  Widget _buildToolsList(Map<String, dynamic> data, AppLocalizations l10n) {
    final List<dynamic> tools = data['requiredTools'] ?? [];
    if (tools.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Text(
          l10n.noToolsListed,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 14,
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tools.map((tool) {
        final toolMap = tool as Map<String, dynamic>;
        final name = toolMap['name'] ?? 'Tool';
        final iconKey = toolMap['icon'];
        IconData toolIcon = Icons.architecture_rounded;
        if (iconKey is String && _iconRegistry.containsKey(iconKey)) {
          toolIcon = _iconRegistry[iconKey]!;
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(toolIcon, color: AppColors.accentGold, size: 14),
              ),
              const SizedBox(width: 10),
              AutoTranslatedText(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGridItem(BuildContext context, String label, String value, IconData icon) {
    final bool isRTL = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        if (!isRTL) ...[
          Icon(icon, color: Colors.white24, size: 18),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: isRTL
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isRTL) ...[
          const SizedBox(width: 12),
          Icon(icon, color: Colors.white24, size: 18),
        ],
      ],
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.accentGold, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(text: "$label: "),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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

  String _getLocalizedLevel(BuildContext context, String category) {
    final l10n = AppLocalizations.of(context)!;
    final cat = category.toLowerCase();
    if (cat.contains('beginner')) return l10n.beginner;
    if (cat.contains('intermediate')) return l10n.intermediate;
    if (cat.contains('advanced')) return l10n.advanced;
    return category;
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentGold, size: 15),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedDays(BuildContext context, List<dynamic>? days) {
    if (days == null || days.isEmpty) return AppLocalizations.of(context)!.tbd;
    final l10n = AppLocalizations.of(context)!;
    return days.map((day) {
      final d = day.toString().toLowerCase();
      if (d.contains('monday')) return l10n.monday;
      if (d.contains('tuesday')) return l10n.tuesday;
      if (d.contains('wednesday')) return l10n.wednesday;
      if (d.contains('thursday')) return l10n.thursday;
      if (d.contains('friday')) return l10n.friday;
      if (d.contains('saturday')) return l10n.saturday;
      if (d.contains('sunday')) return l10n.sunday;
      return day.toString();
    }).join(', ');
  }

  String _formatTimestamp(BuildContext context, dynamic timestamp, {bool isTime = false}) {
    if (timestamp == null) return 'TBD';
    final locale = AppLocalizations.of(context)!.localeName;
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    }
    if (date == null) return 'TBD';
    if (isTime) {
      return intl.DateFormat.jm(locale).format(date);
    }
    return intl.DateFormat.yMMMd(locale).format(date);
  }
}
