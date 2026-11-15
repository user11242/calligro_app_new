import '../models/community_models.dart';
import '../models/community_post.dart';

/// Why a new post / edit / comment was refused.
enum CommunityValidationError { emptyPost, tooManyImages, emptyText }

/// Every community rule in one place (pure, unit-tested).
///
/// The UI uses these to decide what to SHOW; firestore.rules is what actually
/// ENFORCES them on the server.
class CommunityPolicy {
  CommunityPolicy._();

  static const maxImagesPerPost = 5;

  /// Feed size per query; whereIn (Friends / Saved) is limited to 30 ids by Firestore.
  static const feedPageSize = 20;
  static const maxWhereInIds = 30;

  // ── Creating / editing ─────────────────────────────────────────────────
  static CommunityValidationError? validateNewPost(NewPost post) {
    if (post.imagePaths.length > maxImagesPerPost) return CommunityValidationError.tooManyImages;
    final hasLink = post.linkUrl != null && post.linkUrl!.trim().isNotEmpty;
    if (post.caption.trim().isEmpty && post.imagePaths.isEmpty && !hasLink) {
      return CommunityValidationError.emptyPost;
    }
    return null;
  }

  static CommunityValidationError? validateEdit({required String caption, required int imageCount}) {
    if (imageCount > maxImagesPerPost) return CommunityValidationError.tooManyImages;
    if (caption.trim().isEmpty && imageCount == 0) return CommunityValidationError.emptyPost;
    return null;
  }

  /// "calligro.app" → "https://calligro.app"; blank → null.
  static String? normalizeLink(String? raw) {
    final link = raw?.trim() ?? '';
    if (link.isEmpty) return null;
    return link.startsWith('http://') || link.startsWith('https://') ? link : 'https://$link';
  }

  static CommunityValidationError? validateText(String text) =>
      text.trim().isEmpty ? CommunityValidationError.emptyText : null;

  /// Only admins may attach a link, pin, or publish hidden; strip those for everyone else.
  static NewPost sanitizeForAuthor(NewPost post, CommunitySession author) {
    final caption = post.caption.trim();
    if (author.isAdmin) {
      final link = normalizeLink(post.linkUrl);
      final title = post.linkTitle?.trim();
      return NewPost(
        caption: caption,
        imagePaths: post.imagePaths,
        linkUrl: (link?.isEmpty ?? true) ? null : link,
        linkTitle: (link?.isEmpty ?? true) || (title?.isEmpty ?? true) ? null : title,
        isPinned: post.isPinned,
        isHidden: post.isHidden,
      );
    }
    return NewPost(caption: caption, imagePaths: post.imagePaths);
  }

  // ── Post actions ───────────────────────────────────────────────────────
  static bool isAuthor(CommunitySession s, CommunityPost p) => !s.isGuest && s.userId == p.authorId;
  static bool canEdit(CommunitySession s, CommunityPost p) => isAuthor(s, p);
  static bool canDelete(CommunitySession s, CommunityPost p) => isAuthor(s, p) || s.isAdmin;
  static bool canPinOrHide(CommunitySession s) => s.isAdmin;

  /// Report / block someone else's post (admins moderate directly instead).
  static bool canReportOrBlock(CommunitySession s, CommunityPost p) => !s.isGuest && !isAuthor(s, p) && !s.isAdmin;

  /// Guests can read but not like, save, comment, follow, post.
  static bool canInteract(CommunitySession s) => !s.isGuest;

  // ── Comments / replies ─────────────────────────────────────────────────
  static bool canEditComment(CommunitySession s, CommunityComment c) => !s.isGuest && s.userId == c.authorId;

  /// The comment's author, the post's author, or an admin.
  static bool canDeleteComment(CommunitySession s, CommunityComment c, {required String postAuthorId}) =>
      !s.isGuest && (s.userId == c.authorId || s.userId == postAuthorId || s.isAdmin);

  /// The reply's author, the parent comment's author, or an admin (matches firestore.rules).
  static bool canDeleteReply(CommunitySession s, CommunityComment reply, {required String commentAuthorId}) =>
      !s.isGuest && (s.userId == reply.authorId || s.userId == commentAuthorId || s.isAdmin);

  // ── Feed ───────────────────────────────────────────────────────────────
  /// Hidden posts stay visible to admins and their author; posts by blocked users disappear.
  static bool isVisible(CommunityPost p, CommunitySession viewer, {Set<String> blockedUserIds = const {}}) {
    if (blockedUserIds.contains(p.authorId)) return false;
    if (p.isHidden && !viewer.isAdmin && viewer.userId != p.authorId) return false;
    return true;
  }

  /// Tabs a guest can't use (they need an account).
  static bool requiresAccount(CommunityFilter f) =>
      f == CommunityFilter.friends || f == CommunityFilter.myPosts || f == CommunityFilter.saved;

  /// Main feed = everything visible except pinned posts (shown separately on top).
  static List<CommunityPost> mainFeed(
    List<CommunityPost> posts,
    CommunitySession viewer, {
    Set<String> blockedUserIds = const {},
    bool excludePinned = true,
  }) =>
      posts
          .where((p) => isVisible(p, viewer, blockedUserIds: blockedUserIds))
          .where((p) => !excludePinned || !p.isPinned)
          .toList();
}
