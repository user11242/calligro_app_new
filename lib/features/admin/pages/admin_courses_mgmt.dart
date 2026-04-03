import 'package:flutter/material.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/features/teacher/pages/course_details/course_details_page.dart';

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
}
