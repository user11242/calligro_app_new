import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import 'package:calligro_app/core/widgets/auto_translated_text.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/features/courses/presentation/pages/course_preview_page.dart';
import 'package:calligro_app/features/teacher/pages/course_details/course_details_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/profile_controllers.dart';
import '../../domain/profile_models.dart';
import '../profile_scope.dart';

/// Owns a [LiveListController] for the life of a tab.
class _LiveList<T> extends StatefulWidget {
  const _LiveList({required this.source, required this.builder});
  final Stream<List<T>> Function(ProfileServices services) source;
  final Widget Function(BuildContext context, LiveListController<T> c) builder;

  @override
  State<_LiveList<T>> createState() => _LiveListState<T>();
}

class _LiveListState<T> extends State<_LiveList<T>> {
  LiveListController<T>? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= LiveListController<T>(widget.source(ProfileScope.of(context)))..start();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: _c!, builder: (context, _) => widget.builder(context, _c!));
}

class _Empty extends StatelessWidget {
  const _Empty({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white38)),
          ],
        ),
      );
}

const _spinner = Center(child: CircularProgressIndicator(color: AppColors.accentGold));

/// A teacher's courses. Tapping opens the course (own / enrolled) or its preview.
class TeacherCoursesTab extends StatelessWidget {
  const TeacherCoursesTab({super.key, required this.teacherId, required this.viewer});
  final String teacherId;
  final ProfileViewer viewer;

  void _open(BuildContext context, TeacherCourse course) {
    final full = viewer.userId == teacherId || course.isEnrolled(viewer.userId);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => full
            ? CourseDetailsPage(courseId: course.id, courseData: course.raw)
            : CoursePreviewPage(courseId: course.id, courseData: course.raw),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LiveList<TeacherCourse>(
      source: (s) => s.courses.watchCourses(teacherId),
      builder: (context, c) {
        if (c.isLoading) return _spinner;
        if (c.hasError) return _Empty(icon: Icons.error_outline, message: l10n.somethingWentWrong);
        if (c.items.isEmpty) {
          return _Empty(key: const Key('no-courses'), icon: Icons.menu_book_outlined, message: l10n.noCoursesCreated);
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: c.items.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _CourseCard(course: c.items[i], viewer: viewer, onTap: () => _open(context, c.items[i])),
          ),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.viewer, required this.onTap});
  final TeacherCourse course;
  final ProfileViewer viewer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final banner = course.bannerUrl;
    final placeholder = Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.image, color: Colors.white24));
    return GestureDetector(
      key: Key('course-${course.id}'),
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: banner.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: banner,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: Colors.white.withOpacity(0.05)),
                        errorWidget: (_, _, _) => placeholder,
                      )
                    : banner.startsWith('assets')
                        ? Image.asset(banner, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder)
                        : placeholder,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.9)],
                    ),
                  ),
                ),
              ),
              if (course.isEnrolled(viewer.userId))
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    key: const Key('enrolled-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                    child: Text(l10n.enrolled.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.accentGold, borderRadius: BorderRadius.circular(8)),
                  child: Text(CourseUtils.getLocalizedLevel(context, course.level).toUpperCase(),
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoTranslatedText(
                      CourseUtils.getLocalizedCourseName(context, course.raw),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.people_outline, color: AppColors.accentGold, size: 14),
                        const SizedBox(width: 6),
                        Text(l10n.enrolledStudentsCount(course.studentCount),
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
}

/// Reviews of a teacher, newest first.
class TeacherReviewsTab extends StatelessWidget {
  const TeacherReviewsTab({super.key, required this.teacherId});
  final String teacherId;

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LiveList<TeacherReview>(
      source: (s) => s.reviews.watchReviews(teacherId),
      builder: (context, c) {
        if (c.isLoading) return _spinner;
        if (c.hasError) return _Empty(icon: Icons.error_outline, message: l10n.somethingWentWrong);
        if (c.items.isEmpty) return _Empty(key: const Key('no-reviews'), icon: Icons.star_border, message: l10n.noReviewsYet);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: c.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final r = c.items[i];
            final name = r.studentName.isEmpty ? 'Student' : r.studentName;
            return Container(
              key: Key('review-${r.id}'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileAvatar(radius: 22, imageUrl: r.studentPhotoUrl),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                            if (r.courseName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(r.courseName,
                                    style: TextStyle(color: AppColors.accentGold.withOpacity(0.8), fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var s = 0; s < 5; s++)
                            Icon(s < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: AppColors.accentGold, size: 18),
                        ],
                      ),
                    ],
                  ),
                  if (r.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(r.text, style: TextStyle(color: AppColors.textLight.withOpacity(0.9), height: 1.5, fontSize: 14)),
                  ],
                  if (r.createdAt != null) ...[
                    const SizedBox(height: 12),
                    Text(_date(r.createdAt!), style: TextStyle(color: AppColors.textLight.withOpacity(0.4), fontSize: 11)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
