/// A comment on a post, or a reply to a comment (same shape).
class CommunityComment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String authorRole;
  final String text;

  /// Null while the server timestamp is pending.
  final DateTime? createdAt;
  final bool isEdited;

  /// Replies under a comment (always 0 for a reply).
  final int replyCount;

  const CommunityComment({
    required this.id,
    required this.authorId,
    this.authorName = '',
    this.authorPhotoUrl = '',
    this.authorRole = 'student',
    this.text = '',
    this.createdAt,
    this.isEdited = false,
    this.replyCount = 0,
  });
}

/// A user as shown in community lists (likers, search, blocked users, authors).
class CommunityUser {
  final String id;
  final String name;
  final String photoUrl;
  final String role;
  const CommunityUser({required this.id, this.name = '', this.photoUrl = '', this.role = 'student'});

  bool get isTeacher => role == 'teacher';
}

/// The signed-in user (or a guest) as the community sees them.
class CommunitySession {
  final String userId;
  final String name;
  final String photoUrl;
  final String role;

  const CommunitySession({required this.userId, this.name = '', this.photoUrl = '', this.role = 'student'});

  /// Not signed in: may browse, may not interact.
  static const guest = CommunitySession(userId: '');

  bool get isGuest => userId.isEmpty;
  bool get isAdmin => role == 'admin';
}

/// Feed tabs. [label] is the legacy string id (kept for saved preferences / deep links).
enum CommunityFilter {
  all('All'),
  popular('Popular'),
  friends('Friends'),
  teachers('Teachers'),
  myPosts('My Posts'),
  saved('Saved');

  final String label;
  const CommunityFilter(this.label);

  static CommunityFilter fromLabel(String? label) =>
      CommunityFilter.values.firstWhere((f) => f.label == label, orElse: () => CommunityFilter.all);
}

/// What the author submits when creating a post.
class NewPost {
  final String caption;

  /// Local paths of already-compressed images.
  final List<String> imagePaths;
  final String? linkUrl;
  final String? linkTitle;
  final bool isPinned;
  final bool isHidden;

  const NewPost({
    this.caption = '',
    this.imagePaths = const [],
    this.linkUrl,
    this.linkTitle,
    this.isPinned = false,
    this.isHidden = false,
  });
}
