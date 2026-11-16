part of 'student_home_page.dart';

class AmbientVideoPlayer extends StatefulWidget {
  final String videoPath;
  const AmbientVideoPlayer({super.key, required this.videoPath});

  @override
  State<AmbientVideoPlayer> createState() => _AmbientVideoPlayerState();
}

class _AmbientVideoPlayerState extends State<AmbientVideoPlayer> {
  Player? _player;
  VideoController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;

    if (_player != null) {
      await _player!.dispose();
      _player = null;
      _controller = null;
    }

    if (mounted) {
      setState(() {
        _hasError = false;
      });
    }

    try {
      final player = Player();
      _player = player;
      _controller = VideoController(player);

      await player.open(Media('asset://${widget.videoPath}'));
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.setVolume(0);

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('❌ VIDEO PLAYER ERROR: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(AmbientVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: AppColors.cardBackground,
        child: const Center(
          child: Icon(
            Icons.movie_filter_outlined,
            color: Colors.white54,
            size: 40,
          ),
        ),
      );
    }

    if (_controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold),
        ),
      );
    }

    return Video(
      controller: _controller!,
      fit: BoxFit.cover,
      controls: NoVideoControls,
    );
  }
}
