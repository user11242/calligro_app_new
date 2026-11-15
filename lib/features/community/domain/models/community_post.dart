/// A community post. Pure data: no Firestore types (mapping lives in data/).
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;

  /// 'student' | 'teacher' | 'admin'
  final String authorRole;
  final String caption;
  final List<String> imageUrls;

  /// Null while the server timestamp of a just-created post is pending.
  final DateTime? createdAt;
  final int likesCount;

  /// Everyone who liked the post (the `likes` map keys).
  final Set<String> likerIds;
  final int commentsCount;
  final bool isEdited;
  final bool isPinned;
  final bool isHidden;
  final String? linkUrl;
  final String? linkTitle;

  const CommunityPost({
    required this.id,
    required this.authorId,
    this.authorName = '',
    this.authorPhotoUrl = '',
    this.authorRole = 'student',
    this.caption = '',
    this.imageUrls = const [],
    this.createdAt,
    this.likesCount = 0,
    this.likerIds = const {},
    this.commentsCount = 0,
    this.isEdited = false,
    this.isPinned = false,
    this.isHidden = false,
    this.linkUrl,
    this.linkTitle,
  });

  bool isLikedBy(String userId) => userId.isNotEmpty && likerIds.contains(userId);
  bool get hasLink => linkUrl != null && linkUrl!.trim().isNotEmpty;

  /// The author's CURRENT profile (posts store a copy taken when they were written).
  CommunityPost withAuthor({required String name, required String photoUrl, required String role}) => CommunityPost(
        id: id,
        authorId: authorId,
        authorName: name.isNotEmpty ? name : authorName,
        authorPhotoUrl: photoUrl.isNotEmpty ? photoUrl : authorPhotoUrl,
        authorRole: role.isNotEmpty ? role : authorRole,
        caption: caption,
        imageUrls: imageUrls,
        createdAt: createdAt,
        likesCount: likesCount,
        likerIds: likerIds,
        commentsCount: commentsCount,
        isEdited: isEdited,
        isPinned: isPinned,
        isHidden: isHidden,
        linkUrl: linkUrl,
        linkTitle: linkTitle,
      );

  CommunityPost copyWith({
    String? caption,
    List<String>? imageUrls,
    int? likesCount,
    Set<String>? likerIds,
    int? commentsCount,
    bool? isEdited,
    bool? isPinned,
    bool? isHidden,
  }) =>
      CommunityPost(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        authorRole: authorRole,
        caption: caption ?? this.caption,
        imageUrls: imageUrls ?? this.imageUrls,
        createdAt: createdAt,
        likesCount: likesCount ?? this.likesCount,
        likerIds: likerIds ?? this.likerIds,
        commentsCount: commentsCount ?? this.commentsCount,
        isEdited: isEdited ?? this.isEdited,
        isPinned: isPinned ?? this.isPinned,
        isHidden: isHidden ?? this.isHidden,
        linkUrl: linkUrl,
        linkTitle: linkTitle,
      );
}
