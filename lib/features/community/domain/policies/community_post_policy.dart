/// Pure domain policy governing community post rules, validations and permissions.
class CommunityPostPolicy {
  static const int maxImagesPerPost = 10;
  static const int maxCaptionLength = 3000;
  static const int maxCommentLength = 1000;

  /// Checks if a post has sufficient content to be created.
  static bool canCreatePost({
    required String caption,
    required int imageCount,
    String? linkUrl,
  }) {
    if (imageCount > maxImagesPerPost) return false;
    final hasText = caption.trim().isNotEmpty;
    final hasImages = imageCount > 0;
    final hasLink = linkUrl != null && linkUrl.trim().isNotEmpty;
    return hasText || hasImages || hasLink;
  }

  /// Only admins can attach external links to posts.
  static bool canAttachLink({required String userRole}) {
    return userRole.toLowerCase() == 'admin';
  }

  /// Only admins can pin posts to the top of the feed.
  static bool canPinPost({required String userRole}) {
    return userRole.toLowerCase() == 'admin';
  }

  /// A post can only be edited by its original author or a platform admin.
  static bool canEditPost({
    required String currentUserId,
    required String authorId,
    required bool isAdmin,
  }) {
    return currentUserId == authorId || isAdmin;
  }

  /// A post can only be deleted by its original author or a platform admin.
  static bool canDeletePost({
    required String currentUserId,
    required String authorId,
    required bool isAdmin,
  }) {
    return currentUserId == authorId || isAdmin;
  }

  /// Validates caption length. Returns error string if invalid, or null if valid.
  static String? validateCaption(String caption) {
    if (caption.length > maxCaptionLength) {
      return 'Caption cannot exceed $maxCaptionLength characters';
    }
    return null;
  }

  /// Validates comment text. Returns error string if invalid, or null if valid.
  static String? validateComment(String comment) {
    if (comment.trim().isEmpty) {
      return 'Comment cannot be empty';
    }
    if (comment.length > maxCommentLength) {
      return 'Comment cannot exceed $maxCommentLength characters';
    }
    return null;
  }
}

