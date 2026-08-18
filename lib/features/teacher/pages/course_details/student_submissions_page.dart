import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:photo_view/photo_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/core/message/app_messenger.dart';

class StudentSubmissionsPage extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String assignmentTitle;

  const StudentSubmissionsPage({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<StudentSubmissionsPage> createState() => _StudentSubmissionsPageState();
}

class _StudentSubmissionsPageState extends State<StudentSubmissionsPage> {
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
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('submissions')
            .orderBy('submittedAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              return _SubmissionCard(doc: doc)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (index * 100).ms)
                  .slideY(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _SubmissionCard({required this.doc});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _isExpanded = false;
  bool _isDownloading = false;

  Future<void> _toggleSeen(bool currentValue) async {
    try {
      await widget.doc.reference.update({'seenByTeacher': !currentValue});
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

  Future<void> _saveImageToGallery(String url, String name) async {
    if (_isDownloading) return;
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
      final bytes = await file.readAsBytes();

      final title = name.isNotEmpty ? name : 'submission_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await PhotoManager.editor.saveImage(
        bytes,
        title: title,
        filename: title,
      );

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'تم الحفظ',
          message: 'تم حفظ الصورة في ألبوم الصور بنجاح 📸',
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

  void _openFile(String url, String name) {
    if (_isImageFile(url, name)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubmissionImageViewerPage(
            imageUrl: url,
            title: name,
          ),
        ),
      );
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final bool isSeen = data['seenByTeacher'] ?? false;
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final timeStr = submittedAt != null
        ? DateFormat('MMM d, h:mm a', Localizations.localeOf(context).toString()).format(submittedAt)
        : '';
    final String? photoUrl = data['studentImage'] as String?;
    final String studentName = data['studentName'] ?? 'Unknown Student';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSeen ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.accentGold,
                  size: 20,
                ),
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
                    if (data['note'] != null && data['note'].toString().isNotEmpty) ...[
                      Text(
                        AppLocalizations.of(context)!.studentNote,
                        style: const TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(data['note'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 16),
                    ],
                    if (data['fileUrl'] != null)
                      _buildFileAction(data['fileUrl'], data['fileName'] ?? 'submission_file'),
                    
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

  Widget _buildFileAction(String url, String name) {
    final bool isImage = _isImageFile(url, name);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _openFile(url, name),
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
                  Icon(
                    isImage ? Icons.visibility_outlined : Icons.open_in_new,
                    color: Colors.white38,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () {
            if (isImage) {
              _saveImageToGallery(url, name);
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.accentGold,
                    ),
                  )
                : const Icon(
                    Icons.download_rounded,
                    color: AppColors.accentGold,
                    size: 24,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen zoomable image viewer (WhatsApp-style)
class SubmissionImageViewerPage extends StatefulWidget {
  final String imageUrl;
  final String title;

  const SubmissionImageViewerPage({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  State<SubmissionImageViewerPage> createState() => _SubmissionImageViewerPageState();
}

class _SubmissionImageViewerPageState extends State<SubmissionImageViewerPage> {
  bool _isSaving = false;

  Future<void> _saveToPhotos() async {
    if (_isSaving) return;
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
      final bytes = await file.readAsBytes();

      final title = widget.title.isNotEmpty ? widget.title : 'submission_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await PhotoManager.editor.saveImage(
        bytes,
        title: title,
        filename: title,
      );

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'تم الحفظ',
          message: 'تم حفظ الصورة في ألبوم الصور بنجاح 📸',
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
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(widget.imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold),
        ),
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
    );
  }
}
