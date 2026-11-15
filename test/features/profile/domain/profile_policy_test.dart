import 'package:calligro_app/features/profile/domain/profile_models.dart';
import 'package:calligro_app/features/profile/domain/profile_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every "who sees what" rule of the profile screens, for every role × viewer.
void main() {
  const student = ProfileViewer(userId: 's1', role: 'student');
  const teacher = ProfileViewer(userId: 't1', role: 'teacher');
  const admin = ProfileViewer(userId: 'a1', role: 'admin');
  const guest = ProfileViewer.guest;

  UserProfile profile(String id, String role) => UserProfile(id: id, role: role);

  group('own profile', () {
    test('is yours only when the ids match (guests never own one)', () {
      expect(ProfilePolicy.isOwn(student, 's1'), isTrue);
      expect(ProfilePolicy.isOwn(student, 't1'), isFalse);
      expect(ProfilePolicy.isOwn(guest, ''), isFalse);
    });

    test('tabs: students and teachers see Saved + Liked; admins also My Posts', () {
      expect(ProfilePolicy.tabs(profile('s1', 'student'), student), [ProfileTab.saved, ProfileTab.liked]);
      expect(ProfilePolicy.tabs(profile('t1', 'teacher'), teacher), [ProfileTab.saved, ProfileTab.liked]);
      expect(ProfilePolicy.tabs(profile('a1', 'admin'), admin), [ProfileTab.myPosts, ProfileTab.saved, ProfileTab.liked]);
    });

    test('settings button on your own profile only', () {
      expect(ProfilePolicy.showSettings(profile('s1', 'student'), student), isTrue);
      expect(ProfilePolicy.showSettings(profile('s1', 'student'), teacher), isFalse);
    });

    test('commission and email are private to the owner', () {
      final t = profile('t1', 'teacher');
      expect(ProfilePolicy.showCommission(t, teacher), isTrue);
      expect(ProfilePolicy.showCommission(t, student), isFalse);
      expect(ProfilePolicy.showCommission(profile('s1', 'student'), student), isFalse, reason: 'teachers only');
      expect(ProfilePolicy.showEmail(profile('a1', 'admin'), admin), isTrue);
      expect(ProfilePolicy.showEmail(profile('a1', 'admin'), student), isFalse);
      expect(ProfilePolicy.showEmail(profile('s1', 'student'), student), isFalse, reason: 'admins only, as before');
    });
  });

  group('someone else\'s profile', () {
    test('tabs: a teacher shows Courses, Reviews, Posts; everyone else Posts', () {
      expect(ProfilePolicy.tabs(profile('t1', 'teacher'), student), [ProfileTab.courses, ProfileTab.reviews, ProfileTab.posts]);
      expect(ProfilePolicy.tabs(profile('t1', 'teacher'), guest), [ProfileTab.courses, ProfileTab.reviews, ProfileTab.posts]);
      expect(ProfilePolicy.tabs(profile('s1', 'student'), teacher), [ProfileTab.posts]);
      expect(ProfilePolicy.tabs(profile('a1', 'admin'), student), [ProfileTab.posts]);
    });

    test('a teacher opening their own PUBLIC page sees the public tabs', () {
      expect(ProfilePolicy.tabs(profile('t1', 'teacher'), teacher, publicView: true),
          [ProfileTab.courses, ProfileTab.reviews, ProfileTab.posts]);
    });

    test('follow button: signed-in viewers on other people\'s profiles', () {
      expect(ProfilePolicy.showFollow(profile('t1', 'teacher'), student), isTrue);
      expect(ProfilePolicy.showFollow(profile('t1', 'teacher'), teacher), isFalse, reason: 'yourself');
      expect(ProfilePolicy.showFollow(profile('t1', 'teacher'), guest), isFalse);
    });

    test('guests may open teacher profiles only', () {
      expect(ProfilePolicy.canOpen(guest, 'teacher'), isTrue);
      expect(ProfilePolicy.canOpen(guest, 'student'), isFalse);
      expect(ProfilePolicy.canOpen(guest, 'admin'), isFalse);
      expect(ProfilePolicy.canOpen(student, 'student'), isTrue);
    });

    test('only teacher and student/admin profiles exist', () {
      expect(ProfilePolicy.hasPublicPage('teacher'), isTrue);
      expect(ProfilePolicy.hasPublicPage('student'), isTrue);
      expect(ProfilePolicy.hasPublicPage('admin'), isTrue);
      expect(ProfilePolicy.hasPublicPage('pending'), isFalse);
      expect(ProfilePolicy.hasPublicPage(''), isFalse);
    });
  });

  group('tapping someone in a followers / following list', () {
    test('yourself → your own profile tab', () {
      expect(ProfilePolicy.followListTap(viewer: student, shownProfileId: 't1', tappedId: 's1'),
          FollowListTapResult.openOwnProfile);
    });
    test('the profile you are on → just close the list', () {
      expect(ProfilePolicy.followListTap(viewer: student, shownProfileId: 't1', tappedId: 't1'),
          FollowListTapResult.closeOnly);
    });
    test('anyone else → their profile', () {
      expect(ProfilePolicy.followListTap(viewer: student, shownProfileId: 't1', tappedId: 's2'),
          FollowListTapResult.openTheirProfile);
    });
  });

  group('UserProfile', () {
    test('average rating, safe with no reviews', () {
      expect(const UserProfile(id: 't', role: 'teacher', totalStars: 9, reviewCount: 2).averageRating, 4.5);
      expect(const UserProfile(id: 't', role: 'teacher').averageRating, 0);
    });
    test('role helpers', () {
      expect(profile('t', 'teacher').isTeacher, isTrue);
      expect(profile('a', 'admin').isAdmin, isTrue);
      expect(profile('s', 'student').isTeacher, isFalse);
    });
  });
}
