import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import '../../teacher/pages/course_details/course_details_page.dart';
import '../../../core/widgets/auto_translated_text.dart';

enum CourseStatusFilter { all, upcoming, active, completed }
enum CourseStatus { upcoming, active, ended }

class StudentMyCoursesPage extends StatefulWidget {
  const StudentMyCoursesPage({super.key});

  @override
  State<StudentMyCoursesPage> createState() => _StudentMyCoursesPageState();
}

class _StudentMyCoursesPageState extends State<StudentMyCoursesPage> {
  CourseStatusFilter _selectedFilter = CourseStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, l10n),
          SliverToBoxAdapter(
            child: _buildFilterBar(context, l10n),
          ),
          if (currentUser == null)
            SliverFillRemaining(
              child: _buildLoginWarning(context, l10n),
            )
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .where('enrolledStudents', arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accentGold),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(context, l10n),
                  );
                }

                final allCourses = snapshot.data!.docs;
                final now = DateTime.now();

                // Calculate statuses and filter
                final filteredCourses = allCourses.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = _getCourseStatus(data);
                  
                  if (_selectedFilter == CourseStatusFilter.all) return true;
                  if (_selectedFilter == CourseStatusFilter.upcoming) return status == CourseStatus.upcoming;
                  if (_selectedFilter == CourseStatusFilter.active) return status == CourseStatus.active;
                  if (_selectedFilter == CourseStatusFilter.completed) return status == CourseStatus.ended;
                  return true;
                }).toList();

                if (filteredCourses.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildNoResultsState(context, l10n),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = filteredCourses[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final status = _getCourseStatus(data);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildCourseCard(context, doc.id, data, status),
                        );
                      },
                      childCount: filteredCourses.length,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }


  Widget _buildSliverAppBar(BuildContext context, AppLocalizations l10n) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          l10n.myCourses,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontFamily: 'Urbanist',
          ),
        ),
        background: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentGold.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildFilterChip(l10n.allCourses, CourseStatusFilter.all),
          const SizedBox(width: 12),
          _buildFilterChip(l10n.activeCourses, CourseStatusFilter.active),
          const SizedBox(width: 12),
          _buildFilterChip(l10n.upcomingCourses, CourseStatusFilter.upcoming),
          const SizedBox(width: 12),
          _buildFilterChip(l10n.completedCourses, CourseStatusFilter.completed),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, CourseStatusFilter filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.accentGold.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, String courseId, Map<String, dynamic> data, CourseStatus status) {
    final bannerUrl = data['courseBanner'] ?? '';
    final teacherName = data['teacherName'] ?? 'Unknown Teacher';
    final courseTitle = CourseUtils.getLocalizedCourseName(context, data);
    
    final String statusLabel = _getLocalizedStatusLabel(context, status);
    Color statusColor;

    switch (status) {
      case CourseStatus.upcoming:
        statusColor = AppColors.accentGold;
        break;
      case CourseStatus.ended:
        statusColor = Colors.grey;
        break;
      case CourseStatus.active:
      default:
        statusColor = const Color(0xFF4CAF50);
        break;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailsPage(
              courseId: courseId,
              courseData: data,
            ),
          ),
        );
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Row(
              children: [
                // Banner
                SizedBox(
                  width: 110,
                  height: double.infinity,
                  child: Hero(
                    tag: 'my_course_img_$courseId',
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        bannerUrl.startsWith('assets')
                            ? Image.asset(bannerUrl, fit: BoxFit.cover)
                            : CachedNetworkImage(
                                imageUrl: bannerUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white10),
                                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
                              ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.3), width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: statusColor, size: 6),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        AutoTranslatedText(
                          courseTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Urbanist',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentGold.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (data['teacherProfilePic'] != null && 
                                        data['teacherProfilePic'].toString().isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: data['teacherProfilePic'],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Icon(
                                          Icons.person_outline, 
                                          color: Colors.white24, 
                                          size: 14
                                        ),
                                        errorWidget: (context, url, error) => const Icon(
                                          Icons.person_outline, 
                                          color: Colors.white24, 
                                          size: 14
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person_outline, 
                                        color: Colors.white60, 
                                        size: 14
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                teacherName,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            l10n.noActivityHistoryFound, // Reuse or add specific key
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 24),
          Text(
            l10n.noEnrolledCourses,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              l10n.browseCoursesToEnroll,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              elevation: 0,
            ),
            child: Text(
              l10n.viewAll,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginWarning(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 60, color: AppColors.accentGold),
            const SizedBox(height: 20),
            Text(
              l10n.signInToAccess(l10n.myCourses),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  CourseStatus _getCourseStatus(Map<String, dynamic> data) {
    final now = DateTime.now();
    final dynamic startData = data['startDate'];
    final dynamic endData = data['endDate'];

    DateTime? startDate;
    DateTime? endDate;

    if (startData is Timestamp) startDate = startData.toDate();
    if (endData is Timestamp) endDate = endData.toDate();

    if (startDate == null) return CourseStatus.active;

    if (now.isBefore(startDate)) return CourseStatus.upcoming;
    if (endDate != null && now.isAfter(endDate)) return CourseStatus.ended;
    
    return CourseStatus.active;
  }

  String _getLocalizedStatusLabel(BuildContext context, CourseStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case CourseStatus.upcoming:
        return l10n.upcomingCaps;
      case CourseStatus.ended:
        return l10n.completedCaps;
      case CourseStatus.active:
      default:
        return l10n.activeCaps;
    }
  }
}
