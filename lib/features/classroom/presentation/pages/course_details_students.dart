part of 'course_details_page.dart';

/// Split out of course_details_page.dart (unchanged code): sections that only
/// read the page's state.
extension _StudentSections on _CourseDetailsPageState {
  Widget _buildEnrolledStudentsList() {
    // The enrolled students come from the page's one live course listener
    // (_listenToOverrides); their profiles load once per change of the list,
    // not on every redraw.
    final List<String> enrolledStudentIds = _enrolledStudents;

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
          future: _studentDetailsFor(enrolledStudentIds),
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
                            PublicProfilePage(userId: student['uid']),
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
                                  color: AppColors.accentGold.withOpacity(0.3),
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
                                        color: AppColors.accentGold.withOpacity(
                                          0.6,
                                        ),
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

  /// The profiles for [studentIds], loaded once per distinct list of ids.
  Future<List<Map<String, dynamic>>> _studentDetailsFor(List<String> studentIds) {
    final key = studentIds.join(',');
    if (_studentDetails != null && _studentDetailsKey == key) return _studentDetails!;
    _studentDetailsKey = key;
    return _studentDetails = _fetchStudentDetails(studentIds);
  }

  Future<List<Map<String, dynamic>>> _fetchStudentDetails(List<String> studentIds) async {
    if (studentIds.isEmpty) return [];
    final l10n = AppLocalizations.of(context)!;
    final students = await ClassroomScope.of(context).courseDetails.students(studentIds);
    return [
      for (final s in students)
        {
          'uid': s.uid,
          'name': s.name ?? l10n.unknownStudent,
          'email': s.email ?? l10n.noEmail,
          'profilePic': s.photoUrl,
          'createdAt': s.createdAt,
        },
    ];
  }

  void _showAdminNotificationDialog() async {
    // Fetch latest course document to get accurate enrolledStudents and teacherId
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final courseDetails = ClassroomScope.of(context).courseDetails;
    Map<String, dynamic>? latest;
    try {
      latest = await courseDetails.getCourse(widget.courseId);
    } catch (_) {}

    final data = latest ?? widget.courseData;
    final String cName = data['courseName'] ?? data['courseTitle'] ?? courseName;
    final String tName = data['teacherName'] ?? widget.courseData['teacherName'] ?? 'Instructor';
    final String tId = data['teacherId'] ?? widget.courseData['teacherId'] ?? '';
    final dynamic studentsRaw = data['enrolledStudents'];
    final List<String> studentIds = (studentsRaw is List)
        ? studentsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final int enrolledCount = studentIds.length;

    if (!mounted) return;

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
                          cName,
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
                              isArabic ? "المعلم: $tName" : "Teacher: $tName",
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
                          "📢 إشعار إداري: $cName",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          msgController.text.trim().isEmpty
                              ? (isArabic
                                  ? "بخصوص دورتكم مع أ. $tName: [نص رسالتك هنا...]"
                                  : "Regarding your course with $tName: [Your message here...]")
                              : (isArabic
                                  ? "بخصوص دورتكم مع أ. $tName: ${msgController.text.trim()}"
                                  : "Regarding your course with $tName: ${msgController.text.trim()}"),
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
                                    courseId: widget.courseId,
                                    courseName: cName,
                                    teacherName: tName,
                                    teacherId: tId,
                                    studentIds: studentIds,
                                    message: text,
                                  );

                                  if (mounted && dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                    _showMessage(
                                      isArabic ? "تم الإرسال" : "Sent",
                                      isArabic
                                          ? "تم إرسال الإشعار بنجاح إلى $count مستلم (الطلاب والمعلم)"
                                          : "Notification sent successfully to $count recipients",
                                      MessengerType.success,
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSending = false);
                                  if (mounted) {
                                    _showMessage(
                                      isArabic ? "خطأ" : "Error",
                                      "$e",
                                      MessengerType.error,
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
}
