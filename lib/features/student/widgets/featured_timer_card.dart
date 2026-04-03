import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';

class FeaturedTimerCard extends StatelessWidget {
  final bool isGuest;

  const FeaturedTimerCard({super.key, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    // Logic: Session starts in 25 minutes
    DateTime startTime = DateTime.now().add(const Duration(minutes: 25));

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentGold.withOpacity(0.35),
              Colors.white.withOpacity(0.06),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Next Session",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Mastering Thuluth",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  "Sheikh Ahmad Al-Den",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // --- TIMER STREAM ---
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, _) {
                Duration diff = startTime.difference(DateTime.now());
                if (diff.isNegative) diff = Duration.zero;
                String two(int n) => n.toString().padLeft(2, "0");
                return Row(
                  children: [
                    _timerBox(two(diff.inHours)),
                    const SizedBox(width: 6),
                    _timerBox(two(diff.inMinutes % 60)),
                    const SizedBox(width: 6),
                    _timerBox(two(diff.inSeconds % 60)),
                  ],
                );
              },
            ),

            const SizedBox(height: 22),

            // --- ACTION BUTTON ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (isGuest) {
                    Navigator.pushNamed(context, '/LoginPage');
                  } else {
                    // TODO: Join Logic
                    print("Joining Class...");
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isGuest ? "Login to Join" : "Join Class",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timerBox(String value) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(value),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
