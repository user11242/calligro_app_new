// lib/features/teacher/pages/teacher_dashboard_page.dart
//Done

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../l10n/app_localizations.dart';
// Import the separated TeacherHomeTab
import '../../features/teacher/tabs/teacher_home_tab.dart'; // <--- Corrected Import
import '../../features/teacher/tabs/teacher_courses_tab.dart';
import '../../features/teacher/tabs/teacher_profile_tab.dart'; // <--- Assuming this is a separate file
import '../community/pages/community_page.dart';
import 'pages/setup/teacher_setup_page.dart';
import '../../core/message/app_messenger.dart';

// --- MAIN TEACHER DASHBOARD PAGE ---

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  int _selectedIndex = 0;

  String _userName = "Teacher";
  String _userEmail = "Loading...";
  String _userProfileImage =
      'https://via.placeholder.com/150/FFD700/FFFFFF?text=T';
  int _courseCount = 0;
  String _studentCount = "0";
  String _earnings = "£0";
  bool _isLoading = true;
  bool _needsProfileSetup = false;
  bool _hasPayoutInfo = true; // Default to true to avoid flicker
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _initializePages(); // Initialize with defaults first
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("No user logged in, cannot fetch data.");
      return;
    }

    try {
      Future<DocumentSnapshot> userDocFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      Future<QuerySnapshot> coursesQueryFuture = FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: user.uid)
          .get();

      Future<QuerySnapshot> txQueryFuture = FirebaseFirestore.instance
          .collection('transactions')
          .where('teacherId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      final List<dynamic> results = await Future.wait([
        userDocFuture,
        coursesQueryFuture,
        txQueryFuture,
      ]);

      if (!mounted) return;

      final DocumentSnapshot userDoc = results[0] as DocumentSnapshot;
      String fetchedName = "Teacher";
      String fetchedEmail = "No Email";
      String fetchedPhotoUrl = "";

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;

        if (data != null) {
          fetchedName = data['name'] ?? "Teacher";
          fetchedEmail = data['email'] ?? "No Email";
          fetchedPhotoUrl = data['photoUrl'] ?? "";
        }
      }

      final QuerySnapshot coursesQuery = results[1] as QuerySnapshot;
      final int fetchedCourseCount = coursesQuery.size;

      int totalStudents = 0;
      for (var doc in coursesQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['enrolledStudents'] is List) {
          totalStudents += (data['enrolledStudents'] as List).length;
        } else {
          totalStudents += (data['studentsEnrolled'] as int? ?? 0);
        }
      }

      final QuerySnapshot txQuery = results[2] as QuerySnapshot;

      setState(() {
        _userName = fetchedName;
        _userEmail = fetchedEmail;
        _courseCount = fetchedCourseCount;
        _studentCount = totalStudents.toString();
        
        // Calculate earnings from transactions ledger
        double totalEarnings = 0.0;
        for (var doc in txQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final double share = (data['teacherShare'] ?? 0.0).toDouble();
          totalEarnings += share;
        }
        _earnings = "\$${totalEarnings.toStringAsFixed(0)}";

        if (fetchedPhotoUrl.isNotEmpty) {
          _userProfileImage = fetchedPhotoUrl;
        } else {
           // 🚨 Force Setup if photo is empty
           _needsProfileSetup = true;
        }

        // Check for payout info
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          _hasPayoutInfo = data != null && data.containsKey('payoutSettings');
        }

        _isLoading = false;
        _initializePages(); // Update with fetched data
      });
    } catch (e) {
      if (mounted) {
        debugPrint("Error fetching user data or courses: $e");
        setState(() {
          _isLoading = false;
          _initializePages(); // Ensure pages exist even on error
        });
      }
    }
  }

  void _onNavTap(int index, {String? successMessage}) {
    setState(() => _selectedIndex = index);
    if (successMessage != null) {
       print("DEBUG: Showing success message: $successMessage");
       Future.microtask(() {
          if (mounted) {
             AppMessenger.showSnackBar(
               context,
               title: AppLocalizations.of(context)!.success,
               message: successMessage,
               type: MessengerType.success,
             );
          }
       });
    }
  }

  // Handle profile tap specifically from CommunityPage
  void _handleCommunityProfileTap(String userId, String userRole) {
    _onNavTap(3); // Navigate to Profile tab (index 3)
  }

  void _initializePages() {
    _pages = [
      TeacherHomeTab(
        onNavigate: _onNavTap,
        userName: _userName,
        userProfileImage: _userProfileImage,
        courseCount: _courseCount,
        earnings: _earnings,
        hasPayoutInfo: _hasPayoutInfo,
        onRefresh: _fetchUserData,
      ),
      const TeacherCoursesTab(),
      CommunityPage(onProfileTap: _handleCommunityProfileTap),
      TeacherProfileTab(
        userName: _userName,
        userEmail: _userEmail,
        userProfileImage: _userProfileImage,
        courseCount: _courseCount.toString(),
        studentCount: _studentCount,
        earnings: _earnings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(
         backgroundColor: AppColors.primary,
         body: Center(child: CircularProgressIndicator(color: AppColors.secondary)),
       );
    }

    // 🔒 Block Access if no profile picture
    if (_needsProfileSetup) {
      return const TeacherSetupPage();
    }

    return Scaffold(
        backgroundColor: AppColors.primary,
        appBar: null,
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: BottomAppBar(
          color: AppColors.cardBackground,
          elevation: 0,
          child: SafeArea(
            bottom: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home,
                    AppLocalizations.of(context)!.home),
                _buildNavItem(1, Icons.book_outlined, Icons.book,
                    AppLocalizations.of(context)!.courses),
                _buildNavItem(
                  2,
                  Icons.people_alt_outlined,
                  Icons.people_alt,
                  AppLocalizations.of(context)!.community,
                ),
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

  Widget _buildNavItem(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
  ) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  _selectedIndex == index ? selectedIcon : unselectedIcon,
                  key: ValueKey(label),
                  color: _selectedIndex == index
                      ? AppColors.accentGold
                      : AppColors.textLight,
                  size: _selectedIndex == index ? 26 : 24,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: _selectedIndex == index
                      ? AppColors.accentGold
                      : AppColors.textLight,
                  fontSize: 11,
                  fontWeight: _selectedIndex == index
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCentralNavItem(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
  ) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavTap(index),
          borderRadius: BorderRadius.circular(50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.accentGold : Colors.transparent,
                ),
                child: Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  color: isSelected ? AppColors.primary : AppColors.textLight,
                  size: 24,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.accentGold
                      : AppColors.textLight,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
