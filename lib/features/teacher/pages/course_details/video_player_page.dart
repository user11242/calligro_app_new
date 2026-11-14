import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:calligro_app/core/services/security_service.dart';
import 'package:calligro_app/core/theme/colors.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  final Map<String, String>? qualities;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.title,
    this.qualities,
  });

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
  double _currentSpeed = 1.0;
  String _selectedQuality = 'Auto';
  bool _isSwitchingQuality = false;

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

    if (mounted) setState(() {});

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

  void _setPlaybackRate(double rate) {
    _mainPlayer?.setRate(rate);
    setState(() {
      _currentSpeed = rate;
    });
  }

  Future<void> _changeQuality(String quality) async {
    if (_selectedQuality == quality) return;
    
    final player = _mainPlayer;
    if (player == null) return;
    
    final currentPos = player.state.position;
    final wasPlaying = player.state.playing;

    setState(() {
      _selectedQuality = quality;
      _isSwitchingQuality = true;
    });

    try {
      // Determine the target URL from available qualities or fallback to original
      String targetUrl = widget.videoUrl;
      if (widget.qualities != null && widget.qualities!.isNotEmpty) {
        if (quality == 'Auto' || quality == '1080p') {
          targetUrl = widget.qualities!['1080p'] ?? widget.videoUrl;
        } else if (widget.qualities!.containsKey(quality)) {
          targetUrl = widget.qualities![quality]!;
        }
      }

      if (!targetUrl.startsWith('http')) {
        targetUrl = 'https://$targetUrl';
      }

      // Optional low-level decoding optimization for lower qualities
      try {
        final dynamic platform = player.platform;
        if (platform != null) {
          if (quality == '360p' || quality == '480p') {
            await platform.setProperty('vd-lavc-fast', 'yes');
          } else {
            await platform.setProperty('vd-lavc-fast', 'no');
          }
        }
      } catch (_) {}

      // Open media and resume smoothly at the current timestamp
      await player.open(
        Media(targetUrl, start: currentPos),
        play: wasPlaying,
      );

      // Restore playback rate
      if (_currentSpeed != 1.0) {
        await player.setRate(_currentSpeed);
      }
    } catch (e) {
      debugPrint("Error switching quality: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingQuality = false;
        });
      }
    }
  }

  void _seekRelative(Duration delta) {
    final player = _isPlayingIntro ? _introPlayer : _mainPlayer;
    if (player == null) return;
    final current = player.state.position;
    final total = player.state.duration;
    final target = current + delta;
    if (target < Duration.zero) {
      player.seek(Duration.zero);
    } else if (total > Duration.zero && target > total) {
      player.seek(total);
    } else {
      player.seek(target);
    }
  }

  MaterialVideoControlsThemeData _buildNormalTheme(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = math.max(mediaQuery.padding.bottom, 16.0);
    final topPadding = mediaQuery.padding.top + kToolbarHeight;
    final horizontalPadding = math.max(mediaQuery.padding.left, mediaQuery.padding.right) + 12.0;

    return MaterialVideoControlsThemeData(
      // Colors & appearance
      seekBarColor: Colors.white.withValues(alpha: 0.25),
      seekBarPositionColor: AppColors.accentGold,
      seekBarBufferColor: Colors.white.withValues(alpha: 0.45),
      seekBarThumbColor: AppColors.accentGold,
      seekBarHeight: 4.5,
      seekBarThumbSize: 15.0,
      seekBarContainerHeight: 44.0,
      seekBarAlignment: Alignment.bottomCenter,

      // Spacing & safe areas
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: bottomPadding + 14.0,
        top: topPadding + 8.0,
      ),
      bottomButtonBarMargin: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 0.0),
      seekBarMargin: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 48.0),
      buttonBarHeight: 44.0,
      buttonBarButtonSize: 24.0,
      buttonBarButtonColor: Colors.white,

      // Gestures
      seekOnDoubleTap: true,
      seekOnDoubleTapBackwardDuration: const Duration(seconds: 10),
      seekOnDoubleTapForwardDuration: const Duration(seconds: 10),
      seekOnDoubleTapEnabledWhileControlsVisible: true,
      speedUpOnLongPress: true,
      speedUpFactor: 2.0,
      gesturesEnabledWhileControlsVisible: true,

      // Center Controls: -10s, Play/Pause, +10s
      primaryButtonBar: [
        const Spacer(flex: 3),
        MaterialCustomButton(
          iconSize: 42,
          iconColor: Colors.white,
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 42),
          onPressed: () => _seekRelative(const Duration(seconds: -10)),
        ),
        const Spacer(flex: 2),
        const MaterialPlayOrPauseButton(iconSize: 64.0, iconColor: Colors.white),
        const Spacer(flex: 2),
        MaterialCustomButton(
          iconSize: 42,
          iconColor: Colors.white,
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 42),
          onPressed: () => _seekRelative(const Duration(seconds: 10)),
        ),
        const Spacer(flex: 3),
      ],

      // Bottom Bar: Duration / Position, Quality Selector, Speed Selector, Fullscreen
      bottomButtonBar: [
        const MaterialPositionIndicator(
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        _QualitySelectorButton(
          currentQuality: _selectedQuality,
          onQualityChanged: _changeQuality,
          availableQualities: widget.qualities,
        ),
        const SizedBox(width: 8),
        _PlaybackSpeedButton(
          currentSpeed: _currentSpeed,
          onSpeedChanged: _setPlaybackRate,
        ),
        const SizedBox(width: 8),
        const MaterialFullscreenButton(
          iconSize: 24,
          iconColor: Colors.white,
        ),
      ],
    );
  }

  MaterialVideoControlsThemeData _buildFullscreenTheme(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = math.max(mediaQuery.padding.bottom, 12.0);
    final horizontalPadding = math.max(mediaQuery.padding.left, mediaQuery.padding.right) + 16.0;

    return MaterialVideoControlsThemeData(
      // Colors & appearance
      seekBarColor: Colors.white.withValues(alpha: 0.25),
      seekBarPositionColor: AppColors.accentGold,
      seekBarBufferColor: Colors.white.withValues(alpha: 0.45),
      seekBarThumbColor: AppColors.accentGold,
      seekBarHeight: 4.5,
      seekBarThumbSize: 15.0,
      seekBarContainerHeight: 44.0,
      seekBarAlignment: Alignment.bottomCenter,

      // Spacing & safe areas
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: bottomPadding + 10.0,
        top: mediaQuery.padding.top + 10.0,
      ),
      bottomButtonBarMargin: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 0.0),
      seekBarMargin: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 48.0),
      buttonBarHeight: 44.0,
      buttonBarButtonSize: 26.0,
      buttonBarButtonColor: Colors.white,

      // Gestures
      seekOnDoubleTap: true,
      seekOnDoubleTapBackwardDuration: const Duration(seconds: 10),
      seekOnDoubleTapForwardDuration: const Duration(seconds: 10),
      seekOnDoubleTapEnabledWhileControlsVisible: true,
      speedUpOnLongPress: true,
      speedUpFactor: 2.0,
      gesturesEnabledWhileControlsVisible: true,

      // Center Controls: -10s, Play/Pause, +10s
      primaryButtonBar: [
        const Spacer(flex: 3),
        MaterialCustomButton(
          iconSize: 48,
          iconColor: Colors.white,
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 48),
          onPressed: () => _seekRelative(const Duration(seconds: -10)),
        ),
        const Spacer(flex: 2),
        const MaterialPlayOrPauseButton(iconSize: 72.0, iconColor: Colors.white),
        const Spacer(flex: 2),
        MaterialCustomButton(
          iconSize: 48,
          iconColor: Colors.white,
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 48),
          onPressed: () => _seekRelative(const Duration(seconds: 10)),
        ),
        const Spacer(flex: 3),
      ],

      // Bottom Bar: Duration / Position, Quality Selector, Speed Selector, Fullscreen
      bottomButtonBar: [
        const MaterialPositionIndicator(
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        _QualitySelectorButton(
          currentQuality: _selectedQuality,
          onQualityChanged: _changeQuality,
          availableQualities: widget.qualities,
        ),
        const SizedBox(width: 8),
        _PlaybackSpeedButton(
          currentSpeed: _currentSpeed,
          onSpeedChanged: _setPlaybackRate,
        ),
        const SizedBox(width: 8),
        const MaterialFullscreenButton(
          iconSize: 26,
          iconColor: Colors.white,
        ),
      ],
    );
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
        actions: [
          if (!_isPlayingIntro) ...[
            Center(
              child: _QualitySelectorButton(
                currentQuality: _selectedQuality,
                onQualityChanged: _changeQuality,
                availableQualities: widget.qualities,
              ),
            ),
            const SizedBox(width: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _PlaybackSpeedButton(
                  currentSpeed: _currentSpeed,
                  onSpeedChanged: _setPlaybackRate,
                ),
              ),
            ),
          ],
        ],
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
                ? MaterialVideoControlsTheme(
                    normal: _buildNormalTheme(context),
                    fullscreen: _buildFullscreenTheme(context),
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Video(
                        controller: currentController,
                        controls: _isPlayingIntro ? NoVideoControls : MaterialVideoControls,
                      ),
                    ),
                  )
                : const CircularProgressIndicator(color: AppColors.accentGold),
          ),

          // ── Quality Switching HUD Overlay ──
          if (_isSwitchingQuality)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2026).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '$_selectedQuality...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QualitySelectorButton extends StatelessWidget {
  final String currentQuality;
  final ValueChanged<String> onQualityChanged;
  final Map<String, String>? availableQualities;

  const _QualitySelectorButton({
    required this.currentQuality,
    required this.onQualityChanged,
    this.availableQualities,
  });

  void _showQualitySheet(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final options = [
      {
        'id': 'Auto',
        'title': isArabic ? 'تلقائي (Auto)' : 'Auto',
        'desc': isArabic ? 'اختيار أفضل دقة حسب سرعة اتصالك' : 'Optimized for current connection',
        'tag': 'Adaptive',
      },
      {
        'id': '1080p',
        'title': isArabic ? '1080p (Full HD)' : '1080p (Full HD)',
        'desc': isArabic ? 'فائق الدقة • رؤية واضحة لحركات القلم' : 'Highest sharpness for calligraphy details',
        'tag': 'Best',
      },
      {
        'id': '720p',
        'title': isArabic ? '720p (HD)' : '720p (HD)',
        'desc': isArabic ? 'عالي الدقة • توازن ممتاز بين الجودة والسرعة' : 'High definition with smooth playback',
        'tag': 'HD',
      },
      {
        'id': '480p',
        'title': isArabic ? '480p (SD)' : '480p (SD)',
        'desc': isArabic ? 'دقة عادية • تقليل التقطيع وتسريع التحميل' : 'Standard definition, less buffering',
        'tag': 'SD',
      },
      {
        'id': '360p',
        'title': isArabic ? '360p (توفير البيانات)' : '360p (Data Saver)',
        'desc': isArabic ? 'أقل استهلاك للبيانات • للشبكات الضعيفة' : 'Lowest data usage for weak networks',
        'tag': 'Saver',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2026),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppColors.accentGold, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isArabic ? 'جودة الفيديو' : 'Video Quality',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),
                ...options.map((opt) {
                  final id = opt['id']!;
                  final isSelected = (currentQuality == id);

                  return ListTile(
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.accentGold.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.accentGold : Colors.white12,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        opt['tag']!,
                        style: TextStyle(
                          color: isSelected ? AppColors.accentGold : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      opt['title']!,
                      style: TextStyle(
                        color: isSelected ? AppColors.accentGold : Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      opt['desc']!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 22)
                        : null,
                    onTap: () {
                      onQualityChanged(id);
                      Navigator.pop(sheetContext);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnContext) {
        return InkWell(
          onTap: () => _showQualitySheet(btnContext),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 14,
                  color: AppColors.accentGold,
                ),
                const SizedBox(width: 4),
                Text(
                  currentQuality,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlaybackSpeedButton extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const _PlaybackSpeedButton({
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  void _showSpeedSheet(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2026),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.speed_rounded, color: AppColors.accentGold, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isArabic ? 'سرعة التشغيل' : 'Playback Speed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),
                ...speeds.map((speed) {
                  final isSelected = (currentSpeed == speed);
                  return ListTile(
                    dense: true,
                    title: Text(
                      speed == 1.0 
                          ? (isArabic ? '1.0x (عادي)' : '1.0x (Normal)') 
                          : '${speed}x',
                      style: TextStyle(
                        color: isSelected ? AppColors.accentGold : Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppColors.accentGold, size: 20)
                        : null,
                    onTap: () {
                      onSpeedChanged(speed);
                      Navigator.pop(sheetContext);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnContext) {
        return InkWell(
          onTap: () => _showSpeedSheet(btnContext),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.speed_rounded,
                  size: 14,
                  color: AppColors.accentGold,
                ),
                const SizedBox(width: 4),
                Text(
                  '${currentSpeed == 1.0 ? "1.0" : currentSpeed.toString()}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
