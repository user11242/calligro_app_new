import 'package:calligro_app/core/utils/search_normalizer.dart';

import 'course_policy.dart';

/// The teacher creating a course, as the course document needs them.
class CourseAuthor {
  final String id;
  final String name;
  final String photoUrl;

  /// Bank / CliQ details saved (private payout document).
  final bool hasPayoutInfo;

  /// The teacher's share (0.7 = 70%), set by an admin. null = not set yet.
  final double? commissionRate;

  const CourseAuthor({
    required this.id,
    this.name = '',
    this.photoUrl = '',
    this.hasPayoutInfo = false,
    this.commissionRate,
  });

  bool get hasCommissionRate => commissionRate != null;
  double get earningPercentage => (commissionRate ?? 0) * 100;
}

enum DraftProblem { missingWritingType, missingDates, endBeforeStart, noDays, badPrice, badMaxStudents }

/// What the add-course wizard collected (pure, unit-tested). [toDocument] is
/// the ONE place a course document is shaped, so it always matches what
/// Course.fromMap, the purchase flow and firestore.rules expect.
class CourseDraft {
  final String courseName;
  final String courseDescription;
  final String? writingType;
  final String? calligraphyStyle;
  final String level;
  final String? ageCategory;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<String> selectedDays;
  final List<Map<String, dynamic>> requiredTools;
  final List<String> curriculumSteps;
  final double price;
  final int maxStudents;

  const CourseDraft({
    this.courseName = '',
    this.courseDescription = '',
    this.writingType,
    this.calligraphyStyle,
    this.level = 'Beginner',
    this.ageCategory,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.selectedDays = const [],
    this.requiredTools = const [],
    this.curriculumSteps = const [],
    this.price = 0,
    this.maxStudents = defaultMaxStudents,
  });

  static const defaultMaxStudents = 30;

  /// Marks the course as having its Calligro Meet classroom (the Join buttons
  /// check it). LiveKit joins by course id; nothing external is created.
  static const calligroClassroomLink = 'calligro-meet';

  bool get hasCustomName => courseName.trim().isNotEmpty;

  List<DraftProblem> get problems => [
    if (writingType == null || writingType!.isEmpty) DraftProblem.missingWritingType,
    if (startDate == null || endDate == null) DraftProblem.missingDates,
    if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) DraftProblem.endBeforeStart,
    if (selectedDays.isEmpty) DraftProblem.noDays,
    // Store products are whole tiers (tier_60 … tier_200); 0 = free.
    if (price.isNaN || price < 0 || price != price.truncateToDouble()) DraftProblem.badPrice,
    if (maxStudents < 1) DraftProblem.badMaxStudents,
  ];

  /// The seats text field: a positive number, else 30 (as before).
  static int parseMaxStudents(String text) {
    final n = int.tryParse(SearchNormalizer.numerics(text.trim()));
    return n != null && n > 0 ? n : defaultMaxStudents;
  }

  static const _banners = 'assets/courses_backgrounds';
  static const _styleBanners = {
    'Kufi': 'kufi.png',
    'Naskh': 'naskh.jpg',
    "Ruq'ah": 'ruqah.jpg',
    'Thuluth': 'thuluth.jpg',
    'Jali Thuluth': 'thuluth_jali.jpg',
    'Diwani': 'diwani.jpg',
    'Jali Diwani': 'diwani_jali.png',
    "Persian (Ta'liq)": 'taliq.png',
    'Ijaza': 'ijaza.png',
    'Muhaqqiq': 'muhaqqaq.jpg',
    'Rayhani': 'rayhani.jpg',
  };

  static String bannerFor(String? writingType, String? style) {
    if (writingType == 'Normal Pen Writing') return '$_banners/normal_writing.jpg';
    if (writingType == 'Arabic Calligraphy' && style != null) {
      return '$_banners/${_styleBanners[style] ?? 'thuluth.jpg'}';
    }
    return '$_banners/thuluth.jpg';
  }

  String get banner => bannerFor(writingType, calligraphyStyle);

  /// The public course document. [createdAt] is the server timestamp (data
  /// layer); [generatedName] is the localised automatic name used when the
  /// teacher left the name empty. [meetLink] stays public (the Join buttons
  /// check it).
  Map<String, dynamic> toDocument(
    CourseAuthor author, {
    required Object createdAt,
    String generatedName = '',
    String meetLink = '',
  }) => {
    'courseName': hasCustomName ? courseName.trim() : generatedName,
    'courseDescription': courseDescription,
    'writingType': writingType,
    'calligraphyStyle': calligraphyStyle,
    'courseBanner': banner,
    'teacherProfilePic': author.photoUrl,
    'levelColor': level,
    'selectedCategory': level,
    'ageCategory': ageCategory,
    'startDate': startDate,
    'endDate': endDate,
    // The course's time zone (the teacher's, on the start date): every student, in
    // every country, sees the same class times. Older courses get it from the start
    // date (CourseSchedule.offsetFromStartDate).
    if (startDate != null) 'scheduleUtcOffsetMinutes': startDate!.timeZoneOffset.inMinutes,
    'selectedTime': startTime,
    'startTime': startTime,
    'endTime': endTime,
    'selectedDays': List<String>.of(selectedDays),
    'teacherId': author.id,
    'teacherName': author.name,
    'enrolledStudents': const <String>[],
    'enrolledCount': 0,
    'price': price,
    if (price > 0) 'iapProductId': '${CoursePolicy.productPrefix}${price.truncate()}',
    'calligroMeetLink': meetLink,
    'maxStudents': maxStudents,
    'requiredTools': [for (final t in requiredTools) Map<String, dynamic>.of(t)],
    'isAutoGeneratedName': !hasCustomName,
    'curriculumSteps': List<String>.of(curriculumSteps),
    'createdAt': createdAt,
  };
}
