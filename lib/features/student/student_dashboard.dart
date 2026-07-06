import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/student/pages/student_home_page.dart';
import 'package:calligro_app/features/community/pages/community_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/features/student/tabs/student_courses_tab.dart';
import 'package:calligro_app/features/student/tabs/student_profile_tab.dart';

class StudentDashboardPage extends StatefulWidget {
  final bool isGuestMode;

  const StudentDashboardPage({super.key, this.isGuestMode = false});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  int _selectedIndex = 0;
  String? _initialCourseFilter;
  final int _navigationTrigger = 0;

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
      ),

      // 3. Community Tab
      CommunityPage(onProfileTap: _handleCommunityProfileTap),

      // 4. Profile Tab
      const StudentProfileTab(),
    ];

    return Scaffold(
        backgroundColor: AppColors.primary,
        body: IndexedStack(index: _selectedIndex, children: pages),
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
