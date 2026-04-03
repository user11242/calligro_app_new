import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/features/student/student_dashboard.dart';
import 'package:calligro_app/features/teacher/teacher_dashboard.dart';
import 'package:calligro_app/features/admin/admin_dashboard.dart';
import 'package:calligro_app/features/auth/pages/login_page.dart';
import 'package:calligro_app/screens/auth_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _targetRoute;
  Map<String, dynamic>? _userData;
  bool _isInitialized = false;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    // Replaced direct call with didChangeDependencies to fix lifecycle error
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _initializeApp();
    }
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();
    
    // Determine duration based on first launch
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('has_seen_splash') ?? true;
    final minDurationMs = isFirstLaunch ? 4000 : 1800;
    
    if (isFirstLaunch) {
      await prefs.setBool('has_seen_splash', false);
    }

    if (mounted) {
      setState(() {
        _isFirstLaunch = true; // Always true so animation plays fully
      });
    }

    // 0. Pre-cache critical images
    precacheImage(const AssetImage('assets/images/app_icon.png'), context);

    try {
      // 1. Warm up Auth & Firestore
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final String role = data['role'] ?? 'student';
          final String status = data['status'] ?? 'approved';
          
          if (role == 'teacher' && status == 'approved') {
            _targetRoute = '/teacherDashboard';
          } else if (role == 'admin') {
            _targetRoute = '/adminDashboard';
          } else if (role == 'student') {
            _targetRoute = '/studentDashboard';
          } else {
            _targetRoute = '/';
          }
        } else {
          _targetRoute = '/';
        }
      } else {
        _targetRoute = '/';
      }
    } catch (e) {
      _targetRoute = '/';
    }

    // 2. Dynamic Delay based on launch count
    final remaining = Duration(milliseconds: minDurationMs) - stopwatch.elapsed;
    if (remaining.isNegative) {
      // Do nothing
    } else {
      await Future.delayed(remaining);
    }
    
    if (mounted) {
      // Navigate with a custom cross-fade or slide for "Creative" feel
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => _getNextPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  Widget _getNextPage() {
    if (_targetRoute == '/studentDashboard') return const StudentDashboardPage();
    if (_targetRoute == '/teacherDashboard') return const TeacherDashboardPage();
    if (_targetRoute == '/adminDashboard') return const AdminDashboardPage();
    if (_targetRoute == '/LoginPage') return const LoginPage();
    return const AuthWrapper(); // Fallback
  }

  @override
  Widget build(BuildContext context) {
    const Color brandDark = Color(0xFF1F1F1F);
    const Color goldColor = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: brandDark,
      body: Stack(
        children: [
          // 1. DEPTH BACKGROUND
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Color(0xFF1A1A1A),
                    brandDark,
                  ],
                ),
              ),
            ),
          ),

          // 2. THE REVEAL CONTENT
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO REVEAL
                Container(
                  width: 150,
                  height: 150,
                  clipBehavior: Clip.antiAlias, // ✅ Ensure clipping of square children
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: goldColor.withOpacity(0.1),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval( // ✅ Force square image into a perfect circle
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                )
                .animate() // Removed repeat(reverse: true) for performance
                .fadeIn(delay: 800.ms, duration: 1200.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 2000.ms, curve: Curves.easeOut),

                const SizedBox(height: 40),

                // NAME REVEAL with 'ZEN SPLIT' and 'WAVE' effect on "GRO"
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // The Brand Name
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.ltr,
                      children: [
                        Text(
                          "CALLI",
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 40,
                            fontWeight: FontWeight.w200,
                            color: goldColor,
                            letterSpacing: 12.0,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 800.ms),
                        
                        // Wave letters: G, R, O
                        ...["G", "R", "O"].asMap().entries.map((entry) {
                          int idx = entry.key;
                          String letter = entry.value;
                          return Text(
                            letter,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 40,
                              fontWeight: FontWeight.w200,
                              color: goldColor,
                              letterSpacing: 12.0,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: (600 + (idx * 100)).ms, duration: 800.ms)
                          .moveY(
                            begin: 0,
                            end: -10,
                            delay: (1500 + (idx * 150)).ms,
                            duration: 600.ms,
                            curve: Curves.easeInOut,
                          )
                          .then()
                          .moveY(
                            begin: 0,
                            end: 10,
                            duration: 600.ms,
                            curve: Curves.easeInOut,
                          );
                        }),
                      ],
                    )
                    .animate()
                    .shimmer(delay: 1500.ms, duration: 2.seconds, color: Colors.white.withOpacity(0.3)),

                    // Left Splitting Line
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 2,
                          height: 50,
                          color: goldColor,
                        )
                        .animate(onComplete: (controller) {
                          HapticFeedback.mediumImpact();
                        })
                        .scaleY(begin: 0, end: 1, duration: 400.ms)
                        .then()
                        .moveX(begin: 0, end: -150, duration: 1000.ms, curve: Curves.easeOutQuart)
                        .fadeOut(duration: 400.ms),
                      ),
                    ),

                    // Right Splitting Line
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 2,
                          height: 50,
                          color: goldColor,
                        )
                        .animate()
                        .scaleY(begin: 0, end: 1, duration: 400.ms)
                        .then()
                        .moveX(begin: 0, end: 150, duration: 1000.ms, curve: Curves.easeOutQuart)
                        .fadeOut(duration: 400.ms),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // TAGLINE
                Text(
                  "MASTER THE ART",
                  style: GoogleFonts.montserrat(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 8,
                  ),
                )
                .animate()
                .fadeIn(delay: 1600.ms, duration: 1000.ms)
                .blur(begin: const Offset(10, 10), end: Offset.zero, duration: 1500.ms),
              ],
            ),
          ),

          // 3. MINIMALIST PROGRESS
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 60,
                height: 1,
                color: goldColor.withOpacity(0.1),
              )
              .animate()
              .fadeIn(delay: 1000.ms)
              .scaleX(begin: 0, end: 1, duration: 2000.ms, curve: Curves.easeInOut),
            ),
          ),
        ],
      ),
    );
  }
}