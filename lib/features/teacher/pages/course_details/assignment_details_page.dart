import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:io';

class AssignmentDetailsPage extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final Map<String, dynamic> assignmentData;

  const AssignmentDetailsPage({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentData,
  });

  @override
  State<AssignmentDetailsPage> createState() => _AssignmentDetailsPageState();
}

class _AssignmentDetailsPageState extends State<AssignmentDetailsPage> {
  final TextEditingController _noteController = TextEditingController();
  PlatformFile? _pickedFile;
  bool _isSubmitting = false;
  Map<String, dynamic>? _existingSubmission;
  bool _isLoadingSubmission = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fetchExistingSubmission();
  }

  Future<void> _fetchExistingSubmission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _existingSubmission = doc.data();
          if (_existingSubmission != null) {
            _noteController.text = _existingSubmission!['note'] ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching submission: $e");
    } finally {
      if (mounted) setState(() => _isLoadingSubmission = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && mounted) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _submitAssignment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_pickedFile == null && _existingSubmission == null) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: AppLocalizations.of(context)!.pleasePickFile,
        type: MessengerType.info,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? fileUrl = _existingSubmission?['fileUrl'];
      String? fileName = _existingSubmission?['fileName'];

      // 1. Upload new file if picked
      if (_pickedFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('course_submissions')
            .child(widget.courseId)
            .child(widget.assignmentId)
            .child('${user.uid}_${_pickedFile!.name}');

        final uploadTask = await storageRef.putFile(File(_pickedFile!.path!));
        fileUrl = await uploadTask.ref.getDownloadURL();
        fileName = _pickedFile!.name;
      }

      // 2. Fetch User Name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final String studentName = userDoc.data()?['name'] ?? 'Student';
      final String? studentImage = userDoc.data()?['photoUrl'];

      // 3. Update/Create Submission
      final submissionRef = FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(user.uid);

      await submissionRef.set({
        'note': _noteController.text.trim(),
        'fileUrl': fileUrl,
        'fileName': fileName,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': _existingSubmission?['status'] ?? 'submitted',
        'points': _existingSubmission?['points'] ?? 0,
        'studentName': studentName,
        'studentImage': studentImage,
        'studentId': user.uid,
      });

      // 4. Update submissionCount on assignment (only if new)
      if (_existingSubmission == null) {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .update({
          'submissionCount': FieldValue.increment(1),
        });
      }

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.assignmentSubmitted,
          type: MessengerType.success,
        );
        setState(() {
          _isEditing = false;
          _pickedFile = null;
        });
        _fetchExistingSubmission();
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteSubmission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(AppLocalizations.of(context)!.deleteSubmission, style: const TextStyle(color: Colors.white)),
        content: Text(AppLocalizations.of(context)!.deleteSubmissionConfirm, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.close, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(AppLocalizations.of(context)!.deleteCaps, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Delete from Firestore
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(user.uid)
          .delete();

      // 2. Decrement submissionCount
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .update({
        'submissionCount': FieldValue.increment(-1),
      });

      // 3. Clear State
      if (mounted) {
        setState(() {
          _existingSubmission = null;
          _noteController.clear();
          _pickedFile = null;
          _isEditing = false;
        });
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.deleted,
          type: MessengerType.success,
        );
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueDate = (widget.assignmentData['dueDate'] as Timestamp).toDate();
    final isExpired = DateTime.now().isAfter(dueDate);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(l10n.assignmentDetails, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingSubmission 
        ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Block
                _buildHeader(l10n, dueDate, isExpired)
                  .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 32),

                // Instructions
                _buildSectionTitle(l10n.instructions, Icons.info_outline)
                  .animate().fadeIn(duration: 400.ms, delay: 100.ms),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Text(
                    widget.assignmentData['instructions'] ?? l10n.noInstructionsProvided,
                    style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: 32),

                // Submission Section
                _buildSectionTitle(l10n.yourSubmission, Icons.drive_folder_upload_rounded)
                  .animate().fadeIn(duration: 400.ms, delay: 300.ms),
                const SizedBox(height: 16),

                if (_existingSubmission != null && !_isEditing) 
                  _buildStatusBadge(l10n).animate().fadeIn(duration: 400.ms, delay: 350.ms),

                const SizedBox(height: 16),
                
                if (_existingSubmission == null || _isEditing) ...[
                  _buildFilePicker(l10n).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                  const SizedBox(height: 20),
                  _buildNoteField(l10n).animate().fadeIn(duration: 400.ms, delay: 450.ms),
                  const SizedBox(height: 40),
                  _buildSubmitButton(l10n, isExpired).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                ] else ...[
                   _buildPostSubmissionActions(l10n, isExpired).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, DateTime dueDate, bool isExpired) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.assignmentData['title'],
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 20),
              _buildHeaderInfo(
                icon: Icons.calendar_today_rounded,
                label: l10n.deadline,
                value: DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(dueDate),
                color: isExpired ? Colors.redAccent : AppColors.accentGold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo({required IconData icon, required String label, required String value, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          softWrap: true,
          maxLines: 3,
          overflow: TextOverflow.visible,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentGold, size: 20),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusBadge(AppLocalizations l10n) {
    final status = _existingSubmission!['status'] ?? 'submitted';
    final isGraded = status == 'graded';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isGraded ? Colors.green.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isGraded ? Colors.green.withOpacity(0.15) : Colors.blue.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGraded ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(isGraded ? Icons.check_circle_rounded : Icons.history_rounded, size: 20, color: isGraded ? Colors.greenAccent : Colors.blueAccent),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGraded ? l10n.graded : l10n.submitted,
                    style: TextStyle(color: isGraded ? Colors.greenAccent : Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  Text(
                    DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format((_existingSubmission!['submittedAt'] as Timestamp).toDate()),
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          if (isGraded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rate_review_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    l10n.feedback,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilePicker(AppLocalizations l10n) {
    final String? fileName = _pickedFile?.name ?? _existingSubmission?['fileName'];

    return InkWell(
      onTap: _pickFile,
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(fileName != null ? Icons.file_present : Icons.add_circle_outline, color: AppColors.accentGold, size: 30),
            const SizedBox(height: 8),
            Text(
              fileName ?? l10n.attachWorkFile,
              style: TextStyle(color: fileName != null ? Colors.white : Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField(AppLocalizations l10n) {
    return TextField(
      controller: _noteController,
      maxLines: 4,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: l10n.addNoteOptional,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n, bool isExpired) {
    final bool isUpdate = _existingSubmission != null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_isSubmitting || (isExpired && !isUpdate)) ? null : _submitAssignment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : Text(
                (isUpdate ? l10n.updateSubmission : l10n.submitAssignment).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
      ),
    );
  }

  Widget _buildPostSubmissionActions(AppLocalizations l10n, bool isExpired) {
    final String? fileName = _existingSubmission?['fileName'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Always show submitted file (read-only) if one exists
        if (fileName != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.attach_file_rounded, color: AppColors.accentGold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                // Lock icon to indicate non-editable
                if (isExpired)
                  const Icon(Icons.lock_rounded, color: Colors.white24, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isExpired)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.deadlinePassed,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    label: Text(l10n.editSubmission.toUpperCase()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _deleteSubmission,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: Text(l10n.deleteSubmission.toUpperCase()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
