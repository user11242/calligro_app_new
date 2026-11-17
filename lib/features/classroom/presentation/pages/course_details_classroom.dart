part of 'course_details_page.dart';

/// Split out of course_details_page.dart (unchanged code): sections that only
/// read the page's state.
extension _ClassroomSections on _CourseDetailsPageState {
  Widget _buildClassroomTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDynamicSchedulingCard(),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          role: _role,
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
                      : AppLocalizations.of(context)!.submitYourWork,
                  icon: Icons.folder_special_rounded,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignmentsPage(
                        courseId: widget.courseId,
                        role: _role,
                      ),
                    ),
                  ),
                ),
              ),
              if (!isTeacher) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    title: AppLocalizations.of(context)!.classRecordings,
                    subtitle: AppLocalizations.of(context)!.rewatchPastSessions,
                    icon: Icons.video_library_rounded,
                    color: Colors.purpleAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecordingsPage(courseId: widget.courseId, role: _role),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          if (userRole == 'admin') ...[
            const SizedBox(height: 16),
            _buildActionCard(
              title: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'إرسال إشعار للدورة'
                  : 'Send Course Notification',
              subtitle: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'إرسال تنبيه فوري لجميع الطلاب والمعلم'
                  : 'Send instant notification to all students and the teacher',
              icon: Icons.campaign_rounded,
              color: Colors.amber,
              onTap: _showAdminNotificationDialog,
            ),
          ],
          if (isTeacher) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: AppLocalizations.of(context)!.classRecordings,
                    subtitle: AppLocalizations.of(context)!.rewatchPastSessions,
                    icon: Icons.video_library_rounded,
                    color: Colors.purpleAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecordingsPage(courseId: widget.courseId, role: _role),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    title: Localizations.localeOf(context).languageCode == 'ar'
                        ? 'ملحقات ومراجع'
                        : 'Course Materials',
                    subtitle: Localizations.localeOf(context).languageCode == 'ar'
                        ? 'ملفات PDF وصور'
                        : 'PDFs & Templates',
                    icon: Icons.auto_stories_rounded,
                    color: Colors.tealAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CourseMaterialsPage(
                            courseId: widget.courseId,
                            courseName: courseName,
                            isTeacher: isTeacher,
                            isAdmin: userRole == 'admin',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.viewAndManageStudents,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            _buildEnrolledStudentsList(),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: Localizations.localeOf(context).languageCode == 'ar'
                        ? 'ملحقات ومراجع'
                        : 'Course Materials',
                    subtitle: Localizations.localeOf(context).languageCode == 'ar'
                        ? 'ملفات PDF وصور'
                        : 'PDFs & Templates',
                    icon: Icons.auto_stories_rounded,
                    color: Colors.tealAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CourseMaterialsPage(
                            courseId: widget.courseId,
                            courseName: courseName,
                            isTeacher: isTeacher,
                            isAdmin: userRole == 'admin',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                const Spacer(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launchClassroom() async {
    try {
      debugPrint("DEBUG: Classroom logic triggered for course: ${widget.courseId}");

      /* 🚫 SMART GATING DISABLED AT USER REQUEST (For testing and ad-hoc sessions)
      if (!isTeacher) {
        // Smart Gating Logic for Students
        final now = DateTime.now();
        
        // 1. Effective start: the class going on or the next one, moves included (the schedule rule).
        final current = _schedule?.live(now) ?? _schedule?.next(now);
        final DateTime effectiveStart = current?.start.toLocal() ?? now;

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

      // ── STEP 1: Request camera & microphone permissions at runtime ──
      // On Android 6+, manifest declarations alone are NOT enough.
      // Without this the camera / microphone stay off in the classroom and no
      // permission dialog is ever shown.
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
        // User clicked "Don't ask again" — guide them to settings
        if (mounted) {
          AppMessenger.showSnackBar(
            context,
            title: "Permissions Required",
            message:
                "Camera and microphone access are required for the classroom. Please enable them in your device settings.",
            type: MessengerType.error,
          );
        }
        await openAppSettings();
        return;
      }

      if (cameraStatus.isDenied || micStatus.isDenied) {
        if (mounted) {
          AppMessenger.showSnackBar(
            context,
            title: "Permissions Denied",
            message:
                "Camera and microphone access are needed to join the classroom.",
            type: MessengerType.error,
          );
        }
        return;
      }
      // ─────────────────────────────────────────────────────────────────

      final user = FirebaseAuth.instance.currentUser;
      String userName = user?.displayName ?? "User";
      String userEmail = user?.email ?? "";
      String userAvatar = user?.photoURL ?? "";

      // Fetch the true full name and photo URL from Firestore
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            if (data != null) {
              if (data['fullName'] != null &&
                  data['fullName'].toString().isNotEmpty) {
                userName = data['fullName'];
              } else if (data['name'] != null &&
                  data['name'].toString().isNotEmpty) {
                userName = data['name'];
              }
              if (data['photoUrl'] != null &&
                  data['photoUrl'].toString().isNotEmpty) {
                userAvatar = data['photoUrl'];
              }
            }
          }
        } catch (e) {
          debugPrint("Failed to fetch user doc for classroom: $e");
        }
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppMessenger.showSnackBar(
          context,
          title: l10n.startingClassroom,
          message: l10n.pleaseWaitConnecting,
          type: MessengerType.info,
        );
      }

      try {
        // (The old "already in the meeting" check read heartbeats nothing has
        // written since the move to LiveKit — it could never trigger. LiveKit
        // itself replaces a connection that uses the same identity.)
        await LiveKitMeetService().joinMeeting(
          context: context,
          courseId: widget.courseId,
          isTeacher: isTeacher,
        )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception(
                  "Connecting to the classroom timed out. Please check your internet connection.",
                );
              },
            );
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
    } catch (outerErr) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: "Launch Error",
          message: "Could not launch classroom: $outerErr",
          type: MessengerType.error,
        );
      }
    }
  }

  void _openCourseChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseChatPage(
          courseId: widget.courseId,
          courseName: courseName,
          courseTeacherId:
              courseTeacherId ?? widget.courseData['teacherId']?.toString(),
          isTeacher: isTeacher,
          isAdmin: userRole == 'admin',
        ),
      ),
    );
  }
}
