import 'package:flutter/material.dart';

class StepTeacherPortfolio extends StatelessWidget {
  final TextEditingController controller;
  const StepTeacherPortfolio({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Portfolio Link",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Portfolio Link (Instagram, Behance, etc.)",
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.link, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white), // Text color set to white
        ),
      ],
    );
  }
}
