import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RecordedExplanationStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const RecordedExplanationStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<RecordedExplanationStep> createState() => _RecordedExplanationStepState();
}

class _RecordedExplanationStepState extends State<RecordedExplanationStep> {
  Player? _player;
  VideoController? _controller;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _player = Player();
    _controller = VideoController(_player!);
    // Play the existing explainer video and loop it
    _player!.setPlaylistMode(PlaylistMode.loop);
    await _player!.open(Media('asset://assets/videos/recordings_intro.mov'));
    setState(() {});
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "How Recorded Courses Work",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),
          
          const SizedBox(height: 12),
          
          const Text(
            "Watch this quick animation to understand how to structure your course.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2, end: 0),
          
          const SizedBox(height: 40),

          const SizedBox(height: 30),

          // --- Video Player ---
          if (_controller != null)
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGold.withOpacity(0.5), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Video(
                  controller: _controller!,
                  controls: AdaptiveVideoControls, // Shows play/pause/timeline
                ),
              ),
            )
          else
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              ),
            ),
          
          const SizedBox(height: 50),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Got it, Next',
                    style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

