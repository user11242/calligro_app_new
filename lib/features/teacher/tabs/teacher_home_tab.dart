import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/teacher/pages/add_course/add_course_dashboard.dart';

class TeacherHomeTab extends StatefulWidget {
  final Function(int) onNavigate;

  const TeacherHomeTab({super.key, required this.onNavigate});

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> {
  int _courseCount = 0;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchCourseCount();
  }

  Future<void> _fetchCourseCount() async {
    if (user == null) {
      return;
    }

    try {
      final courseRef = FirebaseFirestore.instance.collection('courses');
      final query = courseRef.where('teacherId', isEqualTo: user!.uid);
      final aggregateQuery = await query.count().get();
      
      setState(() {
        _courseCount = aggregateQuery.count ?? 0;
      });
    } catch (e) {
      print("Error fetching course count: $e");
      setState(() {
        _courseCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color earningsColor = Color(0xFF6B4226); 

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Welcome back 👋",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Here’s your teaching overview",
          style: TextStyle(color: AppColors.secondary, fontSize: 16),
        ),
        const SizedBox(height: 20),

        // 📊 Circular Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () {
                widget.onNavigate(1);
              },
              child: _buildCircularStat("Courses", "$_courseCount", Icons.book, AppColors.textColor),
            ),
            _buildCircularStat("Students", "120", Icons.people, Colors.teal),
            _buildCircularStat("Earnings", "450", Icons.attach_money, earningsColor),
          ],
        ),
        const SizedBox(height: 20),

        // 🚀 Quick Actions
        const Text(
          "Quick Actions",
          style: TextStyle(color: AppColors.secondary, fontSize: 18),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddCourseDashboardPage()),
                );
              },
              child: _buildActionButton("Create Course", Icons.add_circle, AppColors.textColor),
            ),
            GestureDetector(
              onTap: () {
                widget.onNavigate(1);
              },
              child: _buildActionButton("My Students", Icons.people_alt, Colors.teal),
            ),
            _buildActionButton("Earnings", Icons.attach_money, earningsColor),
          ],
        ),
      ],
    );
  }

  static Widget _buildCircularStat(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static Widget _buildActionButton(String text, IconData icon, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}