import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CalligroMeetPage extends StatefulWidget {
  final String token;
  final String serverUrl;
  final String roomName;
  final String courseId;

  const CalligroMeetPage({
    Key? key,
    required this.token,
    required this.serverUrl,
    required this.roomName,
    required this.courseId,
  }) : super(key: key);

  @override
  State<CalligroMeetPage> createState() => _CalligroMeetPageState();
}

class _CalligroMeetPageState extends State<CalligroMeetPage> {
  late Room _room;
  late EventsListener<RoomEvent> _listener;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    _room = Room();
    _listener = _room.createListener();

    _listener.on<RoomDisconnectedEvent>((event) {
      if (mounted) {
        Navigator.pop(context);
      }
    });

    try {
      await _room.connect(widget.serverUrl, widget.token);
      
      // Enable camera and mic automatically
      await _room.localParticipant?.setCameraEnabled(true);
      await _room.localParticipant?.setMicrophoneEnabled(true);

      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      debugPrint("LiveKit Connection Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    _room.disconnect();
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFEBB937)),
              SizedBox(height: 16),
              Text(
                "CONNECTING TO SECURE CLASSROOM...",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF13151A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.shieldCheck, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.roomName.substring(0, 15) + "...",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.phoneOff, color: Colors.red),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Video Grid (Basic implementation)
            Expanded(
              child: Center(
                child: Text(
                  "Calligro Meet is connected.\nFull video grid is rendering in Web Portal.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
            ),

            // Bottom Controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: const Color(0xFF13151A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: LucideIcons.mic,
                    onTap: () {
                      final p = _room.localParticipant;
                      if (p != null) p.setMicrophoneEnabled(!p.isMicrophoneEnabled());
                    },
                  ),
                  _ControlButton(
                    icon: LucideIcons.video,
                    onTap: () {
                      final p = _room.localParticipant;
                      if (p != null) p.setCameraEnabled(!p.isCameraEnabled());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
