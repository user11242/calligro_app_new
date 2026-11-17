import 'package:calligro_app/features/profile/presentation/pages/public_profile_page.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/auto_translated_text.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/features/student/data/student_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/core/utils/guest_guard.dart';
import 'package:calligro_app/core/utils/rating_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ IMPORTS
import '../widgets/student_drawer.dart';
import '../../data/student_user_model.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/rating_display.dart';
import '../../../../core/utils/course_utils.dart';
import '../../../../core/widgets/notification_bell_button.dart';
import '../../../gallery/pages/gallery_page.dart';
import 'teachers_page.dart';
import 'package:calligro_app/features/courses/presentation/pages/course_preview_page.dart';
import 'package:calligro_app/features/courses/domain/course_models.dart' show Course;
import 'package:calligro_app/features/courses/domain/course_policy.dart';
import 'package:calligro_app/features/courses/domain/course_schedule.dart';
import 'package:calligro_app/features/classroom/presentation/widgets/next_session_card.dart' show RescheduledTag, formatSessionTime;
import 'package:calligro_app/features/courses/presentation/course_scope.dart';
import 'package:calligro_app/core/utils/shared_latest_stream.dart';
import '../../../classroom/presentation/pages/course_details_page.dart';
import 'package:calligro_app/features/gallery/data/gallery_service.dart';
import 'package:calligro_app/features/gallery/domain/gallery_models.dart';
import 'package:calligro_app/features/gallery/presentation/localized_artist.dart';
import '../../../gallery/pages/artist_bio_page.dart';
import '../../../gallery/pages/artist_gallery_page.dart';
import '../../../rating/presentation/course_completion_rating_dialog.dart';
import '../../../rating/presentation/rating_scope.dart';

part 'student_home_header.dart';
part 'student_home_hero.dart';
part 'student_home_courses.dart';
part 'student_home_community.dart';
part 'student_home_countdown.dart';
part 'student_home_video.dart';

class StudentHomePage extends StatefulWidget {
  final bool isGuestMode;
  final StudentService? studentService;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final Function(String?)? onGoToCourses;
  final VoidCallback? onProfileTap;

  const StudentHomePage({
    super.key,
    this.isGuestMode = false,
    this.studentService,
    this.auth,
    this.firestore,
    this.onGoToCourses,
    this.onProfileTap,
  });

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  late final StudentService _service;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _heroPageController = PageController();

  late Stream<StudentUserModel> _studentStream;
  late Stream<List<Map<String, dynamic>>> _enrolledCoursesStream;
  late Future<List<GalleryArtist>> _galleryFuture;
  late Stream<List<Map<String, dynamic>>> _teachersStream;
  late Stream<List<Map<String, dynamic>>> _featuredCoursesStream;

  @override
  void initState() {
    super.initState();
    _service = widget.studentService ?? StudentService(auth: widget.auth, firestore: widget.firestore);
    _studentStream = _service.getStudentStream();
    _galleryFuture = GalleryService(firestore: widget.firestore).getArtistsList();
    _teachersStream = _service.getTeachersStream();
    _precacheGalleryImages();
    // After the first frame: the check reads the RatingScope.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkForUnratedCompletedCourses();
    });
  }

  bool _courseStreamsReady = false;
  SharedLatestStream<List<Map<String, dynamic>>>? _enrolledShared;
  SharedLatestStream<List<Map<String, dynamic>>>? _featuredShared;

  /// Course lists come from the course repository (live, real fields), as
  /// the maps the cards below already read.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_courseStreamsReady) return;
    _courseStreamsReady = true;
    final services = CourseScope.of(context);
    final uid = services.currentUid();
    List<Map<String, dynamic>> asMaps(Iterable<Course> list) => [for (final c in list) {...c.raw, 'id': c.id}];
    // Several sections read the same list: one subscription, shared.
    _enrolledShared = SharedLatestStream(services.courses.watchEnrolled(uid).map(asMaps));
    _enrolledCoursesStream = _enrolledShared!.stream;
    // Same rule as the catalogue: a started course is not offered to non-students.
    _featuredShared = SharedLatestStream(services.courses.watchCatalog().map((all) =>
        asMaps(all.where((c) => CoursePolicy.isVisibleInCatalog(c, uid, now: DateTime.now())).take(10))));
    _featuredCoursesStream = _featuredShared!.stream;
  }

  @override
  void dispose() {
    _enrolledShared?.dispose();
    _featuredShared?.dispose();
    _heroPageController.dispose();
    super.dispose();
  }

  /// At most ONE rating pop-up, for one finished course, chosen and recorded
  /// by CourseRatings (it used to come back on every visit).
  Future<void> _checkForUnratedCompletedCourses() async {
    if (widget.isGuestMode) return;
    final course = await RatingScope.of(context).courseToRate();
    if (course == null || !mounted) return;
    await showCourseCompletionRatingDialog(
      context: context,
      course: course,
      courseName: CourseUtils.getLocalizedCourseName(context, course.data),
    );
  }

  void _precacheGalleryImages() {
    final List<String> galleryImages =
        []; // Removed broken placeholder Unsplash URLs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final url in galleryImages) {
        if (url.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<StudentUserModel>(
      stream: _studentStream,
      initialData: widget.isGuestMode ? StudentUserModel.guest() : null,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Fallback to Guest Mode if an error occurs (e.g. during logout)
          final student = StudentUserModel.guest();
          return _buildHomeScaffold(context, l10n, student);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !widget.isGuestMode &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            ),
          );
        }

        final student = snapshot.data ?? StudentUserModel.guest();
        return _buildHomeScaffold(context, l10n, student);
      },
    );
  }

  Widget _buildHomeScaffold(
    BuildContext context,
    AppLocalizations l10n,
    StudentUserModel student,
  ) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.primary,
      drawer: StudentDrawer(
        student: student,
        isGuestMode: widget.isGuestMode,
        onGoToCourses: widget.onGoToCourses,
      ),
      drawerEnableOpenDragGesture: false,
      body: Stack(
        children: [
          // 🌌 Ambient Background Glow
          Positioned(
            top: -150,
            right: -100,
            child:
                Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentGold.withOpacity(0.1),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 1000.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- Header ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                  child: _buildPersonalizedHeader(l10n, student),
                ),
              ),

              // --- Statistics ---
              SliverToBoxAdapter(child: _buildStatsRow(student)),

              // --- Next Session / Hero ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: widget.isGuestMode
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildAmbientVideoLoop(l10n),
                        )
                      : _buildDynamicHeroSection(l10n),
                ),
              ),

              // --- My Learning (Enrolled Courses) ---
              if (!widget.isGuestMode) ...[
                SliverToBoxAdapter(
                  child: _buildSectionTitle(
                    l10n.myLearning,
                    () => widget.onGoToCourses?.call(l10n.myCourses),
                  ),
                ),
                SliverToBoxAdapter(child: _buildEnrolledCoursesList()),
              ],

              // --- Gallery (Prototype) ---
              SliverToBoxAdapter(
                child: _buildSectionTitle(l10n.gallery, () {
                  if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GalleryPage(),
                      ),
                    );
                  }
                }),
              ),
              SliverToBoxAdapter(child: _buildGallerySection()),

              // --- Teachers ---
              SliverToBoxAdapter(
                child: _buildSectionTitle(l10n.instructors, () {
                  if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TeachersPage(),
                      ),
                    );
                  }
                }),
              ),
              SliverToBoxAdapter(child: _buildTeachersSection()),

              // --- Discovery (Trending Courses) ---
              SliverToBoxAdapter(
                child: _buildSectionTitle(
                  l10n.exploreCourses,
                  () => widget.onGoToCourses?.call(l10n.all),
                ),
              ),
              SliverToBoxAdapter(child: _buildExploreCoursesList()),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---
}
