import 'profile_models.dart';

enum FollowListTapResult { openOwnProfile, closeOnly, openTheirProfile }

/// Every "who sees what" rule of the profile screens (pure, unit-tested).
class ProfilePolicy {
  ProfilePolicy._();

  static bool isOwn(ProfileViewer viewer, String profileId) => !viewer.isGuest && viewer.userId == profileId;

  /// Tabs under the header. [publicView]: a public page, even when it is the viewer's own.
  static List<ProfileTab> tabs(UserProfile p, ProfileViewer viewer, {bool publicView = false}) {
    if (!publicView && isOwn(viewer, p.id)) {
      return [if (p.isAdmin) ProfileTab.myPosts, ProfileTab.saved, ProfileTab.liked];
    }
    return p.isTeacher ? const [ProfileTab.courses, ProfileTab.reviews, ProfileTab.posts] : const [ProfileTab.posts];
  }

  static bool showSettings(UserProfile p, ProfileViewer viewer) => isOwn(viewer, p.id);

  static bool showFollow(UserProfile p, ProfileViewer viewer) => !viewer.isGuest && !isOwn(viewer, p.id);

  /// The teacher's commission is between them and the platform.
  static bool showCommission(UserProfile p, ProfileViewer viewer) => p.isTeacher && isOwn(viewer, p.id);

  static bool showEmail(UserProfile p, ProfileViewer viewer) => p.isAdmin && isOwn(viewer, p.id);

  /// Guests may look at teachers (to choose one), not at other users.
  static bool canOpen(ProfileViewer viewer, String role) => !viewer.isGuest || role == 'teacher';

  static bool hasPublicPage(String role) => role == 'teacher' || role == 'student' || role == 'admin';

  static FollowListTapResult followListTap({
    required ProfileViewer viewer,
    required String shownProfileId,
    required String tappedId,
  }) {
    if (!viewer.isGuest && tappedId == viewer.userId) return FollowListTapResult.openOwnProfile;
    if (tappedId == shownProfileId) return FollowListTapResult.closeOnly;
    return FollowListTapResult.openTheirProfile;
  }
}
