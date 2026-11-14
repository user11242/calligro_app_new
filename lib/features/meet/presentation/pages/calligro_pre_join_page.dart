import 'package:flutter/material.dart';

import 'package:calligro_app/core/services/meet_debug_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/pre_join_controller.dart';
import '../../data/firebase_profile_source.dart';
import '../../data/livekit_media_devices.dart';
import '../../domain/meet_media.dart';
import '../../domain/meet_participant.dart';
import '../widgets/participant_tile.dart' show MeetVideoView;
import 'calligro_meet_page.dart';

const _gold = Color(0xFFEBB937);

/// "Ready to join?" — name, camera preview, mic/camera choices. UI only:
/// every decision is made by [PreJoinController].
class CalligroPreJoinPage extends StatefulWidget {
  final String token;
  final String serverUrl;
  final String roomName;
  final String courseId;
  final bool isTeacher;
  final String? teacherId;

  /// Test seams (default: real camera/permissions, Firebase profile, real meet page).
  final MeetMediaDevices? devices;
  final MeetProfileSource? profile;
  final Widget Function(PreJoinSettings settings)? meetPageBuilder;

  const CalligroPreJoinPage({
    super.key,
    required this.token,
    required this.serverUrl,
    required this.roomName,
    required this.courseId,
    this.isTeacher = false,
    this.teacherId,
    @visibleForTesting this.devices,
    @visibleForTesting this.profile,
    @visibleForTesting this.meetPageBuilder,
  });

  @override
  State<CalligroPreJoinPage> createState() => _CalligroPreJoinPageState();
}

class _CalligroPreJoinPageState extends State<CalligroPreJoinPage> {
  late final PreJoinController _controller = PreJoinController(
    devices: widget.devices ?? const LiveKitMediaDevices(),
    profile: widget.profile ?? const FirebaseProfileSource(),
    isTeacher: widget.isTeacher,
    log: MeetDebugService().log,
  );

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose(); // stops a running preview
    super.dispose();
  }

  Future<void> _join() async {
    MeetDebugService().log('🖱️ PreJoin: Join pressed');
    final settings = await _controller.join();
    if (settings == null || !mounted) return;
    MeetDebugService().log('🚀 PreJoin: opening the class');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            widget.meetPageBuilder?.call(settings) ??
            CalligroMeetPage(
              token: widget.token,
              serverUrl: widget.serverUrl,
              roomName: widget.roomName,
              courseId: widget.courseId,
              isTeacher: widget.isTeacher,
              teacherId: widget.teacherId,
              startWithMic: settings.startWithMic,
              startWithCamera: settings.startWithCamera,
              startCameraPosition: settings.cameraPosition,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('prejoin-back'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          final name = c.userName ?? 'Loading...';
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Column(
                children: [
                  Text(l10n.readyToJoin,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(l10n.configureAudioVideo,
                      style: const TextStyle(color: Colors.white54, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  _PreviewCircle(preview: c.cameraOn ? c.preview : null, avatarUrl: c.avatarUrl, name: name),
                  const SizedBox(height: 24),
                  Text(name,
                      key: const Key('prejoin-name'),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 48),
                  // Wrap (not Row): long labels / small phones never overflow.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 32,
                    runSpacing: 16,
                    children: [
                      _ToggleButton(
                        key: const Key('prejoin-mic'),
                        icon: c.micOn ? Icons.mic : Icons.mic_off,
                        isActive: c.micOn,
                        label: c.micOn ? l10n.micOn : l10n.micOff,
                        onTap: c.toggleMicrophone,
                      ),
                      _ToggleButton(
                        key: const Key('prejoin-camera'),
                        icon: c.cameraOn ? Icons.videocam : Icons.videocam_off,
                        isActive: c.cameraOn,
                        label: c.cameraOn ? l10n.camOn : l10n.camOff,
                        onTap: c.toggleCamera,
                      ),
                      if (c.cameraOn)
                        _ToggleButton(
                          key: const Key('prejoin-flip'),
                          icon: Icons.flip_camera_ios,
                          isActive: true,
                          label: l10n.flipCam,
                          onTap: c.flipCamera,
                        ),
                    ],
                  ),
                  if (c.lastError != null) ...[
                    const SizedBox(height: 16),
                    Text(c.lastError!,
                        key: const Key('prejoin-error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                  ],
                  if (widget.isTeacher) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _gold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: _gold, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(l10n.teacherRecordingNote,
                                style: const TextStyle(color: _gold, fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 60),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      key: const Key('prejoin-join'),
                      onPressed: c.isJoining || c.isBusy ? null : _join,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 5,
                        shadowColor: _gold.withValues(alpha: 0.5),
                      ),
                      child: Text(l10n.joinClassroom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Round camera preview, or the avatar / initial when the camera is off.
class _PreviewCircle extends StatelessWidget {
  final MeetVideo? preview;
  final String? avatarUrl;
  final String name;
  const _PreviewCircle({required this.preview, required this.avatarUrl, required this.name});

  Widget _initial() => Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white54),
      );

  @override
  Widget build(BuildContext context) {
    final on = preview != null;
    return Container(
      key: const Key('prejoin-preview'),
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        shape: BoxShape.circle,
        border: Border.all(color: on ? _gold : Colors.white12, width: 3),
        boxShadow: [if (on) BoxShadow(color: _gold.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Center(
        child: on
            ? ClipOval(child: SizedBox(width: 180, height: 180, child: MeetVideoView(preview!, cover: true)))
            : avatarUrl != null
                ? ClipOval(
                    child: Image.network(avatarUrl!,
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        // Broken/unreachable avatar → the initial, not an error box.
                        errorBuilder: (_, _, _) => _initial()),
                  )
                : _initial(),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String label;
  final VoidCallback onTap;
  const _ToggleButton({super.key, required this.icon, required this.isActive, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : const Color(0xFFEF4444);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)],
            ),
            child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: isActive ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
