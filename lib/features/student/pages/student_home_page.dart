import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/core/utils/guest_guard.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ IMPORTS
import '../../student/widgets/student_drawer.dart';
import '../../student/data/model/student_user_model.dart';
import '../../student/data/services/student_service.dart';
import '../../../core/widgets/auto_translated_text.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/smart_image.dart';
import '../../../core/widgets/rating_display.dart';
import '../../../core/utils/course_utils.dart';
import '../../teacher/pages/notifications/notifications_page.dart';
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart';
import 'gallery_page.dart';
import 'teachers_page.dart';
import 'course_preview_page.dart';
import '../../teacher/pages/course_details/course_details_page.dart';
import '../../gallery/services/gallery_service.dart';
import '../../gallery/models/gallery_artist.dart';
import '../../gallery/pages/artist_bio_page.dart';
import '../../gallery/pages/artist_gallery_page.dart';

class StudentHomePage extends StatefulWidget {
  final bool isGuestMode;
  final Function(String?)? onGoToCourses;
  final VoidCallback? onProfileTap;

  const StudentHomePage({
    super.key,
    this.isGuestMode = false,
    this.onGoToCourses,
    this.onProfileTap,
  });

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final StudentService _service = StudentService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _heroPageController = PageController();

  late Stream<StudentUserModel> _studentStream;
  late Stream<List<Map<String, dynamic>>> _enrolledCoursesStream;
  late Stream<List<GalleryArtist>> _galleryStream;
  late Stream<List<Map<String, dynamic>>> _teachersStream;
  late Stream<List<Map<String, dynamic>>> _featuredCoursesStream;

  @override
  void initState() {
    super.initState();
    _studentStream = _service.getStudentStream();
    _enrolledCoursesStream = _service.getEnrolledCourses();
    _galleryStream = GalleryService().getArtistsStream();
    _teachersStream = _service.getTeachersStream();
    _featuredCoursesStream = _service.getFeaturedCourses();
    _precacheGalleryImages();
  }

  void _precacheGalleryImages() {
    final List<String> galleryImages = []; // Removed broken placeholder Unsplash URLs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final url in galleryImages) {
        if (url.isNotEmpty) {
           precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
    });
  }


  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context)!;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
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

        if (snapshot.connectionState == ConnectionState.waiting && !widget.isGuestMode && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
          );
        }

        final student = snapshot.data ?? StudentUserModel.guest();
        return _buildHomeScaffold(context, l10n, student);
      },
    );
  }

  Widget _buildHomeScaffold(BuildContext context, AppLocalizations l10n, StudentUserModel student) {
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
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentGold.withOpacity(0.1),
                  ),
                ).animate().fadeIn(duration: 1000.ms).scale(begin: const Offset(0.8, 0.8)),
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
                  SliverToBoxAdapter(
                    child: _buildStatsRow(student),
                  ),

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
                      child: _buildSectionTitle(l10n.myLearning, () => widget.onGoToCourses?.call(l10n.myCourses)),
                    ),
                    SliverToBoxAdapter(
                      child: _buildEnrolledCoursesList(),
                    ),
                  ],

                   // --- Gallery (Prototype) ---
                   SliverToBoxAdapter(
                     child: _buildSectionTitle(l10n.gallery, () {
                       if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
                         Navigator.push(context, MaterialPageRoute(builder: (context) => const GalleryPage()));
                       }
                     }),
                   ),
                   SliverToBoxAdapter(
                     child: _buildGallerySection(),
                   ),

                  // --- Teachers ---
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(l10n.instructors, () {
                      if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const TeachersPage()));
                      }
                    }),
                  ),
                  SliverToBoxAdapter(
                    child: _buildTeachersSection(),
                  ),

                  // --- Discovery (Trending Courses) ---
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(l10n.exploreCourses, () => widget.onGoToCourses?.call(l10n.all)),
                  ),
                  SliverToBoxAdapter(
                    child: _buildExploreCoursesList(),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ],
          ),
        );
  }

  // --- UI COMPONENTS ---

   Widget _buildPersonalizedHeader(AppLocalizations l10n, StudentUserModel student) {
    return Row(
      children: [
        // --- Hamburger Menu ---
        _buildHeaderIconButton(
          Icons.menu,
          () => _scaffoldKey.currentState?.openDrawer(),
        ).animate().fadeIn(delay: 200.ms).scale(),

        const SizedBox(width: 16),

        // --- Greeting & Name ---
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(context),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn(delay: 400.ms).slideX(),
              const SizedBox(height: 4),
              Text(
                widget.isGuestMode ? l10n.guest : student.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 600.ms).slideX(),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // --- Profile Image (Added back) ---
        GestureDetector(
          onTap: () {
            if (widget.onProfileTap != null) {
              widget.onProfileTap!();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentGold.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18, // Slightly smaller to fit with other icons
              backgroundColor: AppColors.cardBackground,
              backgroundImage: (!widget.isGuestMode && student.photoUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(student.photoUrl)
                  : null,
              child: (widget.isGuestMode || student.photoUrl.isEmpty)
                  ? const Icon(Icons.person, color: AppColors.accentGold, size: 20)
                  : null,
            ),
          ),
        ).animate().fadeIn(delay: 700.ms).scale(),

        const SizedBox(width: 12),

         // --- Notifications ---
         _buildHeaderIconButton(
           Icons.notifications_outlined,
           () {
             if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (context) => const NotificationsPage()),
               );
             }
           },
         ).animate().fadeIn(delay: 800.ms).scale(),
      ],
    );
  }

  Widget _buildHeaderIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentGold, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2);
  }

  Widget _buildStatsRow(StudentUserModel student) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _enrolledCoursesStream,
      builder: (context, snapshot) {
        final courseCount = snapshot.data?.length ?? 0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildStatItem(Icons.auto_stories_rounded, courseCount.toString(), AppLocalizations.of(context)!.courses),
              const SizedBox(width: 16),
              // Replaced Certificates with Following
              _buildStatItem(Icons.people_outline, student.followingCount.toString(), AppLocalizations.of(context)!.following),
            ],
          ),
        );
      },
    );
  }

   Widget _buildDynamicHeroSection(AppLocalizations l10n) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _enrolledCoursesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildAmbientVideoLoop(l10n),
          );
        }

        final now = DateTime.now();
        // Filter out ended courses
        final activeCourses = snapshot.data!.where((course) {
          final endDateData = course['endDate'];
          if (endDateData == null) return true; // Assume ongoing if no end date
          
          DateTime endDate;
          if (endDateData is Timestamp) {
            endDate = endDateData.toDate();
          } else if (endDateData is DateTime) {
            endDate = endDateData;
          } else {
            return true;
          }
          
          // Course is active if end date is in the future
          return endDate.isAfter(now);
        }).toList();

        // --- NEW: Calculate Next Session Helper ---
        DateTime? getNextSession(Map<String, dynamic> course) {
          final startTimeData = course['startTime'];
          final selectedDays = List<String>.from(course['selectedDays'] ?? []);
          
          if (startTimeData == null || selectedDays.isEmpty) return null;

          DateTime startTime;
          if (startTimeData is Timestamp) {
            startTime = startTimeData.toDate().toLocal();
          } else if (startTimeData is DateTime) {
            startTime = startTimeData.toLocal();
          } else {
            return null;
          }

          // Check if course hasn't started yet
          final startDateData = course['startDate'];
          DateTime? startDate;
          if (startDateData is Timestamp) {
            startDate = startDateData.toDate().toLocal();
          } else if (startDateData is DateTime) {
            startDate = startDateData.toLocal();
          }
          
          if (startDate != null && startDate.isAfter(now)) {
            return startDate;
          }

          final dayFormat = DateFormat('EEEE', 'en_US');
          
          for (int i = -1; i < 7; i++) {
              final checkDate = now.add(Duration(days: i));
              final dayName = dayFormat.format(checkDate);
              
              if (selectedDays.contains(dayName)) {
                  final localStartTime = startTime.toLocal();
                  final sessionTime = DateTime(
                      checkDate.year,
                      checkDate.month,
                      checkDate.day,
                      localStartTime.hour,
                      localStartTime.minute,
                  );

                  Duration sessionDuration = const Duration(minutes: 90);
                  if (course['endTime'] != null) {
                     DateTime? endDateTime;
                     if (course['endTime'] is Timestamp) {
                       endDateTime = (course['endTime'] as Timestamp).toDate();
                     } else if (course['endTime'] is DateTime) endDateTime = course['endTime'];
                     
                     DateTime? originalStartDateTime;
                     if (course['startTime'] is Timestamp) {
                       originalStartDateTime = (course['startTime'] as Timestamp).toDate();
                     } else if (course['startTime'] is DateTime) originalStartDateTime = course['startTime'];

                     if (endDateTime != null && originalStartDateTime != null) {
                       sessionDuration = endDateTime.difference(originalStartDateTime);
                       if (sessionDuration.inMinutes <= 0) sessionDuration = const Duration(minutes: 90);
                     }
                  }

                  final sessionEndTime = sessionTime.add(sessionDuration);

                  // If it's live right now, treat it as the most urgent (next session is essentially 'now')
                  if (now.isAfter(sessionTime) && now.isBefore(sessionEndTime)) {
                      return now;
                  }
                  
                  if (sessionTime.isAfter(now)) {
                      return sessionTime;
                  }
              }
          }
          return null;
        }

        // --- NEW: Sort courses by closeness to next session ---
        activeCourses.sort((a, b) {
          final nextA = getNextSession(a);
          final nextB = getNextSession(b);
          
          // If both have no predictable session, they tie
          if (nextA == null && nextB == null) return 0;
          // Null means it has no next session scheduled, push to the end
          if (nextA == null) return 1;
          if (nextB == null) return -1;
          
          // Compare dates (closer date comes first)
          return nextA.compareTo(nextB);
        });

        if (activeCourses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AmbientVideoPlayer(
              key: const ValueKey("hero_video_loop"),
              videoPath: 'assets/videos/numbers.m4v',
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 360, // Increased to accommodate Arabic text without overflow
              child: PageView.builder(
                controller: _heroPageController,
                itemCount: activeCourses.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSessionCountdownCard(activeCourses[index]),
                  );
                },
              ),
            ),
            if (activeCourses.length > 1) ...[
              const SizedBox(height: 12),
              _buildPageIndicator(activeCourses.length),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPageIndicator(int count) {
    return ListenableBuilder(
      listenable: _heroPageController,
      builder: (context, child) {
        int currentPage = 0;
        try {
          currentPage = _heroPageController.page?.round() ?? 0;
        } catch (_) {}
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: currentPage == index ? 18 : 6,
              decoration: BoxDecoration(
                color: currentPage == index ? AppColors.accentGold : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSessionCountdownCard(Map<String, dynamic> course) {
    final banner = course['courseBanner'] ?? '';
    final meetLink = course['calligroMeetLink'] ?? course['googleMeetLink'] ?? ''; // Support both
    final l10n = AppLocalizations.of(context)!;
    
    // Local state for the button enable/disable
    final ValueNotifier<bool> isButtonEnabled = ValueNotifier<bool>(false);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.1)),
        image: DecorationImage(
          image: banner.startsWith('assets') 
              ? AssetImage(banner) as ImageProvider 
              : CachedNetworkImageProvider(banner),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.7), // Darkened overlay as requested
            BlendMode.darken,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.nextSession.toUpperCase(),
                    style: const TextStyle(color: AppColors.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                const Icon(Icons.auto_awesome, color: AppColors.accentGold, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            AutoTranslatedText(
              CourseUtils.getLocalizedCourseName(context, course),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.accentGold.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accentGold.withOpacity(0.5), width: 1),
                            ),
                            child: ProfileAvatar(
                              radius: 14,
                              imageUrl: (course['teacherPhoto'] ?? course['teacherProfilePic'])?.toString() ?? '',
                              placeholderIcon: Icons.person,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            course['teacherName'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.verified, color: AppColors.accentGold.withOpacity(0.8), size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _CountdownTimer(
              course: course,
              onTimerUpdate: (remaining) {
                isButtonEnabled.value = remaining <= Duration.zero;
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: isButtonEnabled,
              builder: (context, enabled, child) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: enabled ? () => _launchClass(meetLink) : null,
                    icon: const Icon(Icons.videocam),
                    label: Text(
                      enabled ? l10n.joinClassNow : l10n.classNotStarted,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: enabled ? AppColors.accentGold : Colors.white.withOpacity(0.05),
                      foregroundColor: enabled ? Colors.black : Colors.white.withOpacity(0.3),
                      disabledBackgroundColor: Colors.white.withOpacity(0.02),
                      disabledForegroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: enabled ? Colors.transparent : Colors.white.withOpacity(0.05),
                        ),
                      ),
                      elevation: enabled ? 8 : 0,
                      shadowColor: AppColors.accentGold.withOpacity(0.3),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, curve: Curves.easeOut).scaleXY(begin: 0.95, curve: Curves.easeOut);
  }

  Future<void> _launchClass(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Could not launch meeting link")),
         );
      }
    }
  }





  Widget _buildAmbientVideoLoop(AppLocalizations l10n) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Video Player
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AmbientVideoPlayer(
              key: const ValueKey("hero_video_loop"),
              videoPath: 'assets/videos/numbers.m4v',
            ),
          ),

          // 2. Dark Overlay for Text Readability
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.95),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 3. Motivational Text & Action
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.heroTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  l10n.heroSubtitle,
                  style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () {
                     // Scroll to "Explore Courses"
                     widget.onGoToCourses?.call(null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 12,
                    shadowColor: AppColors.accentGold.withOpacity(0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.heroButton, 
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 22),
                    ],
                  ),
                ).animate().fadeIn(delay: 1100.ms).scale(begin: const Offset(0.95, 0.95)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1);
  }

  Widget _buildSectionTitle(String title, VoidCallback onSeeAll) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: onSeeAll,
            child: Text(l10n.seeAll, style: const TextStyle(color: AppColors.accentGold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledCoursesList() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 300,
      child: StreamBuilder<List<Map<String, dynamic>>>(
         stream: _enrolledCoursesStream,
         builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
           }
           if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return Center(
               child: Text(
                 l10n.noEnrolledCourses,
                 style: TextStyle(color: Colors.white.withOpacity(0.5)),
               ),
             );
           }
           final courses = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: courses.length > 3 ? 3 : courses.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => _buildSimpleCourseCard(courses[index], heroPrefix: 'enrolled'),
          );
        },
      ),
    );
  }

  Widget _buildSimpleCourseCard(Map<String, dynamic> course, {required String heroPrefix}) {
     final String heroTag = '${heroPrefix}_h_${course['id']}';
    final currentUser = FirebaseAuth.instance.currentUser;
    final dynamic studentsRaw = course['enrolledStudents'];
    final List<dynamic> enrolledStudents = (studentsRaw is List) ? studentsRaw : [];
    final bool isEnrolled = currentUser != null && enrolledStudents.contains(currentUser.uid);
    final String banner = course['courseBanner'] ?? '';
    final double price = (course['price'] ?? 0).toDouble();
    final bool isFree = price == 0;
    final String level = _getCourseLevel(course['selectedCategory'] ?? 'Beginner');
    final String teacherName = course['teacherName'] ?? 'Teacher';
    final String teacherPhoto = course['teacherProfilePic'] ?? '';
    final int studentCount = enrolledStudents.length;

    return GestureDetector(
      onTap: () {
        if (isEnrolled) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CourseDetailsPage(
                  courseId: course['id'],
                  courseData: course,
                  heroTag: heroTag,
                ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CoursePreviewPage(
                  courseId: course['id'],
                  courseData: course,
                  heroTag: heroTag,
                ),
            ),
          );
        }
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 25,
              spreadRadius: -5,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- Background Image ---
              Hero(
                tag: heroTag,
                child: SmartImage(
                  imageUrl: banner,
                  fit: BoxFit.cover,
                  errorWidget: Image.asset('assets/courses_backgrounds/normal_writing.jpg', fit: BoxFit.cover),
                ),
              ),

              // --- Gradient Overlay ---
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // --- Top Badges & Schedule ---
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Level Badge
                        _buildMiniBadge(
                          level.toUpperCase(),
                          Colors.black.withOpacity(0.5),
                          isGlass: true,
                        ),
                        
                        // Price Badge
                        if (!isEnrolled)
                          _buildMiniBadge(
                            isFree ? AppLocalizations.of(context)!.free.toUpperCase() : "\$$price",
                            AppColors.accentGold,
                            textColor: Colors.black,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Schedule Badge
                    if (course['selectedDays'] != null && (course['selectedDays'] as List).isNotEmpty)
                      _buildScheduleBadge(course),
                  ],
                ),
              ),

              // --- Bottom Info Panel (Ultimate Glass) ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isEnrolled)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildEnrolledStatusBadge(),
                            ),
                          AutoTranslatedText(
                            CourseUtils.getLocalizedCourseName(context, course),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              height: 1.1,
                              letterSpacing: -0.5,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Teacher Avatar
                              ProfileAvatar(
                                radius: 14,
                                imageUrl: teacherPhoto,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  teacherName,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Student Count
                              if (studentCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.people_outline, color: AppColors.accentGold, size: 10),
                                      const SizedBox(width: 4),
                                      Text(
                                        NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(studentCount),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ).animate().fadeIn(delay: 400.ms),
                        ],
                      ),
                    ).animate().shimmer(
                      delay: 2000.ms,
                      duration: 1500.ms,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(
      duration: 400.ms,
      curve: Curves.easeOutBack,
      begin: const Offset(0.9, 0.9),
    );
  }

  Widget _buildEnrolledStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.greenAccent[700]!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent[700]!.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.greenAccent[400], size: 14),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context)!.enrolled.toUpperCase(),
            style: TextStyle(
              color: Colors.greenAccent[400],
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBadge(Map<String, dynamic> course) {
    final List<dynamic> days = course['selectedDays'] ?? [];
    if (days.isEmpty) return const SizedBox.shrink();

    final String locale = Localizations.localeOf(context).languageCode;
    String timeStr = "";
    if (course['startTime'] != null) {
      DateTime? startTime;
      if (course['startTime'] is Timestamp) {
        startTime = (course['startTime'] as Timestamp).toDate().toLocal();
      } else if (course['startTime'] is DateTime) {
        startTime = (course['startTime'] as DateTime).toLocal();
      }
      if (startTime != null) {
        timeStr = DateFormat.Hm(locale).format(startTime);
      }
    }

    final List<String> localizedDays = days.map((d) => _getLocalizedDayShort(context, d.toString())).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded, color: AppColors.accentGold, size: 12),
              const SizedBox(width: 6),
              Text(
                "${localizedDays.join(', ')}${timeStr.isNotEmpty ? ' • $timeStr' : ''}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLocalizedDayShort(BuildContext context, String day) {
    final l10n = AppLocalizations.of(context)!;
    final d = day.toLowerCase();
    String translated = day;
    
    if (d.contains('sun')) {
      translated = l10n.sunday;
    } else if (d.contains('mon')) {
      translated = l10n.monday;
    } else if (d.contains('tue')) {
      translated = l10n.tuesday;
    } else if (d.contains('wed')) {
      translated = l10n.wednesday;
    } else if (d.contains('thu')) {
      translated = l10n.thursday;
    } else if (d.contains('fri')) {
      translated = l10n.friday;
    } else if (d.contains('sat')) {
      translated = l10n.saturday;
    }

    // For Arabic, "الأحد" can be shortened to "أحد" by removing "ال"
    if (Localizations.localeOf(context).languageCode == 'ar' && translated.startsWith('ال')) {
      return translated.substring(2);
    }
    return translated;
  }

  Widget _buildMiniBadge(String text, Color color, {bool isGlass = false, Color textColor = Colors.white}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: isGlass ? 8 : 0, sigmaY: isGlass ? 8 : 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: isGlass ? Border.all(color: Colors.white.withOpacity(0.15)) : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  String _getCourseLevel(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('beginner')) return AppLocalizations.of(context)!.beginner;
    if (cat.contains('intermediate')) return AppLocalizations.of(context)!.intermediate;
    if (cat.contains('advanced')) return AppLocalizations.of(context)!.advanced;
    return category;
  }

  Widget _buildGallerySection() {
    return SizedBox(
      height: 220,
      child: StreamBuilder<List<GalleryArtist>>(
        stream: _galleryStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading gallery",
                style: TextStyle(color: Colors.redAccent.withOpacity(0.5), fontSize: 12),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }

          final artists = snapshot.data ?? [];
          final artistsWithPhoto = artists.where((a) => 
            (a.photoUrl != null && a.photoUrl!.isNotEmpty) || 
            a.id == "artist_ali_ghalib" || 
            a.id == "artist_abbas_albaghdadi"
          ).toList();

          if (artistsWithPhoto.isEmpty) {
            return Center(
              child: Text(
                "Coming Soon",
                style: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: artistsWithPhoto.length > 5 ? 5 : artistsWithPhoto.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final artist = artistsWithPhoto[index];
              return GestureDetector(
                onTap: () {
                  if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
                    final String name = artist.name;
                    final bool isOttoman = name.contains("خرائط") || name.contains("وثائق") || name.contains("عثمانيه") || name.contains("Ottoman");
                    final bool isRiqaa = name.contains("الرقاع") || name.contains("رقاع") || name.contains("Riqaa");
                    final bool isDiwani = name.contains("ديواني") || name.contains("Diwani");
                    final bool isMisc = name.contains("منوعات") || name.contains("Varieties");

                    if (isOttoman || isRiqaa || isDiwani || isMisc) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArtistGalleryPage(artist: artist),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArtistBioPage(artist: artist),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: 280,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (artist.photoUrl != null && artist.photoUrl!.isNotEmpty)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Blurred background fill
                                  CachedNetworkImage(
                                    imageUrl: artist.photoUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(color: AppColors.accentGold, strokeWidth: 2),
                                    ),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                  BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                    child: Container(color: Colors.black.withOpacity(0.3)),
                                  ),
                                  // Focused full-face image
                                  CachedNetworkImage(
                                    imageUrl: artist.photoUrl!,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center,
                                    placeholder: (context, url) => const SizedBox.shrink(),
                                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                                  ),
                                  // Dark wash over everything to ensure text pops and looks sleek
                                  Container(color: Colors.black.withOpacity(0.25)),
                                ],
                              ),
                            ),
                          )
                        else if (artist.id == "artist_ali_ghalib" || artist.id == "artist_abbas_albaghdadi")
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/gallery_placeholder_${artist.id.contains("ali") ? "1" : "2"}.jpg',
                                fit: BoxFit.cover,
                                color: Colors.black.withOpacity(0.3),
                                colorBlendMode: BlendMode.darken,
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artist.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
            },
          );
        },
      ),
    );
  }

  Widget _buildTeachersSection() {
    return SizedBox(
      height: 240,
      child: StreamBuilder<List<Map<String, dynamic>>>(
         stream: _teachersStream,
         builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
           }
           if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return Center(
               child: Text(
                 "No teachers found",
                 style: TextStyle(color: Colors.white.withOpacity(0.5)),
               ),
             );
           }
           final teachers = snapshot.data!;
           final teachersWithPhoto = teachers.where((t) => t['photoUrl'] != null && t['photoUrl'].toString().trim().isNotEmpty).toList();

           if (teachersWithPhoto.isEmpty) {
             return Center(
               child: Text(
                 "No teachers found",
                 style: TextStyle(color: Colors.white.withOpacity(0.5)),
               ),
             );
           }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: teachersWithPhoto.length > 3 ? 3 : teachersWithPhoto.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => _buildTeacherCard(teachersWithPhoto[index]),
          );
        },
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    return GestureDetector(
      onTap: () {
        if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicTeacherProfilePage(userId: teacher['id'] ?? ''),
            ),
          );
        }
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProfileAvatar(
              radius: 35,
              imageUrl: teacher['photoUrl']?.toString() ?? '',
            ),
            const SizedBox(height: 12),
            Text(
              teacher['name'] ?? 'Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            RatingDisplay(
              averageRating: (teacher['totalStars'] ?? 0).toDouble(),
              reviewCount: teacher['reviewCount'] ?? 0,
              isCompact: true,
              starSize: 12,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                AppLocalizations.of(context)!.teacher.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreCoursesList() {
    return SizedBox(
      height: 300,
      child: StreamBuilder<List<Map<String, dynamic>>>(
         stream: _featuredCoursesStream,
         builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
           }
           if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return Center(
               child: Text(
                 "No courses found",
                 style: TextStyle(color: Colors.white.withOpacity(0.5)),
               ),
             );
           }
           final courses = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: courses.length > 3 ? 3 : courses.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => _buildSimpleCourseCard(courses[index], heroPrefix: 'featured'),
          );
        },
      ),
    );
  }



  // --- Helper Methods ---




}

 class _CountdownTimer extends StatefulWidget {
  final Map<String, dynamic> course;
  final Function(Duration)? onTimerUpdate;
  const _CountdownTimer({required this.course, this.onTimerUpdate});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  Duration _remaining = const Duration(hours: 99); // Start with a safe "long wait" to avoid 0s blink

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure context is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculateRemaining();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateRemaining());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    try {
      final startTimeData = widget.course['startTime'];
      final startDateData = widget.course['startDate'];
      final selectedDays = List<String>.from(widget.course['selectedDays'] ?? []);
      
      // Fallback: If data is missing, we keep it disabled
      if (startTimeData == null || selectedDays.isEmpty) {
        if (mounted) {
          setState(() => _remaining = const Duration(hours: 99)); 
          widget.onTimerUpdate?.call(const Duration(hours: 99));
        }
        return;
      }

      DateTime startTime;
      if (startTimeData is Timestamp) {
        startTime = startTimeData.toDate().toLocal();
      } else if (startTimeData is DateTime) {
        startTime = startTimeData.toLocal();
      } else {
        if (mounted) {
          setState(() => _remaining = const Duration(hours: 99));
          widget.onTimerUpdate?.call(const Duration(hours: 99));
        }
        return;
      }

      DateTime? startDate;
      if (startDateData is Timestamp) {
        startDate = startDateData.toDate().toLocal();
      } else if (startDateData is DateTime) {
        startDate = startDateData.toLocal();
      }

      final now = DateTime.now();
      
      // 1. Check if course hasn't even started yet
      if (startDate != null && startDate.isAfter(now)) {
        final diffToStart = startDate.difference(now);
        if (mounted) {
          setState(() => _remaining = diffToStart);
          widget.onTimerUpdate?.call(_remaining);
        }
        return;
      }

      DateTime? nextSession;
      bool isCurrentlyLive = false;

      // 2. Loop through the next 7 days for the weekly schedule
      // CRITICAL: We MUST use 'en_US' here because the DB stores English day names
      final dayFormat = DateFormat('EEEE', 'en_US');
      
      for (int i = -1; i < 7; i++) {
          final checkDate = now.add(Duration(days: i));
          final dayName = dayFormat.format(checkDate);
          
          if (selectedDays.contains(dayName)) {
              // Fix: Convert UTC startTime to local before using hour/minute
              final localStartTime = startTime.toLocal();
              final sessionTime = DateTime(
                  checkDate.year,
                  checkDate.month,
                  checkDate.day,
                  localStartTime.hour,
                  localStartTime.minute,
              );

              // --- DYNAMIC DURATION LOGIC ---
              Duration sessionDuration = const Duration(minutes: 90);
              if (widget.course['endTime'] != null) {
                 DateTime? endDateTime;
                 if (widget.course['endTime'] is Timestamp) {
                   endDateTime = (widget.course['endTime'] as Timestamp).toDate();
                 } else if (widget.course['endTime'] is DateTime) {
                   endDateTime = widget.course['endTime'];
                 }
                 
                 // We need the original start time to calculate duration difference
                 DateTime? originalStartDateTime;
                 if (widget.course['startTime'] is Timestamp) {
                   originalStartDateTime = (widget.course['startTime'] as Timestamp).toDate();
                 } else if (widget.course['startTime'] is DateTime) {
                   originalStartDateTime = widget.course['startTime'];
                 }

                 if (endDateTime != null && originalStartDateTime != null) {
                   sessionDuration = endDateTime.difference(originalStartDateTime);
                   // Sanity check for negative or zero duration
                   if (sessionDuration.inMinutes <= 0) {
                     sessionDuration = const Duration(minutes: 90);
                   }
                 }
              }

              final sessionEndTime = sessionTime.add(sessionDuration);

              if (now.isAfter(sessionTime) && now.isBefore(sessionEndTime)) {
                  isCurrentlyLive = true;
                  break;
              }
              
              if (sessionTime.isAfter(now)) {
                  nextSession = sessionTime;
                  break;
              }
          }
      }

      if (mounted) {
        setState(() {
          if (isCurrentlyLive) {
            _remaining = Duration.zero;
          } else if (nextSession != null) {
            _remaining = nextSession.difference(now);
          } else {
            _remaining = const Duration(hours: 99); 
          }
        });
        widget.onTimerUpdate?.call(isCurrentlyLive ? Duration.zero : _remaining);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _remaining = const Duration(hours: 99));
        widget.onTimerUpdate?.call(const Duration(hours: 99));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = _remaining.inDays.toString();
    final hrs = twoDigits(_remaining.inHours.remainder(24));
    final mins = twoDigits(_remaining.inMinutes.remainder(60));
    final secs = twoDigits(_remaining.inSeconds.remainder(60));

    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimePart(days, l10n.timerDays),
        _buildDivider(),
        _buildTimePart(hrs, l10n.timerHrs),
        _buildDivider(),
        _buildTimePart(mins, l10n.timerMin),
        _buildDivider(),
        _buildTimePart(secs, l10n.timerSec),
      ],
    );
  }

  Widget _buildTimePart(String value, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Center(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        ":",
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

class AmbientVideoPlayer extends StatefulWidget {
  final String videoPath;
  const AmbientVideoPlayer({super.key, required this.videoPath});

  @override
  State<AmbientVideoPlayer> createState() => _AmbientVideoPlayerState();
}

class _AmbientVideoPlayerState extends State<AmbientVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  int _retryCount = 0;

  Future<void> _initializePlayer() async {
    if (!mounted) return;

    // Dispose previous controller if any
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    if (mounted) {
      setState(() {
        _initialized = false;
        _hasError = false;
      });
    }

    final controller = VideoPlayerController.asset(
      widget.videoPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
          _retryCount = 0; // Reset count on success
        });
      }
    } catch (error) {
      debugPrint('❌ VIDEO PLAYER ERROR (Attempt ${_retryCount + 1}): $error');
      
      if (_retryCount < 3 && mounted) {
        _retryCount++;
        // exponential backoff
        await Future.delayed(Duration(seconds: _retryCount * 2));
        _initializePlayer();
      } else if (mounted) {
        setState(() {
          _hasError = true;
          _initialized = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(AmbientVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _initializePlayer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !_initialized) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      controller.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: AppColors.cardBackground,
        child: const Center(
          child: Icon(Icons.movie_filter_outlined, color: Colors.white54, size: 40),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}