import 'package:flutter/material.dart';

class StepStudentFinish extends StatelessWidget {
  const StepStudentFinish({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user, // Use a verified icon
            color: Colors.green, // Set icon color to green
            size: 60.0, // Set a suitable icon size
          ),
          SizedBox(height: 20), // Add some space between the icon and text
          Text(
            "Great! You’re all set.\nPress Finish to continue.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}