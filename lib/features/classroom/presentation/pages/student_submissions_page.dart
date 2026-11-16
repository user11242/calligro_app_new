import 'package:flutter/material.dart';
import 'package:calligro_app/features/classroom/application/classroom_assignments.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/presentation/classroom_scope.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'package:photo_view/photo_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/features/classroom/presentation/pages/submission_watermark_helper.dart';

class StudentSubmissionsPage extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String assignmentTitle;

  /// The viewer's role in THIS course (only its teacher / an admin sees work).
  final CourseRole role;

  const StudentSubmissionsPage({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentTitle,
    this.role = CourseRole.owner,
  });

  @override
  State<StudentSubmissionsPage> createState() => _StudentSubmissionsPageState();
}

class _StudentSubmissionsPageState extends State<StudentSubmissionsPage> {
  ClassroomAssignments? _work;
  Stream<List<Submission>>? _submissions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_work != null) return;
    _work = ClassroomScope.of(context).assignments;
    _submissions = _work!.repository.watchSubmissions(widget.courseId, widget.assignmentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.submissions,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              widget.assignmentTitle,
              style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
      body: StreamBuilder<List<Submission>>(
        stream: _submissions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 60, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.noSubmissionsYet, style: const TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final submission = snapshot.data![index];
              return _SubmissionCard(
                submission: submission,
                assignmentTitle: widget.assignmentTitle,
                onToggleSeen: (seen) =>
                    _work!.setSeen(widget.courseId, widget.assignmentId, submission.studentId, widget.role, seen),
              ).animate().fadeIn(duration: 400.ms, delay: (index * 100).ms).slideY(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  final Submission submission;
  final String assignmentTitle;
  final Future<ClassroomResult> Function(bool seen) onToggleSeen;

  const _SubmissionCard({required this.submission, required this.assignmentTitle, required this.onToggleSeen});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _isExpanded = false;
  bool _isDownloading = false;

  Future<void> _toggleSeen(bool currentValue) async {
    try {
      final r = await widget.onToggleSeen(!currentValue);
      if (!r.ok) debugPrint("Error updating seen status: ${r.message ?? r.outcome.name}");
    } catch (e) {
      debugPrint("Error updating seen status: $e");
    }
  }

  bool _isImageFile(String url, String name) {
    final lowerName = name.toLowerCase();
    final lowerUrl = url.toLowerCase();
    return lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.heic') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.webp');
  }

  Future<void> _saveImageToGallery(String url, String name, String studentName, String timeStr) async {
    if (_isDownloading) return;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    setState(() => _isDownloading = true);

    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        if (mounted) {
          AppMessenger.showSnackBar(
            context,
            title: 'تنبيه',
            message: 'يرجى السماح بالوصول إلى ألبوم الصور لحفظ التسليم',
            type: MessengerType.error,
          );
        }
        return;
      }

      final file = await DefaultCacheManager().getSingleFile(url);
      Uint8List bytes = await file.readAsBytes();

      if (SubmissionWatermarkHelper.isSupportedImage(name) || SubmissionWatermarkHelper.isSupportedImage(url)) {
        try {
          bytes = await SubmissionWatermarkHelper.stampImageBytes(
            imageBytes: bytes,
            studentName: studentName,
            assignmentTitle: widget.assignmentTitle,
            teacherName: 'Teacher',
            isRtl: isRtl,
          );
        } catch (e) {
          debugPrint("Error watermarking on download: $e");
        }
      }

      final title = name.isNotEmpty ? name : 'submission_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await PhotoManager.editor.saveImage(bytes, title: title, filename: title);

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'تم الحفظ',
          message: 'تم حفظ الصورة مع بيانات الطالب في ألبوم الصور بنجاح 📸',
          type: MessengerType.success,
        );
      }
    } catch (e) {
      debugPrint("Error saving to gallery: $e");
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'خطأ',
          message: 'حدث خطأ أثناء حفظ الصورة',
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _openFile(String url, String name, String studentName, String timeStr) {
    if (_isImageFile(url, name)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubmissionImageViewerPage(
            imageUrl: url,
            title: name,
            studentName: studentName,
            assignmentTitle: widget.assignmentTitle,
            submittedAtStr: timeStr,
          ),
        ),
      );
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.submission;
    final bool isSeen = sub.seenByTeacher;
    final submittedAt = sub.submittedAt;
    final timeStr = submittedAt != null
        ? DateFormat('MMM d, h:mm a', Localizations.localeOf(context).toString()).format(submittedAt)
        : '';
    final String? photoUrl = sub.studentImage;
    final String studentName = sub.studentName.isEmpty ? 'Unknown Student' : sub.studentName;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isSeen ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          // Own transparent Material so the tile's ink is not hidden by the card colour.
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
              leading: _buildAvatar(photoUrl, studentName),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      studentName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  if (isSeen)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                    ),
                ],
              ),
              subtitle: Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              trailing: AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentGold.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGold, size: 20),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      if (sub.note.isNotEmpty) ...[
                        Text(
                          AppLocalizations.of(context)!.studentNote,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(sub.note, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 16),
                      ],
                      if (sub.fileUrl != null)
                        _buildFileAction(sub.fileUrl!, sub.fileName ?? 'submission_file', studentName, timeStr),

                      const SizedBox(height: 20),
                      // Mark as seen toggle
                      InkWell(
                        onTap: () => _toggleSeen(isSeen),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSeen ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSeen ? Colors.green.withOpacity(0.3) : Colors.white10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSeen ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isSeen ? Colors.greenAccent : Colors.white38,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isSeen
                                    ? AppLocalizations.of(context)!.markedAsReviewed
                                    : AppLocalizations.of(context)!.markAsReviewed,
                                style: TextStyle(
                                  color: isSeen ? Colors.greenAccent : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.accentGold.withOpacity(0.15),
      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold, fontSize: 18),
            )
          : null,
    );
  }

  Widget _buildFileAction(String url, String name, String studentName, String timeStr) {
    final bool isImage = _isImageFile(url, name);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _openFile(url, name, studentName, timeStr),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(
                    isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                    color: AppColors.accentGold,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(isImage ? Icons.visibility_outlined : Icons.open_in_new, color: Colors.white38, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () {
            if (isImage) {
              _saveImageToGallery(url, name, studentName, timeStr);
            } else {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
            ),
            child: _isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accentGold),
                  )
                : const Icon(Icons.download_rounded, color: AppColors.accentGold, size: 24),
          ),
        ),
      ],
    );
  }
}

/// Full-screen zoomable image viewer (WhatsApp-style) with student info banner & watermarking on save
class SubmissionImageViewerPage extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String studentName;
  final String assignmentTitle;
  final String? submittedAtStr;

  const SubmissionImageViewerPage({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.studentName,
    required this.assignmentTitle,
    this.submittedAtStr,
  });

  @override
  State<SubmissionImageViewerPage> createState() => _SubmissionImageViewerPageState();
}

class _SubmissionImageViewerPageState extends State<SubmissionImageViewerPage> {
  bool _isSaving = false;
  bool _showBanner = true;

  Future<void> _saveToPhotos() async {
    if (_isSaving) return;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    setState(() => _isSaving = true);

    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        if (mounted) {
          AppMessenger.showSnackBar(
            context,
            title: 'تنبيه',
            message: 'يرجى السماح بالوصول إلى ألبوم الصور لحفظ التسليم',
            type: MessengerType.error,
          );
        }
        return;
      }

      final file = await DefaultCacheManager().getSingleFile(widget.imageUrl);
      Uint8List bytes = await file.readAsBytes();

      // Stamp watermark if it's an image
      if (SubmissionWatermarkHelper.isSupportedImage(widget.title) ||
          SubmissionWatermarkHelper.isSupportedImage(widget.imageUrl)) {
        try {
          bytes = await SubmissionWatermarkHelper.stampImageBytes(
            imageBytes: bytes,
            studentName: widget.studentName,
            assignmentTitle: widget.assignmentTitle,
            teacherName: 'Teacher',
            isRtl: isRtl,
          );
        } catch (e) {
          debugPrint('Watermark error during viewer save: $e');
        }
      }

      final title = widget.title.isNotEmpty ? widget.title : 'submission_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await PhotoManager.editor.saveImage(bytes, title: title, filename: title);

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'تم الحفظ',
          message: 'تم حفظ الصورة مع بيانات الطالب في ألبوم الصور بنجاح 📸',
          type: MessengerType.success,
        );
      }
    } catch (e) {
      debugPrint("Error saving to gallery: $e");
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'خطأ',
          message: 'حدث خطأ أثناء حفظ الصورة',
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(_showBanner ? Icons.info : Icons.info_outline, color: AppColors.accentGold),
            tooltip: _showBanner ? 'إخفاء معلومات الطالب' : 'إظهار معلومات الطالب',
            onPressed: () => setState(() => _showBanner = !_showBanner),
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
                  )
                : const Icon(Icons.download_rounded, color: AppColors.accentGold),
            tooltip: 'حفظ في الصور',
            onPressed: _isSaving ? null : _saveToPhotos,
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoView(
            imageProvider: CachedNetworkImageProvider(widget.imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            loadingBuilder: (context, event) =>
                const Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white38, size: 60),
                  SizedBox(height: 12),
                  Text('تعذر تحميل الصورة', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          ),

          // Floating Student Info Banner (Dark theme with Gold border)
          if (_showBanner)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xF518181B), // Dark solid non-white background
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accentGold, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.accentGold.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: AppColors.accentGold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.assignmentTitle,
                            style: const TextStyle(color: Color(0xFFEEE593), fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text(
                                'الطالب: ',
                                style: TextStyle(
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  widget.studentName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (widget.submittedAtStr != null && widget.submittedAtStr!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(widget.submittedAtStr!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      tooltip: 'إخفاء',
                      onPressed: () => setState(() => _showBanner = false),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
