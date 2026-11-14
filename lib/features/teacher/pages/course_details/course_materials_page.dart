import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:printing/printing.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/message/app_messenger.dart';

// ============================================================================
// DATA MODELS (WITH RETROACTIVE BACKWARD COMPATIBILITY)
// ============================================================================

class CourseMaterialFileItem {
  final String title;
  final String fileName;
  final String fileUrl;
  final String fileSize;
  final String storagePath;
  final String type; // 'pdf' or 'image'

  CourseMaterialFileItem({
    required this.title,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.storagePath,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'storagePath': storagePath,
      'type': type,
    };
  }

  factory CourseMaterialFileItem.fromMap(Map<String, dynamic> map, {String fallbackType = 'image'}) {
    return CourseMaterialFileItem(
      title: map['title'] ?? map['fileName'] ?? '',
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      fileSize: map['fileSize'] ?? '',
      storagePath: map['storagePath'] ?? '',
      type: map['type'] ?? fallbackType,
    );
  }
}

class CourseMaterialFolder {
  final String id;
  final String title;
  final String type; // 'pdf', 'image', or 'folder'
  final String totalSize;
  final String? previewUrl;
  final DateTime? createdAt;
  final String uploadedByName;
  final List<CourseMaterialFileItem> files;

  CourseMaterialFolder({
    required this.id,
    required this.title,
    required this.type,
    required this.totalSize,
    this.previewUrl,
    this.createdAt,
    required this.uploadedByName,
    required this.files,
  });

  bool get isPdf => type == 'pdf' || (files.isNotEmpty && files.every((f) => f.type == 'pdf'));
  int get itemCount => files.length;

  factory CourseMaterialFolder.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final String type = data['type'] ?? 'image';
    final List<CourseMaterialFileItem> parsedFiles = [];

    // 1. If it has a modern 'files' list
    if (data['files'] is List && (data['files'] as List).isNotEmpty) {
      for (final f in data['files'] as List) {
        if (f is Map) {
          parsedFiles.add(CourseMaterialFileItem.fromMap(
            Map<String, dynamic>.from(f),
            fallbackType: type,
          ));
        }
      }
    } else if (data['fileUrl'] != null && (data['fileUrl'] as String).isNotEmpty) {
      // 2. Legacy single-item document
      parsedFiles.add(CourseMaterialFileItem(
        title: data['title'] ?? '',
        fileName: data['fileName'] ?? '',
        fileUrl: data['fileUrl'] ?? '',
        fileSize: data['fileSize'] ?? '',
        storagePath: data['storagePath'] ?? '',
        type: type,
      ));
    }

    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    }

    String preview = data['previewUrl'] ?? '';
    if (preview.isEmpty && parsedFiles.isNotEmpty) {
      final img = parsedFiles.firstWhere(
        (f) => f.type == 'image',
        orElse: () => parsedFiles.first,
      );
      if (img.type == 'image') preview = img.fileUrl;
    }

    return CourseMaterialFolder(
      id: doc.id,
      title: data['title'] ?? 'مجلد الملحقات',
      type: type,
      totalSize: data['totalSize'] ?? data['fileSize'] ?? '',
      previewUrl: preview.isNotEmpty ? preview : null,
      createdAt: created,
      uploadedByName: data['uploadedByName'] ?? 'Instructor',
      files: parsedFiles,
    );
  }
}

// ============================================================================
// MAIN PAGE: FOLDERS LIST
// ============================================================================

class CourseMaterialsPage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final bool isTeacher;
  final bool isAdmin;

  const CourseMaterialsPage({
    super.key,
    required this.courseId,
    required this.courseName,
    this.isTeacher = false,
    this.isAdmin = false,
  });

  @override
  State<CourseMaterialsPage> createState() => _CourseMaterialsPageState();
}

class _CourseMaterialsPageState extends State<CourseMaterialsPage> {
  String _selectedFilter = 'all'; // 'all', 'pdf', 'image'
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusText = '';

  bool get _canManage => widget.isTeacher || widget.isAdmin;

  @override
  Widget build(BuildContext context) {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          isArabic ? "ملحقات ومراجع الدورة" : "Course Materials & References",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.create_new_folder_rounded, size: 22),
              label: Text(
                isArabic ? "إضافة مجلد ملحقات" : "Add Material Folder",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _showUploadOptionsSheet,
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              // Info banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_shared_rounded, color: AppColors.accentGold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isArabic
                            ? "مجلدات منظمة لكراسات التمارين، ملفات PDF، ونماذج الخط العربي القابلة للتحميل."
                            : "Organized folders for worksheets, PDFs, and downloadable calligraphy samples.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: isArabic ? "كل المجلدات" : "All Folders",
                      value: 'all',
                      icon: Icons.folder_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: isArabic ? "مستندات PDF" : "PDFs",
                      value: 'pdf',
                      icon: Icons.picture_as_pdf_rounded,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: isArabic ? "صور ومخطوطات" : "Images",
                      value: 'image',
                      icon: Icons.photo_library_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Materials Folders Stream
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection('materials')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.accentGold),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          isArabic ? "حدث خطأ أثناء تحميل المجلدات" : "Error loading folders",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final folders = docs
                        .map((d) => CourseMaterialFolder.fromDoc(d))
                        .where((folder) {
                      if (_selectedFilter == 'all') return true;
                      if (_selectedFilter == 'pdf') return folder.isPdf;
                      if (_selectedFilter == 'image') return !folder.isPdf;
                      return true;
                    }).toList();

                    if (folders.isEmpty) {
                      return _buildEmptyState(isArabic);
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: folders.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        return _buildFolderCard(folder, isArabic);
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // Uploading overlay indicator
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22242B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.accentGold),
                      const SizedBox(height: 20),
                      Text(
                        _uploadStatusText.isNotEmpty
                            ? _uploadStatusText
                            : (isArabic ? "جاري إنشاء المجلد ورفع الملفات..." : "Creating folder and uploading files..."),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          color: AppColors.accentGold,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${(_uploadProgress * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final bool isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderCard(CourseMaterialFolder folder, bool isArabic) {
    final dateStr = folder.createdAt != null
        ? DateFormat('yyyy/MM/dd - hh:mm a').format(folder.createdAt!)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2026),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseMaterialFolderPage(
                  courseId: widget.courseId,
                  folder: folder,
                  isTeacher: widget.isTeacher,
                  isAdmin: widget.isAdmin,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Folder / Thumbnail Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: folder.previewUrl != null
                        ? CachedNetworkImage(
                            imageUrl: folder.previewUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.purple.withValues(alpha: 0.15),
                              child: const Icon(Icons.photo_library_rounded, color: Colors.purpleAccent, size: 28),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.purple.withValues(alpha: 0.15),
                              child: const Icon(Icons.folder_rounded, color: AppColors.accentGold, size: 28),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: folder.isPdf
                                    ? [Colors.redAccent.withValues(alpha: 0.3), Colors.redAccent.withValues(alpha: 0.1)]
                                    : [AppColors.accentGold.withValues(alpha: 0.3), AppColors.accentGold.withValues(alpha: 0.08)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              folder.isPdf ? Icons.folder_zip_rounded : Icons.folder_rounded,
                              color: folder.isPdf ? Colors.redAccent : AppColors.accentGold,
                              size: 32,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: folder.isPdf
                                  ? Colors.redAccent.withValues(alpha: 0.15)
                                  : Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              folder.isPdf
                                  ? (folder.itemCount <= 1 ? "مستند PDF" : "${folder.itemCount} ملفات PDF")
                                  : (isArabic ? "${folder.itemCount} صور" : "${folder.itemCount} Images"),
                              style: TextStyle(
                                color: folder.isPdf ? Colors.redAccent : Colors.purpleAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (folder.totalSize.isNotEmpty)
                            Text(
                              folder.totalSize,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action buttons: Download All, Share, Menu
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Download Folder / Files Button
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.accentGold),
                      tooltip: isArabic ? "تحميل محتويات المجلد" : "Download Folder",
                      onPressed: () => _downloadEntireFolder(folder),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white70),
                      tooltip: isArabic ? "مشاركة" : "Share",
                      onPressed: () {
                        if (folder.files.isNotEmpty) {
                          // ignore: deprecated_member_use
                          Share.share(folder.files.first.fileUrl, subject: folder.title);
                        }
                      },
                    ),
                    if (_canManage)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.white70),
                        color: const Color(0xFF2A2D35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditFolderTitleDialog(folder);
                          } else if (value == 'delete') {
                            _confirmDeleteFolder(folder);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? "تعديل اسم المجلد" : "Edit Folder Name",
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? "حذف المجلد بالكامل" : "Delete Folder",
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 56,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? "لا توجد مجلدات ملحقات حالياً" : "No material folders yet",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _canManage
                  ? (isArabic
                      ? "اضغط على زر (إضافة مجلد ملحقات) لرفع مجموعة كراسات التمارين أو نماذج الخط لطلابك."
                      : "Tap 'Add Material Folder' to organize practice sheets and calligraphy samples.")
                  : (isArabic
                      ? "سيقوم المعلم بإضافة مجلدات المراجع والتمارين هنا قريباً."
                      : "Your teacher will post practice sheets and reference folders here soon."),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // DOWNLOAD ENTIRE FOLDER
  // -------------------------------------------------------------
  Future<void> _downloadEntireFolder(CourseMaterialFolder folder) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (folder.files.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        title: isArabic ? "تنبيه" : "Notice",
        message: isArabic ? "لا توجد ملفات في هذا المجلد" : "Folder has no files",
        type: MessengerType.info,
      );
      return;
    }

    if (folder.isPdf) {
      // If single PDF, download directly
      if (folder.files.length == 1) {
        await MaterialDownloadHelper.downloadPdf(
          context: context,
          pdfUrl: folder.files.first.fileUrl,
          title: folder.files.first.title.isNotEmpty ? folder.files.first.title : folder.title,
          fileName: folder.files.first.fileName,
        );
      } else {
        // Open folder page to let user pick which PDF or open them
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseMaterialFolderPage(
              courseId: widget.courseId,
              folder: folder,
              isTeacher: widget.isTeacher,
              isAdmin: widget.isAdmin,
            ),
          ),
        );
      }
    } else {
      // Download all images to Photo Gallery!
      await MaterialDownloadHelper.downloadAllImagesToGallery(
        context: context,
        files: folder.files,
        folderTitle: folder.title,
      );
    }
  }

  // -------------------------------------------------------------
  // BOTTOM SHEET: PICK OPTION
  // -------------------------------------------------------------
  void _showUploadOptionsSheet() {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2026),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isArabic ? "إضافة مجلد ملحقات جديد" : "Add New Material Folder",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? "اختر نوع الملفات التي تريد تجميعها في هذا المجلد:"
                      : "Choose file types to group inside this folder:",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),

                // Option 1: PDF Document(s)
                _buildSheetOptionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: Colors.redAccent,
                  title: isArabic ? "مستندات PDF (ملف أو أكثر)" : "PDF Documents (One or More)",
                  subtitle: isArabic
                      ? "كراسات تمارين ومذكرات تعليمية في مجلد واحد"
                      : "Worksheets and notes grouped into a folder",
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPdfFolder();
                  },
                ),
                const SizedBox(height: 12),

                // Option 2: Gallery Image(s)
                _buildSheetOptionTile(
                  icon: Icons.photo_library_rounded,
                  iconColor: Colors.purpleAccent,
                  title: isArabic ? "صور من المعرض (صورة أو أكثر)" : "Gallery Images (One or More)",
                  subtitle: isArabic
                      ? "مجموعة مخطوطات ونماذج فنية في ألبوم/مجلد"
                      : "Calligraphy plates and samples grouped in a folder",
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImageFolder(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),

                // Option 3: Camera
                _buildSheetOptionTile(
                  icon: Icons.camera_alt_rounded,
                  iconColor: Colors.tealAccent,
                  title: isArabic ? "التقاط صورة بالكاميرا" : "Take Photo with Camera",
                  subtitle: isArabic
                      ? "تصوير نموذج مكتوب أو لوحة فوراً في مجلد"
                      : "Snap a quick photo of handwritten calligraphy",
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImageFolder(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }

  // -------------------------------------------------------------
  // PICK & CREATE PDF FOLDER
  // -------------------------------------------------------------
  Future<void> _pickAndUploadPdfFolder() async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final List<_LocalPickItem> items = [];
      int totalBytes = 0;
      for (final f in result.files) {
        if (f.path == null) continue;
        final file = File(f.path!);
        final String originalName = f.name;
        final int bytes = f.size;
        totalBytes += bytes;
        final String sizeStr = _formatBytes(bytes);
        final defaultTitle = originalName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

        items.add(_LocalPickItem(
          file: file,
          fileName: originalName,
          fileSize: sizeStr,
          bytes: bytes,
          title: defaultTitle,
        ));
      }

      if (items.isEmpty) return;

      final defaultFolderTitle = items.length == 1
          ? items.first.title
          : (isArabic ? "مستندات PDF (${items.length})" : "PDF Documents (${items.length})");

      final confirmedFolderTitle = await _promptForFolderName(
        initialValue: defaultFolderTitle,
        fileCount: items.length,
        totalSizeStr: _formatBytes(totalBytes),
        isPdf: true,
      );

      if (confirmedFolderTitle == null || confirmedFolderTitle.trim().isEmpty) return;

      await _uploadBatchAndSaveAsFolder(
        folderTitle: confirmedFolderTitle.trim(),
        items: items,
        type: 'pdf',
      );
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        title: isArabic ? "خطأ" : "Error",
        message: "$e",
        type: MessengerType.error,
      );
    }
  }

  // -------------------------------------------------------------
  // PICK & CREATE IMAGE FOLDER
  // -------------------------------------------------------------
  Future<void> _pickAndUploadImageFolder(ImageSource source) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    try {
      final List<_LocalPickItem> items = [];
      int totalBytes = 0;

      if (source == ImageSource.camera) {
        final picker = ImagePicker();
        final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 88);
        if (photo == null) return;
        final file = File(photo.path);
        final bytes = await file.length();
        totalBytes += bytes;
        final name = photo.name.isNotEmpty ? photo.name : 'camera_sample.jpg';
        items.add(_LocalPickItem(
          file: file,
          fileName: name,
          fileSize: _formatBytes(bytes),
          bytes: bytes,
          title: isArabic ? "صورة بالكاميرا" : "Camera Photo",
        ));
      } else {
        // Multi Image Picker from Gallery
        final picker = ImagePicker();
        final List<XFile> photos = await picker.pickMultiImage(imageQuality: 88);
        if (photos.isEmpty) return;

        for (int i = 0; i < photos.length; i++) {
          final p = photos[i];
          final file = File(p.path);
          final bytes = await file.length();
          totalBytes += bytes;
          final name = p.name.isNotEmpty ? p.name : 'plate_${i + 1}.jpg';
          items.add(_LocalPickItem(
            file: file,
            fileName: name,
            fileSize: _formatBytes(bytes),
            bytes: bytes,
            title: isArabic ? "مخطوطة نموذجية (${i + 1})" : "Sample Plate (${i + 1})",
          ));
        }
      }

      if (items.isEmpty) return;

      final defaultFolderTitle = isArabic
          ? (items.length == 1 ? "مخطوطة نموذجية" : "مجموعة مخطوطات (${items.length})")
          : (items.length == 1 ? "Sample Plate" : "Calligraphy Set (${items.length})");

      final confirmedFolderTitle = await _promptForFolderName(
        initialValue: defaultFolderTitle,
        fileCount: items.length,
        totalSizeStr: _formatBytes(totalBytes),
        isPdf: false,
      );

      if (confirmedFolderTitle == null || confirmedFolderTitle.trim().isEmpty) return;

      await _uploadBatchAndSaveAsFolder(
        folderTitle: confirmedFolderTitle.trim(),
        items: items,
        type: 'image',
      );
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        title: isArabic ? "خطأ" : "Error",
        message: "$e",
        type: MessengerType.error,
      );
    }
  }

  // -------------------------------------------------------------
  // PROMPT DIALOG: FOLDER NAME
  // -------------------------------------------------------------
  Future<String?> _promptForFolderName({
    required String initialValue,
    required int fileCount,
    required String totalSizeStr,
    required bool isPdf,
  }) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF22242B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isPdf ? Icons.folder_zip_rounded : Icons.create_new_folder_rounded,
                color: isPdf ? Colors.redAccent : AppColors.accentGold,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabic ? "إنشاء مجلد ملحقات" : "Create Material Folder",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic
                    ? "أدخل اسماً لهذا المجلد ليتمكن الطلاب من تصفحه وتحميل ملفاته بسهولة:"
                    : "Enter a name for this folder so students can browse and download its contents:",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.photo_library_rounded,
                      size: 16,
                      color: isPdf ? Colors.redAccent : Colors.purpleAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isArabic
                          ? "يحتوي على: $fileCount ملفات ($totalSizeStr)"
                          : "Contains: $fileCount files ($totalSizeStr)",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: isArabic ? "اسم المجلد / عنوان المحتوى" : "Folder / Collection Name",
                  labelStyle: const TextStyle(color: AppColors.accentGold, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(
                isArabic ? "إلغاء" : "Cancel",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx, text);
                }
              },
              child: Text(
                isArabic ? "بدء الرفع وإنشاء المجلد" : "Create & Upload",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // CORE BATCH UPLOAD: CREATES 1 FOLDER IN FIRESTORE WITH ALL FILES
  // -------------------------------------------------------------
  Future<void> _uploadBatchAndSaveAsFolder({
    required String folderTitle,
    required List<_LocalPickItem> items,
    required String type,
  }) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusText = isArabic ? "جاري تهيئة الرفع..." : "Preparing upload...";
    });

    final List<Map<String, dynamic>> uploadedFiles = [];
    int totalBytes = 0;

    try {
      final user = FirebaseAuth.instance.currentUser;

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String storagePath = 'course_materials/${widget.courseId}/${timestamp}_${item.fileName}';

        setState(() {
          _uploadProgress = i / items.length;
          _uploadStatusText = isArabic
              ? "جاري رفع (${i + 1} من ${items.length}):\n${item.fileName}"
              : "Uploading (${i + 1} of ${items.length}):\n${item.fileName}";
        });

        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final uploadTask = ref.putFile(item.file);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        totalBytes += item.bytes;
        uploadedFiles.add({
          'title': item.title,
          'fileName': item.fileName,
          'fileUrl': downloadUrl,
          'fileSize': item.fileSize,
          'storagePath': storagePath,
          'type': type,
        });
      }

      setState(() {
        _uploadStatusText = isArabic ? "جاري حفظ المجلد..." : "Saving folder...";
      });

      // Write SINGLE Folder document to Firestore
      final String? previewUrl = type == 'image' && uploadedFiles.isNotEmpty
          ? uploadedFiles.first['fileUrl']
          : null;

      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .add({
        'title': folderTitle,
        'type': type,
        'itemCount': uploadedFiles.length,
        'totalSize': _formatBytes(totalBytes),
        'previewUrl': previewUrl,
        'files': uploadedFiles,
        'uploadedBy': user?.uid ?? '',
        'uploadedByName': user?.displayName ?? 'Instructor',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        title: isArabic ? "تم إنشاء المجلد بنجاح" : "Folder Created",
        message: isArabic
            ? "تم رفع وحفظ مجلد ($folderTitle) ومحتوياته بنجاح"
            : "Successfully created folder '$folderTitle' with ${uploadedFiles.length} files",
        type: MessengerType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        title: isArabic ? "خطأ في الرفع" : "Upload Error",
        message: "$e",
        type: MessengerType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadStatusText = '';
        });
      }
    }
  }

  // -------------------------------------------------------------
  // EDIT FOLDER TITLE
  // -------------------------------------------------------------
  void _showEditFolderTitleDialog(CourseMaterialFolder folder) {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final controller = TextEditingController(text: folder.title);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22242B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArabic ? "تعديل اسم المجلد" : "Edit Folder Name",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: isArabic ? "اسم المجلد الجديد" : "New Folder Name",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? "إلغاء" : "Cancel", style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('materials')
                    .doc(folder.id)
                    .update({'title': newTitle});
              }
            },
            child: Text(isArabic ? "حفظ" : "Save"),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // DELETE ENTIRE FOLDER
  // -------------------------------------------------------------
  void _confirmDeleteFolder(CourseMaterialFolder folder) {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22242B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArabic ? "حذف المجلد بالكامل؟" : "Delete Folder?",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic
              ? "سيتم حذف مجلد (${folder.title}) وجميع الملفات (${folder.itemCount}) الموجودة بداخله نهائياً."
              : "This will permanently delete '${folder.title}' and all ${folder.itemCount} files inside it.",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? "إلغاء" : "Cancel", style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);

              // 1. Delete Firestore doc
              await FirebaseFirestore.instance
                  .collection('courses')
                  .doc(widget.courseId)
                  .collection('materials')
                  .doc(folder.id)
                  .delete();

              // 2. Delete all files from Storage
              for (final f in folder.files) {
                if (f.storagePath.isNotEmpty) {
                  try {
                    await FirebaseStorage.instance.ref().child(f.storagePath).delete();
                  } catch (_) {}
                }
              }

              if (!mounted) return;
              AppMessenger.showSnackBar(
                context,
                title: isArabic ? "تم الحذف" : "Deleted",
                message: isArabic ? "تم حذف المجلد بنجاح" : "Folder deleted successfully",
                type: MessengerType.info,
              );
            },
            child: Text(
              isArabic ? "حذف نهائي" : "Delete",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
}

class _LocalPickItem {
  final File file;
  final String fileName;
  final String fileSize;
  final int bytes;
  String title;

  _LocalPickItem({
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.bytes,
    required this.title,
  });
}

// ============================================================================
// FOLDER DETAILS PAGE: VIEW & DOWNLOAD CONTENTS
// ============================================================================

class CourseMaterialFolderPage extends StatefulWidget {
  final String courseId;
  final CourseMaterialFolder folder;
  final bool isTeacher;
  final bool isAdmin;

  const CourseMaterialFolderPage({
    super.key,
    required this.courseId,
    required this.folder,
    this.isTeacher = false,
    this.isAdmin = false,
  });

  @override
  State<CourseMaterialFolderPage> createState() => _CourseMaterialFolderPageState();
}

class _CourseMaterialFolderPageState extends State<CourseMaterialFolderPage> {
  late CourseMaterialFolder _currentFolder;

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
  }

  bool get _canManage => widget.isTeacher || widget.isAdmin;

  Future<void> _deleteFileFromFolder(CourseMaterialFileItem file) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22242B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArabic ? "حذف الملف؟" : "Delete File?",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          isArabic
              ? "هل تريد بالتأكيد حذف (${file.title.isNotEmpty ? file.title : file.fileName}) من هذا المجلد؟"
              : "Are you sure you want to remove '${file.title.isNotEmpty ? file.title : file.fileName}' from this folder?",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? "إلغاء" : "Cancel", style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isArabic ? "حذف" : "Delete"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final updatedFiles = _currentFolder.files
          .where((f) => f.fileUrl != file.fileUrl)
          .map((f) => f.toMap())
          .toList();

      if (updatedFiles.isEmpty) {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .doc(_currentFolder.id)
            .delete();
        if (mounted) Navigator.pop(context);
      } else {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .doc(_currentFolder.id)
            .update({
          'files': updatedFiles,
          'itemCount': updatedFiles.length,
        });
      }

      if (file.storagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref().child(file.storagePath).delete();
        } catch (_) {}
      }

      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? "تم الحذف" : "Deleted",
          message: isArabic ? "تم حذف الملف بنجاح" : "File deleted successfully",
          type: MessengerType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? "خطأ" : "Error",
          message: "$e",
          type: MessengerType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(widget.folder.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          _currentFolder = CourseMaterialFolder.fromDoc(snapshot.data!);
        }

        final folder = _currentFolder;
        final bool isPdf = folder.isPdf;

        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            title: Text(
              folder.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white70),
                tooltip: isArabic ? "مشاركة" : "Share",
                onPressed: () {
                  if (folder.files.isNotEmpty) {
                    // ignore: deprecated_member_use
                    Share.share(folder.files.first.fileUrl, subject: folder.title);
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Header Summary Card & Download All Button
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2026),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isPdf
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : AppColors.accentGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.photo_library_rounded,
                            color: isPdf ? Colors.redAccent : AppColors.accentGold,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isArabic
                                    ? "${folder.itemCount} ملفات • الحجم الإجمالي: ${folder.totalSize}"
                                    : "${folder.itemCount} files • Total size: ${folder.totalSize}",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Big Download All Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          isPdf
                              ? (isArabic ? "تحميل ومشاركة المستند" : "Download / Save PDF")
                              : (isArabic ? "تحميل جميع الصور إلى الألبوم 📸" : "Download All to Photos 📸"),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () {
                          if (isPdf) {
                            if (folder.files.isNotEmpty) {
                              MaterialDownloadHelper.downloadPdf(
                                context: context,
                                pdfUrl: folder.files.first.fileUrl,
                                title: folder.files.first.title.isNotEmpty ? folder.files.first.title : folder.title,
                                fileName: folder.files.first.fileName,
                              );
                            }
                          } else {
                            MaterialDownloadHelper.downloadAllImagesToGallery(
                              context: context,
                              files: folder.files,
                              folderTitle: folder.title,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Files Grid / List
              Expanded(
                child: folder.files.isEmpty
                    ? Center(
                        child: Text(
                          isArabic ? "لا توجد ملفات في هذا المجلد" : "No files in this folder",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      )
                    : isPdf
                        ? _buildPdfListView(folder, isArabic)
                        : _buildImagesGridView(folder, isArabic),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // IMAGES GRID VIEW
  // -------------------------------------------------------------
  Widget _buildImagesGridView(CourseMaterialFolder folder, bool isArabic) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: folder.files.length,
      itemBuilder: (context, index) {
        final file = folder.files[index];

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2026),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Thumbnail with tap to view
              Expanded(
                child: GestureDetector(
                  onTap: () => _openImageViewer(file.fileUrl, file.title),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: file.fileUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${index + 1}/${folder.files.length}",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Info Bar with Download Icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: const Color(0xFF16181E),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.title.isNotEmpty ? file.title : "صورة ${index + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (file.fileSize.isNotEmpty)
                            Text(
                              file.fileSize,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    // Single Image Download Button
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.accentGold),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: isArabic ? "تحميل للألبوم" : "Save to Photos",
                      onPressed: () {
                        MaterialDownloadHelper.downloadSingleImageToGallery(
                          context: context,
                          imageUrl: file.fileUrl,
                          name: file.title.isNotEmpty ? file.title : file.fileName,
                        );
                      },
                    ),
                    if (_canManage) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: isArabic ? "حذف الصورة" : "Delete Image",
                        onPressed: () => _deleteFileFromFolder(file),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // PDF LIST VIEW
  // -------------------------------------------------------------
  Widget _buildPdfListView(CourseMaterialFolder folder, bool isArabic) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: folder.files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final file = folder.files[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2026),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.title.isNotEmpty ? file.title : file.fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (file.fileSize.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        file.fileSize,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser_rounded, size: 20, color: Colors.white70),
                tooltip: isArabic ? "عرض الملف" : "Open PDF",
                onPressed: () => _openPdfUrl(file.fileUrl),
              ),
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.accentGold),
                tooltip: isArabic ? "تنزيل وحفظ" : "Download PDF",
                onPressed: () {
                  MaterialDownloadHelper.downloadPdf(
                    context: context,
                    pdfUrl: file.fileUrl,
                    title: file.title.isNotEmpty ? file.title : folder.title,
                    fileName: file.fileName,
                  );
                },
              ),
              if (_canManage)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                  tooltip: isArabic ? "حذف الملف" : "Delete File",
                  onPressed: () => _deleteFileFromFolder(file),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openImageViewer(String imageUrl, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded, color: AppColors.accentGold),
                tooltip: "حفظ في ألبوم الصور",
                onPressed: () {
                  MaterialDownloadHelper.downloadSingleImageToGallery(
                    context: context,
                    imageUrl: imageUrl,
                    name: title,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                // ignore: deprecated_member_use
                onPressed: () => Share.share(imageUrl),
              ),
            ],
          ),
          body: Center(
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPdfUrl(String url) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch $url";
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        title: isArabic ? "تعذر فتح الملف" : "Cannot open file",
        message: "$e",
        type: MessengerType.error,
      );
    }
  }
}

// ============================================================================
// DOWNLOAD HELPER: SAVES IMAGES TO GALLERY & SAVES PDF TO DEVICE
// ============================================================================

class MaterialDownloadHelper {
  /// Save a single image to the device's photo gallery
  static Future<void> downloadSingleImageToGallery({
    required BuildContext context,
    required String imageUrl,
    required String name,
  }) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        if (context.mounted) {
          AppMessenger.showSnackBar(
            context,
            title: isArabic ? 'تنبيه الصلاحيات' : 'Permission Required',
            message: isArabic
                ? 'يرجى السماح بالوصول إلى ألبوم الصور لحفظ الصورة في هاتفك'
                : 'Please allow photos access to save the image to your gallery',
            type: MessengerType.error,
          );
        }
        return;
      }

      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? 'جاري التحميل...' : 'Downloading...',
          message: isArabic ? 'جاري حفظ الصورة في ألبوم الصور...' : 'Saving image to photos...',
          type: MessengerType.info,
        );
      }

      final file = await DefaultCacheManager().getSingleFile(imageUrl);
      final bytes = await file.readAsBytes();

      final cleanName = name.trim().isNotEmpty
          ? (name.endsWith('.jpg') || name.endsWith('.png') ? name : '$name.jpg')
          : 'calligro_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await PhotoManager.editor.saveImage(
        bytes,
        title: cleanName,
        filename: cleanName,
      );

      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? 'تم الحفظ بنجاح' : 'Saved Successfully',
          message: isArabic
              ? 'تم حفظ الصورة في ألبوم الصور بنجاح 📸'
              : 'Image successfully saved to your photos album 📸',
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? 'خطأ في الحفظ' : 'Download Error',
          message: '$e',
          type: MessengerType.error,
        );
      }
    }
  }

  /// Save multiple images from a folder to the device's photo gallery at once
  static Future<void> downloadAllImagesToGallery({
    required BuildContext context,
    required List<CourseMaterialFileItem> files,
    required String folderTitle,
  }) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (files.isEmpty) return;

    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        if (context.mounted) {
          AppMessenger.showSnackBar(
            context,
            title: isArabic ? 'تنبيه الصلاحيات' : 'Permission Required',
            message: isArabic
                ? 'يرجى السماح بالوصول إلى ألبوم الصور لحفظ الصور'
                : 'Please allow photos access to save images',
            type: MessengerType.error,
          );
        }
        return;
      }

      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? 'جاري تحميل المجلد...' : 'Downloading Folder...',
          message: isArabic
              ? 'جاري تحميل ${files.length} صور وحفظها في ألبوم الصور...'
              : 'Saving ${files.length} images to your photos album...',
          type: MessengerType.info,
        );
      }

      int savedCount = 0;
      for (int i = 0; i < files.length; i++) {
        final f = files[i];
        try {
          final cachedFile = await DefaultCacheManager().getSingleFile(f.fileUrl);
          final bytes = await cachedFile.readAsBytes();
          final fileName = '${folderTitle}_${i + 1}.jpg';

          await PhotoManager.editor.saveImage(
            bytes,
            title: fileName,
            filename: fileName,
          );
          savedCount++;
        } catch (err) {
          debugPrint('Error saving file $i: $err');
        }
      }

      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? 'اكتمل التحميل' : 'Download Complete',
          message: isArabic
              ? 'تم حفظ $savedCount من أصل ${files.length} صور في ألبوم الصور بنجاح 📸'
              : 'Successfully saved $savedCount of ${files.length} images to your gallery 📸',
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? 'خطأ' : 'Error',
          message: '$e',
          type: MessengerType.error,
        );
      }
    }
  }

  /// Download and save a PDF to device via system share/save-to-files sheet
  static Future<void> downloadPdf({
    required BuildContext context,
    required String pdfUrl,
    required String title,
    required String fileName,
  }) async {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';

    try {
      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? 'جاري التحميل...' : 'Downloading...',
          message: isArabic
              ? 'جاري تجهيز مستند الـ PDF للحفظ على الهاتف...'
              : 'Preparing PDF file for saving...',
          type: MessengerType.info,
        );
      }

      final cachedFile = await DefaultCacheManager().getSingleFile(pdfUrl);
      final bytes = await cachedFile.readAsBytes();

      final cleanName = title.trim().isNotEmpty ? title.trim() : 'document';
      final nameWithExt = cleanName.toLowerCase().endsWith('.pdf') ? cleanName : '$cleanName.pdf';

      // Opens native system sheet (iOS "Save to Files" / Android "Save to Downloads")
      await Printing.sharePdf(
        bytes: bytes,
        filename: nameWithExt,
      );
    } catch (e) {
      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: isArabic ? 'خطأ في التنزيل' : 'Download Error',
          message: '$e',
          type: MessengerType.error,
        );
      }
    }
  }
}
