import 'package:flutter/material.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/features/teacher/pages/course_details/course_details_page.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/message/app_messenger.dart';

class AdminCoursesMgmt extends StatefulWidget {
  const AdminCoursesMgmt({super.key});

  @override
  State<AdminCoursesMgmt> createState() => _AdminCoursesMgmtState();
}

class _AdminCoursesMgmtState extends State<AdminCoursesMgmt> {
  final AdminService _adminService = AdminService();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l10n.courseModeration, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.searchHintCourses,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search, color: Colors.amber),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adminService.getAllCourses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }

                final courses = snapshot.data?.where((c) {
                  final name = c['courseName']?.toString().toLowerCase() ?? "";
                  final teacher = c['teacherName']?.toString().toLowerCase() ?? "";
                  return name.contains(_searchQuery.toLowerCase()) || teacher.contains(_searchQuery.toLowerCase());
                }).toList() ?? [];

                if (courses.isEmpty) {
                  return Center(
                    child: Text(l10n.noCoursesFound, style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return _buildCourseItem(context, course);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItem(BuildContext context, Map<String, dynamic> course) {
    final l10n = AppLocalizations.of(context)!;
    final String courseName = course['courseName'] ?? l10n.untitledCourse;
    final String teacherName = course['teacherName'] ?? l10n.unknown;
    final String? courseImageUrl = course['courseBanner'];
    final String? teacherProfilePic = course['teacherProfilePic'];
    final price = (course['price'] ?? 0).toDouble();
    final isFree = price == 0;
    
    final dynamic studentsRaw = course['enrolledStudents'];
    final List<dynamic> enrolledList = (studentsRaw is List) ? studentsRaw : [];
    final int enrolledCount = enrolledList.length;
    final int maxStudents = (course['maxStudents'] ?? 0);
    final bool isFull = maxStudents > 0 && enrolledCount >= maxStudents;
    final String locale = Localizations.localeOf(context).languageCode;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.accentGold.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailsPage(
                  courseId: course['id'],
                  courseData: course,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Image Section
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: courseImageUrl != null && courseImageUrl.isNotEmpty
                          ? (courseImageUrl.startsWith('assets')
                              ? Image.asset(
                                  courseImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white.withOpacity(0.05),
                                    child: const Icon(Icons.broken_image, color: Colors.white30, size: 40),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: courseImageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.white.withOpacity(0.05),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: AppColors.accentGold, strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.white.withOpacity(0.05),
                                    child: const Icon(Icons.broken_image, color: Colors.white30, size: 40),
                                  ),
                                ))
                          : Container(
                              color: Colors.white.withOpacity(0.05),
                              child: const Icon(Icons.image, color: Colors.white30, size: 40),
                            ),
                    ),
                  ),
                  // Dark Gradient Overlay for text readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  // Price Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFree ? Colors.green.withOpacity(0.9) : AppColors.accentGold.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isFree ? l10n.free.toUpperCase() : "\$${price.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: isFree ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  // Action Menu (Top Left)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        color: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'view') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CourseDetailsPage(
                                  courseId: course['id'],
                                  courseData: course,
                                ),
                              ),
                            );
                          } else if (value == 'send_notification') {
                            _showSendNotificationDialog(course);
                          } else if (value == 'add_student') {
                            _showAddStudentDialog(course['id'], courseName);
                          } else if (value == 'delete') {
                            _confirmDelete(course['id'], course['courseName']);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                const Icon(Icons.visibility, color: AppColors.accentGold, size: 20),
                                const SizedBox(width: 12),
                                Text(l10n.viewDetails, style: const TextStyle(color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'send_notification',
                            child: Row(
                              children: [
                                const Icon(Icons.campaign_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  Localizations.localeOf(context).languageCode == 'ar' ? 'إرسال إشعار' : 'Send Notification',
                                  style: const TextStyle(color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'add_student',
                            child: Row(
                              children: [
                                const Icon(Icons.person_add_alt_1_rounded, color: Colors.blueAccent, size: 20),
                                const SizedBox(width: 12),
                                Text(l10n.addStudent, style: const TextStyle(color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                Text(l10n.deleteCourse, style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Status Badge (Bottom Left)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: _buildPremiumStatusBadge(_getCourseDisplayStatus(context, course['startDate'], course['endDate'])),
                  ),
                  // Students Count Badge (Bottom Right)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 14,
                            color: isFull ? const Color(0xFFFF4D6D) : AppColors.accentGold,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            maxStudents > 0 ? '$enrolledCount / $maxStudents' : '$enrolledCount',
                            style: TextStyle(
                              color: isFull ? const Color(0xFFFF4D6D) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // 2. Info Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Name
                    Text(
                      courseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Students Enrollment Row
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 15,
                          color: isFull ? const Color(0xFFFF4D6D) : const Color(0xFF00B4D8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          maxStudents > 0
                              ? (locale == 'ar'
                                  ? '$enrolledCount من $maxStudents طالب مسجل'
                                  : '$enrolledCount of $maxStudents students enrolled')
                              : (locale == 'ar'
                                  ? '$enrolledCount طالب مسجل'
                                  : '$enrolledCount students enrolled'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isFull) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D6D).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFF4D6D).withOpacity(0.4)),
                            ),
                            child: Text(
                              locale == 'ar' ? 'مكتملة' : 'FULL',
                              style: const TextStyle(
                                color: Color(0xFFFF4D6D),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Divider
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    const SizedBox(height: 12),
                    
                    // Teacher Info Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accentGold.withOpacity(0.5), width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            backgroundImage: teacherProfilePic != null && teacherProfilePic.isNotEmpty
                                ? (teacherProfilePic.startsWith('assets') 
                                    ? AssetImage(teacherProfilePic) as ImageProvider
                                    : CachedNetworkImageProvider(teacherProfilePic))
                                : null,
                            child: teacherProfilePic == null || teacherProfilePic.isEmpty
                                ? const Icon(Icons.person, size: 14, color: Colors.white54)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacherName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                l10n.instructor.toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.accentGold.withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Small View Details Button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
                          ),
                          child: Text(
                            l10n.viewDetails,
                            style: const TextStyle(
                              color: AppColors.accentGold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
    );
  }

  void _showSendNotificationDialog(Map<String, dynamic> course) {
    final String courseId = course['id'] ?? '';
    final String courseName = course['courseName'] ?? 'Course';
    final String teacherName = course['teacherName'] ?? 'Instructor';
    final String teacherId = course['teacherId'] ?? '';
    final dynamic studentsRaw = course['enrolledStudents'];
    final List<String> studentIds = (studentsRaw is List)
        ? studentsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final int enrolledCount = studentIds.length;
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final TextEditingController msgController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isArabic ? "إرسال إشعار للدورة" : "Send Course Notification",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Course Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isArabic ? "المعلم: $teacherName" : "Teacher: $teacherName",
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isArabic ? "$enrolledCount طالب + المعلم" : "$enrolledCount students + teacher",
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Live Preview Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.preview_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text(
                              isArabic ? "شكل الإشعار كما سيصل للهواتف:" : "Notification Preview:",
                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "📢 إشعار إداري: $courseName",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          msgController.text.trim().isEmpty
                              ? (isArabic
                                  ? "بخصوص دورتكم مع أ. $teacherName: [نص رسالتك هنا...]"
                                  : "Regarding your course with $teacherName: [Your message here...]")
                              : (isArabic
                                  ? "بخصوص دورتكم مع أ. $teacherName: ${msgController.text.trim()}"
                                  : "Regarding your course with $teacherName: ${msgController.text.trim()}"),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message Input Field
                  Text(
                    isArabic ? "نص الرسالة:" : "Message Body:",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: msgController,
                    maxLines: 4,
                    minLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? "مثال: نود تذكيركم بمراجعة قسم الواجبات قبل بداية الحصة القادمة..."
                          : "Type your message here...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
                        child: Text(
                          isArabic ? "إلغاء" : "Cancel",
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSending || msgController.text.trim().isEmpty
                            ? null
                            : () async {
                                final text = msgController.text.trim();
                                if (text.isEmpty) return;

                                setDialogState(() => isSending = true);

                                try {
                                  final count = await _adminService.sendCourseNotification(
                                    courseId: courseId,
                                    courseName: courseName,
                                    teacherName: teacherName,
                                    teacherId: teacherId,
                                    studentIds: studentIds,
                                    message: text,
                                  );

                                  if (mounted) {
                                    Navigator.pop(dialogCtx);
                                    AppMessenger.showSnackBar(
                                      context,
                                      title: isArabic ? "تم الإرسال" : "Sent",
                                      message: isArabic
                                          ? "تم إرسال الإشعار بنجاح إلى $count مستلم (الطلاب والمعلم)"
                                          : "Notification sent successfully to $count recipients",
                                      type: MessengerType.success,
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSending = false);
                                  if (mounted) {
                                    AppMessenger.showSnackBar(
                                      context,
                                      title: isArabic ? "خطأ" : "Error",
                                      message: "$e",
                                      type: MessengerType.error,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          disabledBackgroundColor: Colors.amber.withOpacity(0.3),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.send_rounded, size: 16, color: Colors.black),
                                  const SizedBox(width: 6),
                                  Text(
                                    isArabic ? "إرسال الإشعار" : "Send Notification",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddStudentDialog(String courseId, String courseName) {
    final l10n = AppLocalizations.of(context)!;
    String query = "";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.addStudent,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    courseName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  
                  // Search TextField
                  TextField(
                    onChanged: (val) => setState(() => query = val.toLowerCase().trim()),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: l10n.searchHintUsers,
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.amber, size: 18),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Students List
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'student')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.amber));
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Center(
                            child: Text(
                              l10n.somethingWentWrong,
                              style: const TextStyle(color: Colors.white30),
                            ),
                          );
                        }

                        final allUsers = snapshot.data!.docs;
                        final students = allUsers.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['name'] ?? '').toString().toLowerCase();
                          final email = (data['email'] ?? '').toString().toLowerCase();
                          return name.contains(query) || email.contains(query);
                        }).toList();

                        if (students.isEmpty) {
                          return Center(
                            child: Text(
                              l10n.noUsersFound,
                              style: const TextStyle(color: Colors.white30),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final doc = students[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'No Name';
                            final email = data['email'] ?? 'No Email';
                            final photoUrl = data['photoUrl'] as String?;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: photoUrl != null && photoUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.white.withOpacity(0.05),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.blueAccent.withOpacity(0.1),
                                          child: const Icon(Icons.person, color: Colors.blueAccent, size: 18),
                                        ),
                                    )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.blueAccent.withOpacity(0.1),
                                        child: const Icon(Icons.person, color: Colors.blueAccent, size: 18),
                                      ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                email,
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.pop(context); // Close search dialog
                                _confirmAddStudent(courseId, courseName, doc.id, name);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        l10n.cancel,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmAddStudent(String courseId, String courseName, String studentUid, String studentName) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.addStudent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          l10n.enrollStudentConfirmMessage(studentName, courseName),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final navContext = Navigator.of(context).context; // Capture parent context
              Navigator.pop(context); // Close confirmation dialog
              
              showDialog(
                context: navContext,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
              );

              try {
                await _adminService.enrollStudentInCourse(courseId, studentUid);
                if (mounted) {
                  Navigator.of(navContext).pop(); // Close loading indicator
                  AppMessenger.showSnackBar(
                    navContext,
                    title: "Success",
                    message: l10n.enrollStudentSuccess(studentName),
                    type: MessengerType.success,
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(navContext).pop(); // Close loading indicator
                  AppMessenger.showSnackBar(
                    navContext,
                    title: l10n.error,
                    message: e.toString(),
                    type: MessengerType.error,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String courseId, String? name) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(l10n.deleteCourseConfirmTitle, style: const TextStyle(color: Colors.white)),
        content: Text(l10n.deleteCourseConfirmMessage, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(l10n.delete, style: const TextStyle(color: Colors.redAccent)),
            onPressed: () async {
              await _adminService.deleteCourse(courseId);
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getCourseDisplayStatus(BuildContext context, dynamic start, dynamic end) {
    DateTime? startDate;
    DateTime? endDate;
    if (start is Timestamp) startDate = start.toDate();
    if (end is Timestamp) endDate = end.toDate();

    if (startDate == null || endDate == null) {
      return {'text': 'Status Unknown', 'color': Colors.grey, 'icon': Icons.help_outline};
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

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

  Widget _buildPremiumStatusBadge(Map<String, dynamic> status) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (status['color'] as Color).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (status['color'] as Color).withOpacity(0.4),
              width: 1.5,
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
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
