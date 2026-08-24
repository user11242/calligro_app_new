import 'package:flutter/material.dart';
import 'package:calligro_app/features/meet/pages/calligro_meet_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:calligro_app/core/services/meet_debug_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class CalligroPreJoinPage extends StatefulWidget {
  final String token;
  final String serverUrl;
  final String roomName;
  final String courseId;
  final bool isTeacher;

  const CalligroPreJoinPage({
    Key? key,
    required this.token,
    required this.serverUrl,
    required this.roomName,
    required this.courseId,
    this.isTeacher = false,
  }) : super(key: key);

  @override
  State<CalligroPreJoinPage> createState() => _CalligroPreJoinPageState();
}

class _CalligroPreJoinPageState extends State<CalligroPreJoinPage> {
  bool _isMicOn = false;
  bool _isCameraOn = false;
  CameraPosition _cameraPosition = CameraPosition.front;
  LocalVideoTrack? _cameraTrack;
  bool _isJoining = false;
  String _avatarUrl = '';
  String _userName = 'Loading...';

  @override
  void dispose() {
    _cameraTrack?.stop();
    _cameraTrack?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              _userName = data['fullName'] ?? data['name'] ?? user.displayName ?? 'Calligro User';
              _avatarUrl = data['photoUrl'] ?? user.photoURL ?? '';
            });
          }
        }
      } catch (e) {
        debugPrint("Error fetching user for pre-join: $e");
      }
    }
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.readyToJoin,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.configureAudioVideo,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Avatar / Camera Preview Placeholder
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C23),
                  shape: BoxShape.circle,
                  border: Border.all(color: _isCameraOn ? const Color(0xFFEBB937) : Colors.white12, width: 3),
                  boxShadow: [
                    if (_isCameraOn)
                      BoxShadow(
                        color: const Color(0xFFEBB937).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Center(
                  child: (_isCameraOn && _cameraTrack != null)
                    ? ClipOval(
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: VideoTrackRenderer(_cameraTrack!),
                        ),
                      )
                    : (_avatarUrl.isNotEmpty 
                        ? ClipOval(
                            child: Image.network(_avatarUrl, width: 180, height: 180, fit: BoxFit.cover),
                          )
                        : Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white54),
                          )),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Toggles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildToggleBtn(
                    icon: _isMicOn ? Icons.mic : Icons.mic_off,
                    isActive: _isMicOn,
                    label: _isMicOn ? l10n.micOn : l10n.micOff,
                    onTap: () async {
                      if (!_isMicOn) {
                        final status = await Permission.microphone.request();
                        if (status.isGranted) {
                          setState(() => _isMicOn = true);
                        } else {
                          debugPrint('Microphone permission denied.');
                        }
                      } else {
                        setState(() => _isMicOn = false);
                      }
                    },
                  ),
                  const SizedBox(width: 32),
                  _buildToggleBtn(
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    isActive: _isCameraOn,
                    label: _isCameraOn ? l10n.camOn : l10n.camOff,
                    onTap: () async {
                      if (_isCameraOn) {
                        await _cameraTrack?.stop();
                        await _cameraTrack?.dispose();
                        setState(() {
                          _cameraTrack = null;
                          _isCameraOn = false;
                        });
                      } else {
                        final status = await Permission.camera.request();
                        if (status.isGranted) {
                          try {
                            final track = await LocalVideoTrack.createCameraTrack(
                              CameraCaptureOptions(
                                cameraPosition: _cameraPosition,
                              ),
                            );
                            setState(() {
                              _cameraTrack = track;
                              _isCameraOn = true;
                            });
                          } catch (e) {
                            debugPrint('Camera preview error: $e');
                          }
                        } else {
                          debugPrint('Camera permission denied.');
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 32),
                  if (_isCameraOn)
                    _buildToggleBtn(
                      icon: Icons.flip_camera_ios,
                      isActive: true,
                      label: l10n.flipCam,
                      onTap: () async {
                        setState(() {
                          _cameraPosition = _cameraPosition == CameraPosition.front 
                              ? CameraPosition.back 
                              : CameraPosition.front;
                        });
                        if (_cameraTrack != null) {
                          await _cameraTrack!.restartTrack(
                            CameraCaptureOptions(
                              cameraPosition: _cameraPosition,
                            )
                          );
                        }
                      },
                    ),
                ],
              ),
              
              const SizedBox(height: 60),
              
              // Join Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : () async {
                    setState(() => _isJoining = true);
                    MeetDebugService().log("🖱️ PreJoin: Join button clicked. Requesting permissions...");
                    // Final safety check to ensure permissions are granted before connecting to the room
                    if (_isCameraOn) await Permission.camera.request();
                    if (_isMicOn) await Permission.microphone.request();

                    MeetDebugService().log("🛑 PreJoin: Disposing local preview tracks");
                    // Must dispose local track before joining real room to free hardware lock
                    await _cameraTrack?.stop();
                    await _cameraTrack?.dispose();
                    _cameraTrack = null;

                    if (!mounted) {
                      MeetDebugService().log("⚠️ PreJoin: Component unmounted before pushReplacement!");
                      return;
                    }
                    
                    MeetDebugService().log("🚀 PreJoin: pushReplacement to CalligroMeetPage");
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CalligroMeetPage(
                          token: widget.token,
                          serverUrl: widget.serverUrl,
                          roomName: widget.roomName,
                          courseId: widget.courseId,
                          isTeacher: widget.isTeacher,
                          startWithMic: _isMicOn,
                          startWithCamera: _isCameraOn,
                          startCameraPosition: _cameraPosition,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEBB937),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: const Color(0xFFEBB937).withOpacity(0.5),
                  ),
                  child: Text(
                    l10n.joinClassroom,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn({required IconData icon, required bool isActive, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : const Color(0xFFEF4444),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isActive ? Colors.white : const Color(0xFFEF4444)).withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
