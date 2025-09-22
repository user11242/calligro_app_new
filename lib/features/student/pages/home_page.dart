import 'package:calligro_app/features/student/widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import 'package:calligro_app/features/student/widgets/app_bar.dart';
import 'package:calligro_app/features/student/widgets/custom_drawer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: Appbar(),
      drawer: CustomDrawer(),
      body: Stack(
        children: [
          const Background(),
          const Header(),

          // ✅ Floating bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomBottomNavBar(
              currentIndex: 0,
              onTap: (index) {
                // TODO: Handle navigation
              },
            ),
          ),
        ],
      ),
    );
  }
}

class Background extends StatelessWidget {
  const Background({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            "assets/backgrounds/main_background.jpg",
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.7), // dark overlay
          ),
        ),
      ],
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 150, left: 30),
      child: const Text(
        "A journey that begins from the first point",
        style: TextStyle(
          color: AppColors.textColor,
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
