import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class CourseShareCard extends StatelessWidget {
  final Map<String, dynamic> courseData;
  final String teacherName;
  final String teacherProfilePic;

  const CourseShareCard({
    super.key,
    required this.courseData,
    required this.teacherName,
    required this.teacherProfilePic,
  });

  @override
  Widget build(BuildContext context) {
    final bannerUrl = courseData['courseBanner'] ?? '';
    final calligraphyStyle = courseData['calligraphyStyle'] ?? 'Calligraphy';
    final courseName = CourseUtils.getLocalizedCourseName(context, courseData);

    return Container(
      width: 1080, // High res for Instagram/WhatsApp
      height: 1350, // 4:5 Aspect ratio (portrait)
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background/Main Image
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: bannerUrl.startsWith('assets')
                ? Image.asset(bannerUrl, fit: BoxFit.cover)
                : CachedNetworkImage(
                    imageUrl: bannerUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[900]),
                  ),
          ),
          
          // Dark Overlay for text readability
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0, 0.4, 1.0],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(60.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo & Style
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/Logo_zoomed.png',
                      height: 80,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        calligraphyStyle.toUpperCase(),
                        style: GoogleFonts.urbanist(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),

                // Course Name
                Text(
                  courseName,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 84,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    shadows: [
                      const Shadow(
                        color: Colors.black45,
                        offset: Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // Teacher Info
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accentGold, width: 4),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: teacherProfilePic.startsWith('http')
                            ? CachedNetworkImageProvider(teacherProfilePic)
                            : AssetImage(teacherProfilePic) as ImageProvider,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacherName,
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "LEARN WITH THE MASTER",
                          style: GoogleFonts.urbanist(
                            color: AppColors.accentGold,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 60),

                // Call to Action
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "JOIN ME ON CALLIGRO",
                      style: GoogleFonts.urbanist(
                        color: Colors.white70,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
