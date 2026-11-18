/// Notifications (pure Dart): where a tap leads, and what an inbox item is.
///
/// The route contract shared with functions/notifications.js (keep in sync):
///   /postDetails   {postId, commentId?}        comments, likes, replies
///   /courseChat    {courseId, courseName, teacherId}
///   /courseDetails {courseId}                  announcements, assignments,
///                                              reschedules, enrolments, submissions
///   /profile       {userId}                    new follower
///   /adminPendingTeachers                      new teacher to approve
///   (none)         → the inbox                 approvals, broadcasts, admin messages
library;

sealed class NotificationTarget {
  const NotificationTarget();

  /// Reads the push `data` / the inbox item's `data`. Unknown or incomplete
  /// routes fall back to the inbox (a tap must always open SOMETHING).
  factory NotificationTarget.fromData(Map<String, dynamic> data) {
    String s(String k) => data[k] == null ? '' : '${data[k]}'.trim();
    final route = s('route');
    final type = s('type');
    switch (route) {
      case '/postDetails':
        if (s('postId').isNotEmpty) return PostTarget(s('postId'), commentId: s('commentId').isEmpty ? null : s('commentId'));
      case '/courseChat':
        if (s('courseId').isNotEmpty) {
          return CourseChatTarget(s('courseId'), courseName: s('courseName'), teacherId: s('teacherId'));
        }
      case '/courseDetails':
        if (s('courseId').isNotEmpty) return CourseTarget(s('courseId'));
      case '/profile':
        if (s('userId').isNotEmpty) return ProfileTarget(s('userId'));
      case '/adminPendingTeachers' || '/admin/teachers':
        return const PendingTeachersTarget();
    }
    // Older pushes / inbox items carried only a type and ids.
    if ((type == 'comment' || type == 'like' || type == 'reply') && s('postId').isNotEmpty) return PostTarget(s('postId'));
    if (type == 'new_follower' && s('userId').isNotEmpty) return ProfileTarget(s('userId'));
    if (s('courseId').isNotEmpty && const {'announcement', 'assignment', 'reschedule', 'enrollment'}.contains(type)) {
      return CourseTarget(s('courseId'));
    }
    return const InboxTarget();
  }
}

class PostTarget extends NotificationTarget {
  final String postId;
  final String? commentId;
  const PostTarget(this.postId, {this.commentId});
  @override
  bool operator ==(Object o) => o is PostTarget && o.postId == postId && o.commentId == commentId;
  @override
  int get hashCode => Object.hash(postId, commentId);
}

class CourseChatTarget extends NotificationTarget {
  final String courseId;
  final String courseName;
  final String teacherId;
  const CourseChatTarget(this.courseId, {this.courseName = '', this.teacherId = ''});
  @override
  bool operator ==(Object o) => o is CourseChatTarget && o.courseId == courseId && o.teacherId == teacherId;
  @override
  int get hashCode => Object.hash(courseId, teacherId);
}

class CourseTarget extends NotificationTarget {
  final String courseId;
  const CourseTarget(this.courseId);
  @override
  bool operator ==(Object o) => o is CourseTarget && o.courseId == courseId;
  @override
  int get hashCode => courseId.hashCode;
}

class ProfileTarget extends NotificationTarget {
  final String userId;
  const ProfileTarget(this.userId);
  @override
  bool operator ==(Object o) => o is ProfileTarget && o.userId == userId;
  @override
  int get hashCode => userId.hashCode;
}

class PendingTeachersTarget extends NotificationTarget {
  const PendingTeachersTarget();
  @override
  bool operator ==(Object o) => o is PendingTeachersTarget;
  @override
  int get hashCode => 1;
}

class InboxTarget extends NotificationTarget {
  const InboxTarget();
  @override
  bool operator ==(Object o) => o is InboxTarget;
  @override
  int get hashCode => 0;
}

/// An item of users/{uid}/notifications.
/// A moved class (or a move undone), with the exact moments, so the app can
/// show them in the phone's own time zone (the push text is written by the server).
class ClassChange {
  final bool isBack;
  final String courseName;
  final DateTime oldStart;
  final DateTime? newStart;
  final DateTime? newEnd;
  final String note;

  const ClassChange({
    required this.isBack,
    required this.courseName,
    required this.oldStart,
    this.newStart,
    this.newEnd,
    this.note = '',
  });

  /// From the notification's data (all values arrive as strings).
  static ClassChange? fromData(Map<String, dynamic> data) {
    final kind = '${data['classChange'] ?? ''}';
    if (kind != 'moved' && kind != 'back') return null;
    DateTime? at(String k) {
      final v = int.tryParse('${data[k] ?? ''}');
      return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    }

    final old = at('oldStart');
    if (old == null) return null;
    final newStart = at('newStart'), newEnd = at('newEnd');
    if (kind == 'moved' && (newStart == null || newEnd == null)) return null;
    return ClassChange(
      isBack: kind == 'back',
      courseName: '${data['courseName'] ?? ''}',
      oldStart: old,
      newStart: newStart,
      newEnd: newEnd,
      note: '${data['note'] ?? ''}',
    );
  }
}

class InboxItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime? createdAt;
  final NotificationTarget target;

  /// Set for moved-class notifications (newer ones carry the exact times).
  final ClassChange? classChange;

  const InboxItem({
    required this.id,
    this.title = '',
    this.body = '',
    this.type = '',
    this.read = false,
    this.createdAt,
    this.target = const InboxTarget(),
    this.classChange,
  });

  /// Reads the server's shape ({title, body, read, data}) and the older
  /// app-written one ({title, message, isRead, courseId}).
  factory InboxItem.fromMap(String id, Map<String, dynamic> d) {
    DateTime? at;
    try {
      final dynamic t = d['createdAt'];
      if (t is DateTime) {
        at = t;
      } else if (t != null) {
        at = t.toDate() as DateTime;
      }
    } catch (_) {}
    String s(String k) => d[k] is String ? d[k] as String : '';
    final data = <String, dynamic>{
      if (d['data'] is Map) ...Map<String, dynamic>.from(d['data'] as Map),
      'type': s('type'),
      if (d['courseId'] is String && !(d['data'] is Map && (d['data'] as Map).containsKey('courseId'))) 'courseId': d['courseId'],
    };
    return InboxItem(
      id: id,
      title: s('title'),
      body: s('body').isNotEmpty ? s('body') : s('message'),
      type: s('type'),
      read: d['read'] == true || d['isRead'] == true,
      createdAt: at,
      target: NotificationTarget.fromData(data),
      classChange: ClassChange.fromData(data),
    );
  }
}
