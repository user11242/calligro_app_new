import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/core/services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/features/student/pages/purchase_success_page.dart';
import '../../../core/utils/guest_guard.dart';
import '../../../core/utils/course_utils.dart';
import '../../../core/utils/rating_utils.dart';
import '../../../core/widgets/auto_translated_text.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/smart_image.dart';
import '../../../../core/utils/country_utils.dart';
import 'package:calligro_app/features/student/widgets/course_share_card.dart';
import 'package:calligro_app/core/utils/share_utils.dart';
import '../../teacher/pages/course_details/course_details_page.dart';

import 'package:cloud_functions/cloud_functions.dart';

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
  bool _isProcessing = false;
  late StreamSubscription<PurchaseResult> _subscription;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _subscription = IAPService().purchaseStream.listen((result) {
      if (result.status == PurchaseStatus.purchased || result.status == PurchaseStatus.restored) {
        _handleServerValidation(result);
      } else if (result.status == PurchaseStatus.error || result.status == PurchaseStatus.canceled) {
        _safetyTimer?.cancel();
        if (mounted) setState(() => _isProcessing = false);
      } else if (result.status == PurchaseStatus.pending) {
        debugPrint('💰 UI: Purchase is pending...');
      }
    });
  }

  Future<void> _handleServerValidation(PurchaseResult result) async {
    _safetyTimer?.cancel(); // Cancel the initial safety timer as Apple side is done
    
    // Start a new server-validation timer
    _safetyTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _isProcessing) {
        setState(() => _isProcessing = false);
        AppMessenger.showSnackBar(
          context,
          title: "Validation Timeout",
          message: "The purchase was successful but the server is taking too long to verify. Please refresh the page.",
          type: MessengerType.info,
        );
      }
    });

    try {
      final String? receipt = result.receipt;
      if (receipt == null) throw "Receipt data missing.";

      debugPrint("📡 Calling verifyPurchase Cloud Function...");
      final callable = FirebaseFunctions.instance.httpsCallable('verifyPurchase');
      final validationResult = await callable.call({
        'receiptData': receipt,
        'courseId': widget.courseId,
        'productId': result.productId,
      });

      final bool success = validationResult.data['success'] ?? false;
      if (success && mounted) {
        _safetyTimer?.cancel();
        setState(() => _isProcessing = false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseSuccessPage(
              courseId: widget.courseId,
              courseData: widget.courseData,
            ),
          ),
        );
      } else {
        throw validationResult.data['message'] ?? "Validation failed.";
      }
    } catch (e) {
      _safetyTimer?.cancel();
      if (mounted) {
        setState(() => _isProcessing = false);
        AppMessenger.showSnackBar(
          context,
          title: "Security Validation Error",
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }

  Future<void> _enrollStudent() async {
    // Only used for FREE courses now. Paid courses use verifyPurchase Cloud Function.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('courses').doc(widget.courseId).update({
        'enrolledStudents': FieldValue.arrayUnion([user.uid]),
        'enrolledCount': FieldValue.increment(1),
      });

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseSuccessPage(
              courseId: widget.courseId,
              courseData: widget.courseData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      debugPrint("Enrollment error: $e");
    }
  }

  Future<void> _handlePurchase() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isGuest = currentUser == null;

    if (GuestGuard.check(
      context,
      isGuest: isGuest,
      returnTo: '/studentDashboard',
    )) {
      if (widget.courseData['price'] == 0) {
        setState(() => _isProcessing = true);
        await _enrollStudent();
        return;
      }

      setState(() => _isProcessing = true);
      _safetyTimer?.cancel();
      _safetyTimer = Timer(const Duration(seconds: 25), () {
        if (mounted && _isProcessing) {
          setState(() => _isProcessing = false);
          AppMessenger.showSnackBar(
            context,
            title: "Safety Timeout",
            message: "Purchase timed out. Check the Debug Logs button on top.",
            type: MessengerType.error,
          );
        }
      });

      final productId = widget.courseData['iapProductId'] ??
          'com.yazan.calligro.tier_${(widget.courseData['price'] ?? 50.0).toInt()}';

      try {
        await IAPService().buyCourse(productId);
      } catch (e) {
        _safetyTimer?.cancel();
        if (mounted) setState(() => _isProcessing = false);
        AppMessenger.showSnackBar(
          context,
          title: "IAP Error",
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    }
  }

  void _showDebugLogs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "💰 IAP DEBUG LOGS",
                  style: TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: IAPService().logStream,
                initialData: const [],
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return const Center(child: Text("No logs yet...", style: TextStyle(color: Colors.white24)));
                  }
                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        logs[index],
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bannerUrl = widget.courseData['courseBanner'] ?? '';
    final price = (widget.courseData['price'] ?? 0).toDouble();
    final isFree = price == 0;
    final teacherId = widget.courseData['teacherId'] ?? '';

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
                        // 💰 DEBUG LOGS BUTTON
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                          ),
                          child: TextButton.icon(
                            onPressed: _showDebugLogs,
                            icon: const Icon(Icons.bug_report, color: AppColors.accentGold, size: 16),
                            label: const Text("DEBUG", style: TextStyle(color: AppColors.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
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
                                    "Check out this calligraphy course: ${CourseUtils.getLocalizedCourseName(context, widget.courseData)} on Calligro!",
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
                  height: 380,
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
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 80,
                          left: 20,
                          right: 20,
                          child: Container(
                            alignment: Alignment.center,
                            child: AutoTranslatedText(
                              CourseUtils.getLocalizedCourseName(context, widget.courseData),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 20,
                          right: 20,
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(teacherId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              String name =
                                  widget.courseData['teacherName'] ?? 'Master Artist';
                              String photo =
                                  widget.courseData['teacherProfilePic'] ?? '';

                              if (snapshot.hasData &&
                                  snapshot.data != null &&
                                  snapshot.data!.exists) {
                                final data =
                                    snapshot.data!.data()
                                        as Map<String, dynamic>;
                                name = data['name'] ?? name;
                                photo = data['photoUrl'] ?? photo;
                              }

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 18,
                                    sigmaY: 18,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.18),
                                          Colors.white.withValues(alpha: 0.08),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(32),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(1.5),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.accentGold,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: ProfileAvatar(
                                            radius: 24,
                                            imageUrl: photo,
                                            backgroundColor: Colors.grey[900],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 0.2,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.black45,
                                                          blurRadius: 4,
                                                          offset: Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.exists)
                                                    () {
                                                      final userData =
                                                          snapshot.data!.data()
                                                              as Map<String, dynamic>;
                                                      final phone =
                                                          userData['phone'] ??
                                                          userData['phoneNumber']
                                                              as String?;
                                                      final flag =
                                                          CountryUtils
                                                              .getFlagFromPhoneNumber(
                                                                phone,
                                                              );
                                                      if (flag.isNotEmpty) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 8.0,
                                                              ),
                                                          child: Text(
                                                            flag,
                                                            style: const TextStyle(
                                                              fontSize: 20,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      return const SizedBox
                                                          .shrink();
                                                    }() ??
                                                    const SizedBox.shrink(),
                                                ],
                                              ),
                                              Text(
                                                l10n.instructor.toUpperCase(),
                                                style: TextStyle(
                                                  color: AppColors.accentGold
                                                      .withValues(alpha: 0.95),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 20,
                          left: 20,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Text(
                                  _getLocalizedLevel(
                                    context,
                                    widget.courseData['selectedCategory'] ??
                                        'Beginner',
                                  ).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              isFree ? l10n.free.toUpperCase() : "\$$price",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
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
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(teacherId)
                          .snapshots(),
                      builder: (context, userSnap) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('courses')
                              .where('teacherId', isEqualTo: teacherId)
                              .snapshots(),
                          builder: (context, courseSnap) {
                            final userData =
                                userSnap.data?.data() as Map<String, dynamic>? ??
                                {};
                            final avgRating = RatingUtils.calculateAverageRating(
                              userData['totalStars'] ?? 0,
                              userData['reviewCount'] ?? 0,
                            );
                            final followerCount = userData['followerCount'] ?? 0;
                            final courseCount =
                                courseSnap.hasData
                                    ? courseSnap.data!.docs.length
                                    : 0;

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
                                    followerCount.toString(),
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
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    _buildPremiumHeader(l10n.description, icon: Icons.info_outline),
                    const SizedBox(height: 16),
                    AutoTranslatedText(
                      widget.courseData['courseDescription'] ?? '',
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
                                    widget.courseData['startDate'],
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
                                  widget.courseData['endDate'] != null
                                      ? _formatTimestamp(
                                        context,
                                        widget.courseData['endDate'],
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
                                    widget.courseData['startTime'],
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
                                    widget.courseData['endTime'],
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
                              widget.courseData['selectedDays'] as List<dynamic>?,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildPremiumHeader(
                      l10n.curriculum.toUpperCase(),
                      icon: Icons.auto_stories_outlined,
                    ),
                    const SizedBox(height: 24),
                    _buildPremiumCurriculum(widget.courseData, l10n),
                    const SizedBox(height: 40),
                    _buildPremiumHeader(
                      l10n.toolsRequirements.toUpperCase(),
                      icon: Icons.draw_outlined,
                    ),
                    const SizedBox(height: 24),
                    _buildToolsList(widget.courseData, l10n),
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
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('courses')
                    .doc(widget.courseId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  bool isEnrolled = false;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final List<dynamic> enrolledStudents =
                        data['enrolledStudents'] ?? [];
                    if (currentUser != null &&
                        enrolledStudents.contains(currentUser.uid)) {
                      isEnrolled = true;
                    }
                  }

                  return ElevatedButton(
                    onPressed: _isProcessing ? null : () {
                      if (isEnrolled) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CourseDetailsPage(
                              courseId: widget.courseId,
                              courseData:
                                  snapshot.data!.data() as Map<String, dynamic>,
                            ),
                          ),
                        );
                      } else {
                        _handlePurchase();
                      }
                    },
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
                courseData: widget.courseData,
                teacherName: widget.courseData['teacherName'] ?? 'Master Artist',
                teacherProfilePic: widget.courseData['teacherProfilePic'] ?? '',
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

  String _getLocalizedLevel(BuildContext context, String category) {
    final l10n = AppLocalizations.of(context)!;
    final cat = category.toLowerCase();
    if (cat.contains('beginner')) return l10n.beginner;
    if (cat.contains('intermediate')) return l10n.intermediate;
    if (cat.contains('advanced')) return l10n.advanced;
    return category;
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
