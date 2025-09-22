import 'package:calligro_app/core/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/core/theme/colors.dart';

class TeacherCoursesTab extends StatefulWidget {
  const TeacherCoursesTab({super.key});

  @override
  _TeacherCoursesTabState createState() => _TeacherCoursesTabState();
}

class _TeacherCoursesTabState extends State<TeacherCoursesTab> {
  late String teacherId;

  @override
  void initState() {
    super.initState();
    // No need to fetch courses initially, StreamBuilder will handle that.
  }

  // Fetch the teacher's ID from Firebase Authentication
  Future<String> _getTeacherId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.uid;
    }
    return ''; // Return empty if user is not authenticated
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Courses'),
        backgroundColor: AppColors.primary,  // Set your primary color for AppBar
      ),
      body: Container(
        color: AppColors.primary,  // Set background color to primary color
        child: FutureBuilder<String>(
          future: _getTeacherId(), // Get the teacher ID from FirebaseAuth
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text("Error fetching teacher ID"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No teacher ID found"));
            }

            teacherId = snapshot.data!;

            // StreamBuilder to listen for changes in the 'courses' collection for this teacher
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .where('teacherId', isEqualTo: teacherId)
                  .snapshots(), // Listen for real-time updates
              builder: (context, courseSnapshot) {
                if (courseSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (courseSnapshot.hasError) {
                  return const Center(child: Text("Error fetching courses"));
                } else if (!courseSnapshot.hasData || courseSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No courses available"));
                }

                // Convert the snapshot data into a list of courses
                List<Map<String, dynamic>> courses = courseSnapshot.data!.docs.map((doc) {
                  return {
                    'courseName': doc['courseName'],
                    'studentsEnrolled': doc['enrolledStudents'], // Updated field name
                  };
                }).toList();

                // Display the courses dynamically
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16.0), // Space between cards
                      child: Card(
                        color: Colors.black54,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 5, // Add shadow for separation from background
                        child: ListTile(
                          leading: const Icon(Icons.menu_book, color: Colors.amber),
                          title: Text(
                            courses[index]['courseName'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "${courses[index]['studentsEnrolled']} students enrolled",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70),
                          onTap: () {
                            // 🔹 TODO: Open course details
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0), // Ensure it's not overlapping
        child: FloatingActionButton.extended(
          onPressed: () {
            // Navigate to the Add Course page
            Navigator.pushNamed(context, '/addCourse');
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Course'),
          backgroundColor: Colors.amber,
        ),
      ),
    );
  }
}
