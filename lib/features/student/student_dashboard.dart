import 'package:calligro_app/features/community/presentation/community_scope.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/student/pages/student_home_page.dart';
import 'package:calligro_app/features/community/presentation/pages/community_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/features/student/tabs/student_courses_tab.dart';
import 'package:calligro_app/features/student/tabs/student_profile_tab.dart';
import 'package:calligro_app/features/student/data/services/student_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentDashboardPage extends StatefulWidget {
  final bool isGuestMode;
  final StudentService? studentService;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const StudentDashboardPage({
    super.key, 
    this.isGuestMode = false,
    this.studentService,
    this.auth,
    this.firestore,
  });

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  /// Community screens use the same (injectable) Firestore/Auth as the dashboard.
  late final CommunityServices _communityServices =
      CommunityServices.firebase(firestore: widget.firestore, auth: widget.auth);

  int _selectedIndex = 0;
  String? _initialCourseFilter;
  final int _navigationTrigger = 0;

  Future<void> _openSupportWhatsApp() async {
    final Uri whatsappUri = Uri.parse("https://wa.me/15645446119");
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(whatsappUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint("Error opening WhatsApp support: $e");
    }
  }

  void _handleCommunityProfileTap(String userId, String userRole) {
    setState(() {
      _selectedIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // 1. Home Tab (Safe ✅)
      StudentHomePage(
        isGuestMode: widget.isGuestMode,
        studentService: widget.studentService,
        auth: widget.auth,
        firestore: widget.firestore,
        onGoToCourses: (String? filter) {
          setState(() {
            _initialCourseFilter = filter;
            _selectedIndex = 1;
          });
        },
        onProfileTap: () {
          setState(() {
            _selectedIndex = 3;
          });
        },
      ),

      // 2. Courses Tab
      StudentCoursesTab(
        initialFilter: _initialCourseFilter,
        navigationTrigger: _navigationTrigger,
        auth: widget.auth,
        firestore: widget.firestore,
      ),

      // 3. Community Tab
      CommunityPage(
        onProfileTap: _handleCommunityProfileTap,
      ),

      // 4. Profile Tab
      StudentProfileTab(
        auth: widget.auth,
        firestore: widget.firestore,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          CommunityScope(
            services: _communityServices,
            child: IndexedStack(index: _selectedIndex, children: pages),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGold.withOpacity(0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: AppColors.accentGold,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openSupportWhatsApp,
                  child: const SizedBox(
                    width: 54,
                    height: 54,
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: Colors.black,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.cardBackground,
        height: 70,
        padding: EdgeInsets.zero,
        child: SafeArea(
          bottom: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                  0, Icons.home_outlined, Icons.home, AppLocalizations.of(context)!.home),
              _buildNavItem(
                1,
                Icons.menu_book_outlined,
                Icons.menu_book,
                AppLocalizations.of(context)!.courses,
              ),
              _buildNavItem(
                  2, Icons.people_outline, Icons.people, AppLocalizations.of(context)!.community),
              _buildCentralNavItem(
                3,
                Icons.person_outline,
                Icons.person,
                AppLocalizations.of(context)!.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Nav Item Helpers ---
  Widget _buildNavItem(
    int index,
    IconData unselected,
    IconData selected,
    String label,
  ) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selected : unselected,
              color: isSelected ? AppColors.accentGold : AppColors.textLight,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accentGold : AppColors.textLight,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCentralNavItem(
    int index,
    IconData unselected,
    IconData selected,
    String label,
  ) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.accentGold : Colors.transparent,
              ),
              child: Icon(
                isSelected ? selected : unselected,
                color: isSelected ? AppColors.primary : AppColors.textLight,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accentGold : AppColors.textLight,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
