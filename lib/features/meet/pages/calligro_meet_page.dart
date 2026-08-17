import 'dart:convert';
import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:calligro_app/core/services/meet_debug_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/features/meet/controllers/connection_resilience_controller.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// Top-level callback for foreground service (required by package but we just need the service alive)
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isServiceState) async {}
}

class CalligroMeetPage extends StatefulWidget {
  final String token;
  final String serverUrl;
  final String roomName;
  final String courseId;
  final bool isTeacher;
  final bool startWithMic;
  final bool startWithCamera;
  final CameraPosition startCameraPosition;

  const CalligroMeetPage({
    Key? key,
    required this.token,
    required this.serverUrl,
    required this.roomName,
    required this.courseId,
    this.isTeacher = false,
    this.startWithMic = false,
    this.startWithCamera = false,
    this.startCameraPosition = CameraPosition.front,
  }) : super(key: key);

  @override
  State<CalligroMeetPage> createState() => _CalligroMeetPageState();
}

class _CalligroMeetPageState extends State<CalligroMeetPage> with WidgetsBindingObserver {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _isDisconnected = false;
  List<ParticipantTrack> _participantTracks = [];
  late CameraPosition _cameraPosition;

  // ── Debug Console ──────────────────────────────
  final _debug = MeetDebugService();

  void _log(String msg) => _debug.log(msg);

  bool _showDebug = false;
  final ScrollController _logScroll = ScrollController();
  
  bool _isRecording = false;

  late final ConnectionResilienceController _resilienceController;
  
  bool _isAudioOnlyMode = false;
  bool _wasCameraEnabledBeforeBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initForegroundTask();
    _resilienceController = ConnectionResilienceController();
    _cameraPosition = widget.startCameraPosition;
    _log('initState — starting connection flow');
    _connect();
  }

  Future<void> _connect() async {
    _log('_connect() called — cleaning up old room first');
    await _cleanupRoom();

    _log('Waiting 800ms for server grace period...');
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) { _log('Widget unmounted after delay — aborting'); return; }

    _log('Creating new Room instance with HD quality settings');
    final room = Room(
      roomOptions: RoomOptions(
        // ── Camera Capture: 720p @ 30fps ──────────────────────────
        // Captures at 720p which is the sweet spot for mobile phones.
        // 1080p on mobile burns battery and most phone cameras compress
        // heavily anyway, so 720p gives the best quality-per-watt.
        defaultCameraCaptureOptions: CameraCaptureOptions(
          cameraPosition: _cameraPosition,
          params: VideoParametersPresets.h1080_43,
          maxFrameRate: 30,
        ),
        // ── Video Publishing: aggressive encoding for calligraphy sharpness ──
        // Google Meet/Zoom use ~4-5 Mbps for 1080p. Our previous 3 Mbps cap
        // was causing LiveKit's adaptive system to over-compress fine details
        // like pen strokes and Arabic letters. Bumping to 4.5 Mbps with
        // a higher top simulcast layer fixes the blurriness on iPhones.
        defaultVideoPublishOptions: const VideoPublishOptions(
          videoEncoding: VideoEncoding(
            maxBitrate: 6000000, // 6 Mbps — maximum sharpness for calligraphy
            maxFramerate: 30,
          ),
          simulcast: false,
          // For calligraphy, resolution > framerate. When bandwidth drops,
          // keep pen strokes sharp even if video becomes slightly choppy.
          degradationPreference: DegradationPreference.maintainResolution,
          videoCodec: 'h264', // Hardware-accelerated and generally sharper on mobile
        ),
        // ── Audio: crystal clear voice with noise suppression ──
        defaultAudioPublishOptions: const AudioPublishOptions(
          dtx: true,  // Saves bandwidth when nobody is talking
          red: true,  // Redundant Audio Data — sends packets twice so
                      // dropped packets on bad connections don't cause
                      // audio cuts. Essential for students worldwide.
        ),
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          noiseSuppression: true,
          echoCancellation: true,
          autoGainControl: true,
          typingNoiseDetection: true,
        ),
        // ── Speaker output: always use loudspeaker on phones ──
        defaultAudioOutputOptions: const AudioOutputOptions(
          speakerOn: true,
        ),
        // ── Adaptive Stream + Dynacast for smart bandwidth usage ──
        // DISABLED adaptive stream — it auto-downscales to 360p/720p based
        // on the video widget's physical pixel size on screen. We ALWAYS
        // want the full 1080p stream for razor-sharp pen strokes.
        adaptiveStream: false,
        dynacast: true,
      ),
    );
    _room = room;
    final listener = room.createListener();
    _listener = listener;

    listener
      ..on<RoomDisconnectedEvent>((event) {
        _log('🔴 DISCONNECTED — reason: ${event.reason}');
        if (mounted) {
          setState(() {
            _isReconnecting = false;
            _isDisconnected = true;
          });
        }
      })
      ..on<RoomReconnectingEvent>((_) {
        _log('🟡 RECONNECTING...');
        if (mounted) setState(() => _isReconnecting = true);
      })
      ..on<RoomReconnectedEvent>((_) {
        _log('🟢 RECONNECTED successfully');
        if (mounted) setState(() { _isReconnecting = false; _isDisconnected = false; });
      })
      ..on<ParticipantConnectedEvent>((e) {
        _log('👤 Participant joined: ${e.participant.identity}');
        _sortParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((e) {
        _log('👤 Participant left: ${e.participant.identity}');
        _sortParticipants();
      })
      ..on<TrackSubscribedEvent>((e) {
        _log('📹 Track subscribed: ${e.track.kind} from ${e.participant.identity}');
        
        if (_isAudioOnlyMode && e.track.kind == TrackType.VIDEO) {
          _log('🔇 Audio-only mode active: Immediately unsubscribing from incoming video track');
          e.publication.unsubscribe();
        }
        
        _sortParticipants();
      })
      ..on<TrackUnsubscribedEvent>((e) {
        _log('📹 Track unsubscribed: ${e.track.kind}');
        _sortParticipants();
      })
      ..on<LocalTrackPublishedEvent>((e) {
        _log('📤 Local track published: ${e.publication.kind}');
        _sortParticipants();
      })
      ..on<LocalTrackUnpublishedEvent>((e) {
        _log('📤 Local track unpublished: ${e.publication.kind}');
        _sortParticipants();
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
        _resilienceController.handleConnectionQualityUpdate(
          e.connectionQuality, 
          () => _showAudioOnlyPrompt(),
        );
      });

    try {
      _log('Calling room.connect(${widget.serverUrl})');
      final startTime = DateTime.now().millisecondsSinceEpoch;
      await room.connect(
        widget.serverUrl,
        widget.token,
        // Extended timeouts for students on slow 3G/4G worldwide.
        // Default is only 10s — too short for remote areas.
        connectOptions: const ConnectOptions(
          timeouts: Timeouts(
            connection: Duration(seconds: 30),
            debounce: Duration(milliseconds: 20),
            publish: Duration(seconds: 15),
            subscribe: Duration(seconds: 15),
            peerConnection: Duration(seconds: 30),
            iceRestart: Duration(seconds: 15),
          ),
        ),
      );
      if (!mounted) {
        _log('Widget unmounted after connection — aborting');
        return;
      }
      _log('✅ room.connect() succeeded — room state: ${room.connectionState}');
      
      if (widget.startWithCamera) {
        _log('Enabling camera (${_cameraPosition.name})...');
        await room.localParticipant?.setCameraEnabled(true,
            cameraCaptureOptions: CameraCaptureOptions(
              cameraPosition: _cameraPosition,
              params: VideoParametersPresets.h1080_43,
              maxFrameRate: 30,
            ));
        _log('Camera enabled');
      }
      if (widget.startWithMic) {
        _log('Enabling microphone...');
        await room.localParticipant?.setMicrophoneEnabled(true);
        _log('Microphone enabled');
      }

      _sortParticipants();
      _log('✅ Fully connected. Participants: ${_participantTracks.length}');
      
      final joinTime = DateTime.now().millisecondsSinceEpoch - startTime;
      _log('[TELEMETRY] ConnectSuccess | OS: ${Theme.of(context).platform.name} | Region/Course: ${widget.courseId} | JoinTime: ${joinTime}ms');
      
      if (mounted) setState(() { _isConnected = true; });

      // Start foreground service to keep audio alive
      await FlutterForegroundTask.startService(
        notificationTitle: 'Live Class Active',
        notificationText: 'Audio is running in the background.',
        callback: startCallback,
      );

      // Automatically start recording for teachers
      if (widget.isTeacher) {
        _startRecording();
      }
    } catch (e, st) {
      _log('❌ CONNECT ERROR: $e');
      _log('[TELEMETRY] ConnectFailed | ErrorType: ${e.runtimeType}');
      
      if (_resilienceController.shouldRetryWithRelay(e)) {
        _log('🔄 Triggering ICE Relay Fallback over TCP/TLS...');
        _log('[TELEMETRY] IceRelayFallbackTriggered');
        try {
          await room.connect(
            widget.serverUrl,
            widget.token,
            connectOptions: const ConnectOptions(
              // Force TURN relay so the connection uses standard port 443 TCP/TLS
              // effectively punching through strict firewalls that block UDP.
              rtcConfiguration: RTCConfiguration(
                iceTransportPolicy: RTCIceTransportPolicy.relay,
              ),
              timeouts: Timeouts(
                connection: Duration(seconds: 30),
                debounce: Duration(milliseconds: 20),
                publish: Duration(seconds: 15),
                subscribe: Duration(seconds: 15),
                peerConnection: Duration(seconds: 30),
                iceRestart: Duration(seconds: 15),
              ),
            ),
          );
          _log('✅ ICE Relay Fallback succeeded!');
          _log('[TELEMETRY] IceRelayFallbackSucceeded');
          
          if (!mounted) return;
          if (mounted) setState(() { _isConnected = true; });
          
        } catch (relayError) {
          _log('❌ ICE Relay Fallback failed: $relayError');
          _log('[TELEMETRY] IceRelayFallbackFailed');
          _handleConnectFailure(e, st);
        }
      } else {
        _handleConnectFailure(e, st);
      }
    }
  }

  void _handleConnectFailure(Object e, StackTrace st) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
      setState(() { _showDebug = true; });
    }
  }

  // ── Audio-Only Hysteresis Prompt ─────────────────────────────────────────

  void _showAudioOnlyPrompt() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13151A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Unstable Connection',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Your network connection is struggling, making the video blurry.\n\nWould you like to switch to Audio-Only mode? This will stop video but keep the audio crystal clear.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _resilienceController.onPromptClosed();
              },
              child: const Text('Dismiss', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _resilienceController.onPromptClosed();
                _enableAudioOnlyMode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEBB937),
                foregroundColor: Colors.black,
              ),
              child: const Text('Switch to Audio-Only', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _enableAudioOnlyMode() async {
    _log('Enabling Audio-Only mode due to poor connection');
    
    _isAudioOnlyMode = true;

    // 1. Disable local camera so we stop uploading video
    if (widget.startWithCamera) {
      await _room?.localParticipant?.setCameraEnabled(false);
    }
    
    // 2. Unsubscribe from all existing remote video tracks to free up download bandwidth
    if (_room != null) {
      for (final participant in _room!.remoteParticipants.values) {
        for (final pub in participant.videoTrackPublications) {
          if (pub.subscribed) {
             _log('Unsubscribing from remote video track: ${pub.sid}');
             pub.unsubscribe();
          }
        }
      }
    }
    
    AppMessenger.showSnackBar(
      context, 
      title: 'Audio-Only Mode',
      message: 'Audio-Only mode activated. Tap the video icon to resume video later.',
      type: MessengerType.info,
    );
    if (mounted) setState(() {});
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'calligro_live_class',
        channelName: 'Live Class Audio',
        channelDescription: 'Keeps the class audio alive in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    
    if (_room == null || _room!.connectionState.name != 'connected') return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // OS is backgrounding us. Cut the camera cleanly so we don't send frozen/black frames.
      // Audio is kept alive by the foreground service (Android) / UIBackgroundModes (iOS).
      if (_room!.localParticipant?.isCameraEnabled() == true) {
        _log('App backgrounded: Muting camera to prevent frozen frames');
        _wasCameraEnabledBeforeBackground = true;
        await _room!.localParticipant?.setCameraEnabled(false);
      } else {
        _wasCameraEnabledBeforeBackground = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      // App foregrounded. 
      _log('App resumed: Reconnecting UI if needed');
      if (_wasCameraEnabledBeforeBackground && !_isAudioOnlyMode) {
        _log('App resumed: Restoring previously enabled camera');
        await _room!.localParticipant?.setCameraEnabled(true);
      }
    }
  }

  Future<void> _cleanupRoom() async {
    _log('_cleanupRoom() — disposing listener and disconnecting room');
    try {
      await _listener?.dispose();
      _listener = null;
      await _room?.disconnect();
      await _room?.dispose();
      _room = null;
      _log('_cleanupRoom() done');
    } catch (e) {
      _log('_cleanupRoom() error (ignored): $e');
    }
  }

  void _sortParticipants() {
    final room = _room;
    if (room == null) return;
    List<ParticipantTrack> tracks = [];
    if (room.localParticipant != null) {
      final lp = room.localParticipant!;
      if (lp.videoTrackPublications.isNotEmpty) {
        tracks.add(ParticipantTrack(participant: lp, videoTrack: lp.videoTrackPublications.first.track));
      } else {
        tracks.add(ParticipantTrack(participant: lp, videoTrack: null));
      }
    }

    for (var p in room.remoteParticipants.values) {
      if (p.videoTrackPublications.isNotEmpty) {
        tracks.add(ParticipantTrack(participant: p, videoTrack: p.videoTrackPublications.first.track));
      } else {
        tracks.add(ParticipantTrack(participant: p, videoTrack: null));
      }
    }

    if (mounted) setState(() { _participantTracks = tracks; });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.stopService();
    _logScroll.dispose();
    _log('dispose() called — meeting page is closing');
    try {
      final st = StackTrace.current.toString();
      _log('dispose() stacktrace: ${st.substring(0, st.length.clamp(0, 400))}');
    } catch (e) {
      _log('could not get stacktrace');
    }
    _cleanupRoom();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording || !mounted) return;
    setState(() => _isRecording = true);
    try {
      _log("🔴 Starting automated R2 recording...");
      await FirebaseFunctions.instance
          .httpsCallable('livekit-startAutomatedRecording')
          .call({'courseId': widget.courseId});
      _log("✅ Recording started successfully");
      if (mounted) {
        AppMessenger.showSnackBar(context, title: "Recording Started", message: "Class is now being recorded to Cloudflare", type: MessengerType.success);
      }
    } catch (e) {
      _log("❌ Recording failed: $e");
      if (mounted) {
        setState(() => _isRecording = false);
        AppMessenger.showSnackBar(context, title: "Recording Error", message: e.toString(), type: MessengerType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // PERMANENTLY block swipe-back on iOS. Users MUST use the Red Phone button to exit.
      child: Scaffold(
        backgroundColor: Colors.black,
        body: !_isConnected ? _buildConnectingBody(context) : Stack(
          children: [
            _buildConnectedBody(context),
            // ── Reconnection / Disconnection Overlay ──
            if (_isReconnecting || _isDisconnected)
              _buildReconnectionOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingBody(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFEBB937)),
              const SizedBox(height: 24),
              const Text(
                "CONNECTING TO SECURE CLASSROOM...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "This may take up to 15 seconds on 4G/Cellular networks.\nPlease do not close the app.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () {
                  _log("⚠️ User explicitly pressed 'Cancel Connection' button!");
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                label: const Text("Cancel Connection", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
        _buildDebugConsole(),
      ],
    );
  }

  Widget _buildConnectedBody(BuildContext context) {
    return SafeArea(
      child: Stack(
          children: [
            Column(
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
                          const Icon(Icons.security, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            widget.roomName.length > 15 ? widget.roomName.substring(0, 15) + "..." : widget.roomName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Debug toggle button
                          GestureDetector(
                            onTap: () => setState(() => _showDebug = !_showDebug),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _showDebug ? Colors.orange.withValues(alpha: 0.3) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _showDebug ? Colors.orange : Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.bug_report,
                                color: _showDebug ? Colors.orange : Colors.white54,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.isTeacher) ...[
                            IconButton(
                              icon: _isRecording
                                  ? const Icon(Icons.radio_button_checked, color: Colors.red)
                                  : const Icon(Icons.radio_button_unchecked, color: Colors.white54),
                              onPressed: _isRecording ? null : () => _startRecording(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: const Icon(Icons.call_end, color: Colors.red),
                            onPressed: () {
                              _log("☎️ User explicitly pressed 'Red Phone' button to leave!");
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

            // Video Grid
            Expanded(
              child: _participantTracks.isEmpty
                  ? const Center(child: Text("Waiting for others to join...", style: TextStyle(color: Colors.white54)))
                  : _buildGoogleMeetLayout(),
            ),

            // Bottom Controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: const Color(0xFF13151A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _room?.localParticipant?.isMicrophoneEnabled() == true ? Icons.mic : Icons.mic_off,
                    isActive: _room?.localParticipant?.isMicrophoneEnabled() == true,
                    onTap: () async {
                      final p = _room?.localParticipant;
                      if (p != null) {
                        await p.setMicrophoneEnabled(!(p.isMicrophoneEnabled()));
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                  _ControlButton(
                    icon: _room?.localParticipant?.isCameraEnabled() == true ? Icons.videocam : Icons.videocam_off,
                    isActive: _room?.localParticipant?.isCameraEnabled() == true,
                    onTap: () async {
                      final p = _room?.localParticipant;
                      if (p != null) {
                        bool turningOn = !(p.isCameraEnabled());
                        if (turningOn) {
                           await p.setCameraEnabled(true, cameraCaptureOptions: CameraCaptureOptions(
                             cameraPosition: _cameraPosition,
                             params: VideoParametersPresets.h1080_43,
                             maxFrameRate: 30,
                           ));
                        } else {
                           await p.setCameraEnabled(false);
                        }
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                  if (_room?.localParticipant?.isCameraEnabled() == true)
                    _ControlButton(
                      icon: Icons.flip_camera_ios,
                      isActive: true,
                      onTap: () async {
                        setState(() {
                          _cameraPosition = _cameraPosition == CameraPosition.front 
                              ? CameraPosition.back 
                              : CameraPosition.front;
                        });
                        final p = _room?.localParticipant;
                        if (p != null) {
                          final track = p.videoTrackPublications.firstWhereOrNull((pub) => pub.track is LocalVideoTrack)?.track as LocalVideoTrack?;
                          if (track != null) {
                            await track.restartTrack(CameraCaptureOptions(
                              cameraPosition: _cameraPosition,
                              params: VideoParametersPresets.h1080_43,
                              maxFrameRate: 30,
                            ));
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
            // Debug console overlay (on top of everything)
          _buildDebugConsole(),
        ],
      ),
    );
  }

  Widget _buildDebugConsole() {
    if (!_showDebug) return const SizedBox.shrink();
    return Positioned(
      left: 8,
      right: 8,
      bottom: 90,
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black.withValues(alpha: 0.88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.orange.withValues(alpha: 0.2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🐛 LiveKit Debug Log',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                    GestureDetector(
                      onTap: () => setState(() => _debug.clear()),
                      child: const Text('CLEAR',
                          style: TextStyle(color: Colors.orange, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _logScroll,
                  padding: const EdgeInsets.all(8),
                  itemCount: _debug.logs.length,
                  itemBuilder: (_, i) {
                    final entry = _debug.logs[i];
                    Color color = Colors.white70;
                    if (entry.level == LogLevel.error) color = const Color(0xFFFF6B6B);
                    if (entry.level == LogLevel.success) color = const Color(0xFF69FF8B);
                    if (entry.level == LogLevel.warning) color = Colors.yellow;
                    if (entry.level == LogLevel.info) color = const Color(0xFF69C4FF);
                    return Text('[${entry.formattedTime}] ${entry.message}',
                        style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleMeetLayout() {
    if (_participantTracks.isEmpty) return const SizedBox();
    
    // Priority 1: Screen Share
    ParticipantTrack? focusTrack;
    for (var track in _participantTracks) {
      if (track.videoTrack?.source == TrackSource.screenShareVideo) {
        focusTrack = track;
        break;
      }
    }

    // Priority 2: Active Speaker
    if (focusTrack == null && _room?.activeSpeakers.isNotEmpty == true) {
      final speaker = _room!.activeSpeakers.first;
      for (var track in _participantTracks) {
        if (track.participant.identity == speaker.identity && track.videoTrack?.source != TrackSource.screenShareVideo) {
          focusTrack = track;
          break;
        }
      }
    }

    // Priority 3: Teacher
    if (focusTrack == null) {
      for (var track in _participantTracks) {
        try {
          final meta = track.participant.metadata;
          if (meta != null && meta.contains('"role":"moderator"')) {
            focusTrack = track;
            break;
          }
        } catch (_) {}
      }
    }

    // Fallback: Just take the first one
    focusTrack ??= _participantTracks.first;

    final carouselTracks = _participantTracks.where((t) => t != focusTrack).toList();

    return Column(
      children: [
        // Main View (takes up remaining space)
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF13151A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            clipBehavior: Clip.antiAlias,
            child: ParticipantWidget(track: focusTrack),
          ),
        ),
        // Carousel View (Horizontal strip at bottom)
        if (carouselTracks.isNotEmpty)
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: carouselTracks.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13151A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ParticipantWidget(track: carouselTracks[index]),
                );
              },
            ),
          ),
      ],
    );
  }
  // ── Reconnection Overlay (matches web portal UX) ──────────────────
  Widget _buildReconnectionOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF13151A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isReconnecting) ...[
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Color(0xFFEBB937),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reconnecting...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your connection dropped. Trying to restore the session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else if (_isDisconnected) ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Connection Lost',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The session could not be restored.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _log('🔄 User pressed Rejoin button');
                      setState(() {
                        _isConnected = false;
                        _isDisconnected = false;
                        _isReconnecting = false;
                      });
                      _connect();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEBB937),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Rejoin Classroom',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Leave Class',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ParticipantTrack {
  final Participant participant;
  final Track? videoTrack;
  ParticipantTrack({required this.participant, this.videoTrack});
}

class ParticipantWidget extends StatelessWidget {
  final ParticipantTrack track;

  const ParticipantWidget({Key? key, required this.track}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the name to display (fallback to identity if name is empty)
    final displayName = (track.participant.name.isNotEmpty)
        ? track.participant.name
        : track.participant.identity;

    // Parse metadata for avatar
    String? avatarUrl;
    try {
      if (track.participant.metadata != null && track.participant.metadata!.isNotEmpty) {
        final meta = jsonDecode(track.participant.metadata!);
        avatarUrl = meta['avatar'] as String?;
      }
    } catch (e) {
      debugPrint("Could not parse metadata for avatar: $e");
    }

    final isCameraOn = track.participant.isCameraEnabled();
    final isMicOn = track.participant.isMicrophoneEnabled();

    // Connection quality indicator
    final connectionQuality = track.participant.connectionQuality;
    IconData qualityIcon;
    Color qualityColor;
    switch (connectionQuality) {
      case ConnectionQuality.excellent:
        qualityIcon = Icons.signal_wifi_4_bar;
        qualityColor = const Color(0xFF22C55E); // green
        break;
      case ConnectionQuality.good:
        qualityIcon = Icons.network_wifi_3_bar;
        qualityColor = const Color(0xFFEBB937); // gold
        break;
      case ConnectionQuality.poor:
        qualityIcon = Icons.network_wifi_1_bar;
        qualityColor = const Color(0xFFEF4444); // red
        break;
      default:
        qualityIcon = Icons.signal_wifi_4_bar;
        qualityColor = Colors.white38;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isCameraOn && track.videoTrack != null)
            VideoTrackRenderer(track.videoTrack as VideoTrack)
          else
            Container(
              color: const Color(0xFF1A1C23),
              child: Center(
                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(avatarUrl),
                      )
                    : CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFFEBB937),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
              ),
            ),

          // ── Connection Quality Indicator (top-left) ──
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(qualityIcon, color: qualityColor, size: 14),
            ),
          ),
            
          // Glassmorphism Name Tag Overlay
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isMicOn)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_off, color: Colors.white, size: 14),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ControlButton({required this.icon, required this.onTap, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white24 : Colors.red.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
