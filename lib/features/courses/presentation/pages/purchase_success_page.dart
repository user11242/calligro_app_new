import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/teacher/pages/course_details/course_details_page.dart';

class PurchaseSuccessPage extends StatelessWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const PurchaseSuccessPage({
    super.key,
    required this.courseId,
    required this.courseData,
  });

  @override
  Widget build(BuildContext context) {
    final String courseName = courseData['courseName'] ?? 'Untitled Course';
    final String bannerUrl = courseData['courseBanner'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // 🌌 Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: _buildAmbientGlow(AppColors.accentGold.withOpacity(0.15)),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: _buildAmbientGlow(Colors.green.withOpacity(0.1)),
          ),

          // 🎊 Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // 🎉 Success Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentGold.withOpacity(0.1),
                      border: Border.all(color: AppColors.accentGold.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.accentGold,
                      size: 80,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 💎 Title
                  const Text(
                    "Payment Successful!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Welcome to the Calligro Academy!",
                    style: TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // 🖼️ Course Card (Glassmorphism)
                  _buildGlassCard(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: (bannerUrl.isEmpty)
                                ? Container(color: Colors.white10, child: const Icon(Icons.image, color: Colors.white24))
                                : bannerUrl.startsWith('assets') 
                                    ? Image.asset(bannerUrl, fit: BoxFit.cover)
                                    : Image.network(
                                        bannerUrl, 
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.white10),
                                      ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courseName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Unlock your potential",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 🚀 Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CourseDetailsPage(
                              courseId: courseId,
                              courseData: courseData,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 10,
                        shadowColor: AppColors.accentGold.withOpacity(0.4),
                      ),
                      child: const Text(
                        "START LEARNING NOW",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  
                   const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlow(Color color) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
