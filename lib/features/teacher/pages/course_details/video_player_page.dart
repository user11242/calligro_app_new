import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:calligro_app/core/services/security_service.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/utils/video_asset_helper.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerPage({Key? key, required this.videoUrl, required this.title}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  Player? _introPlayer;
  VideoController? _introController;
  
  Player? _mainPlayer;
  VideoController? _mainController;
  
  StreamSubscription? _introCompleteSubscription;
  
  bool _isPlayingIntro = true;

  @override
  void initState() {
    super.initState();
    SecurityService().enableScreenshotProtection();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    initializePlayer();
  }

  Future<void> initializePlayer() async {
    // 1. Initialize Intro Video
    _introPlayer = Player();
    _introController = VideoController(_introPlayer!);
    await _introPlayer!.open(Media('asset://assets/videos/recordings_intro.mov'), play: false);

    // 2. Initialize Main Video
    String finalUrl = widget.videoUrl;
    if (!finalUrl.startsWith('http')) {
      finalUrl = 'https://$finalUrl';
    }
    _mainPlayer = Player();
    _mainController = VideoController(_mainPlayer!);
    await _mainPlayer!.open(Media(finalUrl), play: false);

    setState(() {});

    // 3. Listen for intro completion
    _introCompleteSubscription = _introPlayer!.stream.completed.listen((completed) {
      if (completed) {
        _switchToMainVideo();
      }
    });
    
    // Play intro
    await _introPlayer!.play();
  }

  void _switchToMainVideo() {
    if (!mounted) return;
    
    _introCompleteSubscription?.cancel();
    
    setState(() {
      _isPlayingIntro = false;
    });
    
    _mainPlayer?.play();
  }

  @override
  void dispose() {
    SecurityService().disableScreenshotProtection();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _introCompleteSubscription?.cancel();
    _introPlayer?.dispose();
    _mainPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentController = _isPlayingIntro ? _introController : _mainController;
    
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        title: Text(
          widget.title, 
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred Video Background ──
          if (currentController != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 1920,
                height: 1080,
                child: Video(
                  controller: currentController,
                  controls: NoVideoControls,
                ),
              ),
            ),
            
          // ── Heavy Blur Filter Overlay ──
          if (currentController != null)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),

          // ── Main Video Player ──
          Center(
            child: currentController != null
                ? InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Video(
                      controller: currentController,
                      controls: _isPlayingIntro ? NoVideoControls : AdaptiveVideoControls,
                    ),
                  )
                : const CircularProgressIndicator(color: AppColors.accentGold),
          ),
        ],
      ),
    );
  }
}
