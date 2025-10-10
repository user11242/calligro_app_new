import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../features/teacher/tabs/teacher_home_tab.dart';
import '../../features/teacher/tabs/teacher_courses_tab.dart';
import '../../features/teacher/tabs/teacher_profile_tab.dart';
import '../../features/community/community_page.dart'; // 1. IMPORT THE COMMUNITY PAGE

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  // Define the pages list inside the build method
  // to pass the required onNavigate function to the home tab.
  List<Widget> get _pages {
    return [
      TeacherHomeTab(onNavigate: _onNavTap),
      const TeacherCoursesTab(),
      const TeacherProfileTab(),
      const CommunityPage(), // 2. ADD COMMUNITY PAGE TO THE LIST
    ];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 🚫 disable back button
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            "Teacher Dashboard",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                // TODO: Show notifications page or logic
              }
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _pages[_selectedIndex],
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onNavTap,
            backgroundColor: Colors.black87, // Returned to original black87
            selectedItemColor: Colors.amber,
            unselectedItemColor: Colors.white70,
            items: [
              BottomNavigationBarItem(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedIndex == 0
                      ? const Icon(Icons.home, key: ValueKey('home'))
                      : const Icon(Icons.home_outlined, key: ValueKey('home_outlined')),
                ),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedIndex == 1
                      ? const Icon(Icons.book, key: ValueKey('courses'))
                      : const Icon(Icons.book_outlined, key: ValueKey('courses_outlined')),
                ),
                label: "Courses",
              ),
              BottomNavigationBarItem(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedIndex == 2
                      ? const Icon(Icons.person, key: ValueKey('profile'))
                      : const Icon(Icons.person_outline, key: ValueKey('profile_outlined')),
                ),
                label: "Profile",
              ),
              // 3. ADD THE COMMUNITY TAB
              BottomNavigationBarItem(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedIndex == 3
                      ? const Icon(Icons.people_alt, key: ValueKey('community'))
                      : const Icon(Icons.people_alt_outlined, key: ValueKey('community_outlined')),
                ),
                label: "Community",
              ),
            ],
          ),
        ),
      ),
    );
  }
}