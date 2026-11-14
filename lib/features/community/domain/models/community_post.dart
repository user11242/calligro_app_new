/// Immutable domain model for a community artwork / discussion post.
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String authorRole;
  final String caption;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final bool isPinned;
  final bool isHidden;
  final bool isEdited;
  final String? linkUrl;
  final String? linkTitle;

  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl = '',
    this.authorRole = 'student',
    required this.caption,
    this.imageUrls = const [],
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    this.isPinned = false,
    this.isHidden = false,
    this.isEdited = false,
    this.linkUrl,
    this.linkTitle,
  });

  bool get isTeacher => authorRole.toLowerCase() == 'teacher';
  bool get isAdmin => authorRole.toLowerCase() == 'admin';
  bool get hasImages => imageUrls.isNotEmpty;

  CommunityPost copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? authorRole,
    String? caption,
    List<String>? imageUrls,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
    bool? isPinned,
    bool? isHidden,
    bool? isEdited,
    String? linkUrl,
    String? linkTitle,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      authorRole: authorRole ?? this.authorRole,
      caption: caption ?? this.caption,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
      isEdited: isEdited ?? this.isEdited,
      linkUrl: linkUrl ?? this.linkUrl,
      linkTitle: linkTitle ?? this.linkTitle,
    );
  }

  factory CommunityPost.fromMap({
    required String id,
    required Map<String, dynamic> map,
    String? currentUserId,
  }) {
    DateTime parsedDate;
    final rawTimestamp = map['timestamp'] ?? map['createdAt'];
    if (rawTimestamp is DateTime) {
      parsedDate = rawTimestamp;
    } else if (rawTimestamp != null && rawTimestamp.toString().contains('Timestamp')) {
      // Dynamic parsing of Firestore Timestamp without coupling domain to Firestore
      try {
        final seconds = (rawTimestamp as dynamic).seconds as int;
        parsedDate = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else if (rawTimestamp is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else {
      parsedDate = DateTime.now();
    }

    final rawImages = map['imageUrls'];
    final List<String> images = rawImages is List
        ? rawImages.map((e) => e.toString()).toList()
        : const [];

    final rawLikes = map['likes'];
    bool liked = false;
    if (currentUserId != null && rawLikes is Map) {
      liked = rawLikes[currentUserId] != null;
    }

    return CommunityPost(
      id: id,
      authorId: map['userId'] ?? map['authorId'] ?? '',
      authorName: map['userName'] ?? map['authorName'] ?? 'Anonymous',
      authorPhotoUrl: map['userImageUrl'] ?? map['authorPhotoUrl'] ?? '',
      authorRole: map['userRole'] ?? map['authorRole'] ?? 'student',
      caption: map['caption'] ?? '',
      imageUrls: images,
      createdAt: parsedDate,
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: liked,
      isPinned: map['isPinned'] == true,
      isHidden: map['isHidden'] == true,
      isEdited: map['isEdited'] == true,
      linkUrl: map['linkUrl'],
      linkTitle: map['linkTitle'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': authorId,
      'userName': authorName,
      'userImageUrl': authorPhotoUrl,
      'userRole': authorRole,
      'caption': caption,
      'imageUrls': imageUrls,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'isPinned': isPinned,
      'isHidden': isHidden,
      'isEdited': isEdited,
      if (linkUrl != null) 'linkUrl': linkUrl,
      if (linkTitle != null) 'linkTitle': linkTitle,
    };
  }
}

