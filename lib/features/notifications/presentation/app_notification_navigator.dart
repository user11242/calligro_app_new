import 'package:flutter/material.dart';

import 'package:calligro_app/features/admin/presentation/pages/admin_pending_teachers.dart';
import 'package:calligro_app/features/community/presentation/pages/single_post_page.dart';
import 'package:calligro_app/features/classroom/presentation/chat/course_chat_page.dart';
import 'package:calligro_app/features/courses/domain/course_policy.dart';
import 'package:calligro_app/features/courses/presentation/course_scope.dart';
import 'package:calligro_app/features/courses/presentation/pages/course_preview_page.dart';
import 'package:calligro_app/features/profile/presentation/pages/public_profile_page.dart';
import 'package:calligro_app/features/classroom/presentation/pages/course_details_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../domain/notification_models.dart';
import '../domain/notification_repositories.dart';
import 'notification_services.dart';
import 'notifications_page.dart';

/// Opens the screen a notification points to, from a dashboard's context.
class AppNotificationNavigator implements NotificationNavigator {
  AppNotificationNavigator(this._context);
  final BuildContext _context;

  @override
  void open(NotificationTarget target) {
    if (!_context.mounted) return;
    final nav = Navigator.of(_context);
    switch (target) {
      case PostTarget(:final postId):
        nav.push(MaterialPageRoute(builder: (_) => SinglePostPage(postId: postId)));
      case CourseChatTarget(:final courseId, :final courseName, :final teacherId):
        final uid = NotificationScope.of(_context).currentUid();
        nav.push(MaterialPageRoute(
          builder: (c) => CourseChatPage(
            courseId: courseId,
            courseName: courseName.isNotEmpty ? courseName : AppLocalizations.of(c)!.courseGroupChat,
            courseTeacherId: teacherId.isNotEmpty ? teacherId : null,
            isTeacher: uid.isNotEmpty && uid == teacherId,
          ),
        ));
      case CourseTarget(:final courseId):
        _openCourse(nav, courseId);
      case ProfileTarget(:final userId):
        nav.push(MaterialPageRoute(builder: (_) => PublicProfilePage(userId: userId)));
      case PendingTeachersTarget():
        nav.push(MaterialPageRoute(builder: (_) => AdminPendingTeachersPage()));
      case InboxTarget():
        nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    }
  }

  /// The course page for its teacher / students; the preview for anyone else.
  Future<void> _openCourse(NavigatorState nav, String courseId) async {
    final services = CourseScope.of(_context);
    final course = await services.courses.watchCourse(courseId).first;
    if (course == null || !nav.mounted) return;
    final uid = services.currentUid();
    final member = CoursePolicy.isOwner(course, uid) || CoursePolicy.isEnrolled(course, uid);
    nav.push(MaterialPageRoute(
      builder: (_) => member
          ? CourseDetailsPage(courseId: course.id, courseData: course.raw)
          : CoursePreviewPage(courseId: course.id, courseData: course.raw),
    ));
  }
}

/// Put around a dashboard: while it is on screen, notification taps open
/// from it (including a tap that launched the app, kept until now).
class NotificationTapHandler extends StatefulWidget {
  const NotificationTapHandler({super.key, required this.child});
  final Widget child;

  @override
  State<NotificationTapHandler> createState() => _NotificationTapHandlerState();
}

class _NotificationTapHandlerState extends State<NotificationTapHandler> {
  AppNotificationNavigator? _navigator;
  NotificationServices? _services;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_navigator != null) return;
    _services = NotificationScope.of(context);
    _navigator = AppNotificationNavigator(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _services!.opener.attach(_navigator!);
    });
  }

  @override
  void dispose() {
    if (_navigator != null) _services?.opener.detach(_navigator!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
