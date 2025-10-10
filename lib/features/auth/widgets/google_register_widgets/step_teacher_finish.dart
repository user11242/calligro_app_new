import 'package:flutter/material.dart';

class StepTeacherFinish extends StatelessWidget {
  const StepTeacherFinish({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,  // Verified icon
            color: Colors.green,  // Green color for the icon
            size: 50,  // Icon size
          ),
          SizedBox(height: 20),
          Text(
            "Your registration has been submitted for approval.\nYou’ll be notified once it’s approved.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
