import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'assignment_details_page.dart';
import 'student_submissions_page.dart';
import 'dart:ui';

class AssignmentsPage extends StatefulWidget {
  final String courseId;
  final bool isTeacher;

  const AssignmentsPage({
    super.key,
    required this.courseId,
    this.isTeacher = false,
  });

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  // Points controller removed
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedTime;

  // --- LOGIC: CREATE ASSIGNMENT ---
  Future<void> _createAssignment() async {
    if (_titleController.text.isEmpty ||
        _selectedDueDate == null ||
        _selectedTime == null) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.required,
        message: AppLocalizations.of(context)!.titleDateTimeRequired,
        type: MessengerType.info,
      );
      return;
    }

    // Combine Date and Time
    final DateTime finalDeadline = DateTime(
      _selectedDueDate!.year,
      _selectedDueDate!.month,
      _selectedDueDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    await FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .collection('assignments')
        .add({
          'title': _titleController.text.trim(),
          'instructions': _instructionsController.text.trim(),
          'dueDate': Timestamp.fromDate(finalDeadline),
          'createdAt': FieldValue.serverTimestamp(),
          'submissionCount': 0,
        });

    _titleController.clear();
    _instructionsController.clear();
    setState(() {
      _selectedDueDate = null;
      _selectedTime = null;
    });
    
    if (!mounted) return;
    Navigator.pop(context);
  }

  // --- UI: MODERN CREATE SHEET ---
  void _showCreateAssignmentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
            left: 24,
            right: 24,
            top: 30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.newTask,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildTextField(_titleController, AppLocalizations.of(context)!.taskTitle, Icons.title),
              const SizedBox(height: 16),

              _buildTextField(
                _instructionsController,
                AppLocalizations.of(context)!.instructionsOptional,
                Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Date, Time & Points Row
              Row(
                children: [
                  // 1. DATE PICKER
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          builder: (context, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.accentGold,
                                onPrimary: Colors.black,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                          if (date != null && context.mounted) {
                            setDialogState(() => _selectedDueDate = date);
                            // Auto-trigger Time Picker
                            final time = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 23, minute: 59),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.accentGold,
                                  onPrimary: Colors.black,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (time != null) {
                            setDialogState(() => _selectedTime = time);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedDueDate != null
                                ? AppColors.accentGold
                                : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: _selectedDueDate != null
                                  ? AppColors.accentGold
                                  : Colors.white54,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                _selectedDueDate == null
                                    ? AppLocalizations.of(context)!.setDeadline
                                    : "${DateFormat('MMM d', Localizations.localeOf(context).toString()).format(_selectedDueDate!)}, ${_selectedTime?.format(context) ?? '--:--'}",
                                style: TextStyle(
                                  color: _selectedDueDate != null
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                ],
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _createAssignment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: AppColors.accentGold.withOpacity(0.4),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.assignTask.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .orderBy('dueDate', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final totalAssignments = docs.length;
          final activeAssignments = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final dueDate = (data['dueDate'] as Timestamp).toDate();
            return DateTime.now().isBefore(dueDate);
          }).length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. PREMIUM DYNAMIC HEADER
              SliverAppBar(
                expandedHeight: 240.0,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.primary,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 24.0), // Increased space from edge using Directional
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                leadingWidth: 70, // Ensure enough width for the padded leading
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient & Pattern
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.accentGold.withOpacity(0.15),
                              AppColors.primary,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: -30,
                        top: -20,
                        child: Icon(
                          Icons.assignment_rounded,
                          size: 220,
                          color: Colors.white.withOpacity(0.03),
                        ),
                      ),
                      // CONTENT: Title and Stats Row
                      Positioned(
                        bottom: 30,
                        left: 24,
                        right: 24,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.assignments,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _buildHeaderStat(
                                  label: l10n.activeCaps,
                                  value: activeAssignments.toString(),
                                  icon: Icons.rocket_launch_rounded,
                                  color: Colors.greenAccent,
                                ),
                                const SizedBox(width: 16),
                                _buildHeaderStat(
                                  label: l10n.totalCaps,
                                  value: totalAssignments.toString(),
                                  icon: Icons.folder_rounded,
                                  color: AppColors.accentGold,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
                actions: [
                  if (widget.isTeacher)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 24.0), // Increased space from edge using Directional
                      child: Center(
                        child: _buildCreateButton(),
                      ),
                    ),
                ],
              ),

              // 2. ASSIGNMENTS LIST
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
                )
              else if (docs.isEmpty)
                _buildEmptyState()
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 16, bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final assignmentId = docs[index].id;
                        return _buildModernAssignmentCard(data, assignmentId, index);
                      },
                      childCount: docs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
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
    );
  }

  Widget _buildCreateButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCreateAssignmentDialog,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accentGold,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGold.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.black, size: 22),
        ),
      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
       .shimmer(duration: 2.seconds, color: Colors.white24),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Icon(
                Icons.assignment_turned_in_rounded,
                color: Colors.white.withOpacity(0.1),
                size: 64,
              ),
            ).animate(onPlay: (c) => c.repeat())
             .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.05, 1.05), curve: Curves.easeInOut)
             .then()
             .scale(duration: 2.seconds, begin: const Offset(1.05, 1.05), end: const Offset(1, 1), curve: Curves.easeInOut),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noTasksAssignedYet,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAssignmentCard(Map<String, dynamic> data, String assignmentId, int index) {
    final dueDate = (data['dueDate'] as Timestamp).toDate();
    final isExpired = DateTime.now().isAfter(dueDate);
    final l10n = AppLocalizations.of(context)!;
    final String locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.yMMMd(locale).format(dueDate);
    final timeStr = DateFormat.jm(locale).format(dueDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: InkWell(
            onTap: () {
              if (widget.isTeacher) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentSubmissionsPage(
                      courseId: widget.courseId,
                      assignmentId: assignmentId,
                      assignmentTitle: data['title'] ?? 'Untitled',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssignmentDetailsPage(
                      courseId: widget.courseId,
                      assignmentId: assignmentId,
                      assignmentData: data,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge row (no marks badge)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isExpired ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          isExpired ? AppLocalizations.of(context)!.closedCaps : AppLocalizations.of(context)!.activeCaps,
                          style: TextStyle(
                            color: isExpired ? Colors.redAccent : Colors.greenAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data['title'] ?? "Untitled",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 8),
                      Text(
                        "$dateStr • $timeStr",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (widget.isTeacher) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Live submission count via StreamBuilder
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('courses')
                              .doc(widget.courseId)
                              .collection('assignments')
                              .doc(assignmentId)
                              .collection('submissions')
                              .snapshots(),
                          builder: (context, subSnap) {
                            final count = subSnap.data?.docs.length ?? 0;
                            return _buildSubStat(
                              icon: Icons.people_rounded,
                              label: l10n.submissions,
                              value: count.toString(),
                            );
                          },
                        ),
                        const Spacer(),
                        // Arrow indicator to hint the card is tappable
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.accentGold,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    _buildTimeProgressBar(dueDate),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSubStat({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.white54),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeProgressBar(DateTime dueDate) {
    final now = DateTime.now();
    final remaining = dueDate.difference(now);
    
    double progress = isSameDay(now, dueDate) ? 1.0 : 0.5; // Default for now
    if (now.isAfter(dueDate)) {
      progress = 1.0;
    } else {
       // Estimate progress based on a 7-day window
       final double p = 1.0 - (remaining.inSeconds / (7 * 24 * 3600)).clamp(0.0, 1.0);
       progress = p;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              now.isAfter(dueDate)
                  ? AppLocalizations.of(context)!.expired
                  : AppLocalizations.of(context)!.daysRemaining(remaining.inDays),
              style: TextStyle(
                color: now.isAfter(dueDate) ? Colors.redAccent : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${(progress * 100).toInt()}%",
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.05),
            color: now.isAfter(dueDate) ? Colors.redAccent.withOpacity(0.3) : AppColors.accentGold,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
