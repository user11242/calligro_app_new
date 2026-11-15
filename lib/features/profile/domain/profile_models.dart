/// A user's public profile (what other people may see) plus the few
/// owner-only fields the own-profile screen shows.
class UserProfile {
  final String id;
  final String name;
  final String photoUrl;
  final String bio;

  /// 'student', 'teacher' or 'admin'.
  final String role;
  final int followerCount;
  final int followingCount;

  // Teacher details.
  final List<String> spokenLanguages;
  final num totalStars;
  final int reviewCount;

  /// Flag emoji for the teacher's country ('' when unknown).
  final String countryFlag;

  // Shown to the owner only (see ProfilePolicy).
  final double? commissionRate;
  final String email;

  const UserProfile({
    required this.id,
    required this.role,
    this.name = '',
    this.photoUrl = '',
    this.bio = '',
    this.followerCount = 0,
    this.followingCount = 0,
    this.spokenLanguages = const [],
    this.totalStars = 0,
    this.reviewCount = 0,
    this.countryFlag = '',
    this.commissionRate,
    this.email = '',
  });

  bool get isTeacher => role == 'teacher';
  bool get isAdmin => role == 'admin';
  double get averageRating => reviewCount == 0 ? 0 : totalStars / reviewCount;
}

/// Who is looking at a profile.
class ProfileViewer {
  final String userId;
  final String role;
  const ProfileViewer({required this.userId, this.role = 'student'});

  static const guest = ProfileViewer(userId: '');
  bool get isGuest => userId.isEmpty;
}

/// Tabs under the profile header.
enum ProfileTab { courses, reviews, posts, myPosts, saved, liked }

enum FollowListKind {
  followers('followers'),
  following('following');

  const FollowListKind(this.collection);

  /// The users/{uid}/<collection> sub-collection.
  final String collection;
}

/// Someone in a followers / following list.
class FollowListEntry {
  final String id;
  final String name;
  final String photoUrl;
  final String role;
  const FollowListEntry({required this.id, this.name = '', this.photoUrl = '', this.role = 'student'});

  bool get isTeacher => role == 'teacher';
}

/// Counters shown on a profile (posts in the header, tab badges).
class ProfileCounts {
  final int posts;
  final int saved;
  final int liked;
  final int courses;
  const ProfileCounts({this.posts = 0, this.saved = 0, this.liked = 0, this.courses = 0});

  ProfileCounts copyWith({int? posts, int? saved, int? liked, int? courses}) => ProfileCounts(
        posts: posts ?? this.posts,
        saved: saved ?? this.saved,
        liked: liked ?? this.liked,
        courses: courses ?? this.courses,
      );
}

/// A course card on a teacher's profile. [raw] is handed unchanged to the
/// course pages, which still take the Firestore map.
class TeacherCourse {
  final String id;
  final String bannerUrl;
  final String level;
  final List<String> enrolledStudentIds;
  final int studentCount;
  final Map<String, dynamic> raw;
  const TeacherCourse({
    required this.id,
    required this.raw,
    this.bannerUrl = '',
    this.level = 'Beginner',
    this.enrolledStudentIds = const [],
    this.studentCount = 0,
  });

  bool isEnrolled(String userId) => userId.isNotEmpty && enrolledStudentIds.contains(userId);
}

/// A student's review of a teacher.
class TeacherReview {
  final String id;
  final String studentId;
  final String studentName;
  final String studentPhotoUrl;
  final String courseName;
  final int rating;
  final String text;
  final DateTime? createdAt;
  const TeacherReview({
    required this.id,
    this.studentId = '',
    this.studentName = '',
    this.studentPhotoUrl = '',
    this.courseName = '',
    this.rating = 5,
    this.text = '',
    this.createdAt,
  });
}
