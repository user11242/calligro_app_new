import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:calligro_app/core/services/security_service.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerPage({Key? key, required this.videoUrl, required this.title}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    SecurityService().enableScreenshotProtection();
    // Allow device rotation while watching the video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    initializePlayer();
  }

  Future<void> initializePlayer() async {
    // Add https:// if it is missing
    String finalUrl = widget.videoUrl;
    if (!finalUrl.startsWith('http')) {
      finalUrl = 'https://$finalUrl';
    }

    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(finalUrl));

    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      allowFullScreen: true,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.accentGold,
        handleColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        bufferedColor: Colors.white.withValues(alpha: 0.5),
      ),
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: AppColors.accentGold,
        handleColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        bufferedColor: Colors.white.withValues(alpha: 0.5),
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
    setState(() {});
  }

  @override
  void dispose() {
    SecurityService().disableScreenshotProtection();
    // Restore orientation lock to portrait when leaving the player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
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
          if (_videoPlayerController.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoPlayerController.value.size.width,
                height: _videoPlayerController.value.size.height,
                child: VideoPlayer(_videoPlayerController),
              ),
            ),
            
          // ── Heavy Blur Filter Overlay ──
          if (_videoPlayerController.value.isInitialized)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),

          // ── Main Video Player ──
          Center(
            child: _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
                ? InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Chewie(controller: _chewieController!),
                  )
                : const CircularProgressIndicator(color: AppColors.accentGold),
          ),
        ],
      ),
    );
  }
}
