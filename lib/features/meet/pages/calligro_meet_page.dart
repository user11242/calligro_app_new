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
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

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

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _playJoinSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/join.wav'));
    } catch (e) {
      _log('🔇 Failed to play join sound: $e');
    }
  }

  Future<void> _playLeaveSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/leave.wav'));
    } catch (e) {
      _log('🔇 Failed to play leave sound: $e');
    }
  }

  // ── Meeting Duration Timer ──────────────────────────────
  DateTime? _meetingStartTime;
  Timer? _durationTimer;
  Duration _meetingDuration = Duration.zero;

  // ── Active Speakers ────────────────────────────────────
  Set<String> _activeSpeakerIdentities = {};
  bool _wasCameraEnabledBeforeBackground = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
        // ── Camera Capture: 1080p @ 30fps ──────────────────────────
        // Captures at 1080p for perfect cloud recordings.
        // We rely on Simulcast to automatically downscale this for students
        // to save their battery and bandwidth.
        defaultCameraCaptureOptions: CameraCaptureOptions(
          cameraPosition: _cameraPosition,
          params: VideoParametersPresets.h1080_43,
          maxFrameRate: 30,
        ),
        // ── Video Publishing: aggressive encoding for calligraphy sharpness ──
        // Google Meet/Zoom use ~4-5 Mbps for 1080p. Our 6 Mbps cap
        // ensures the top Simulcast layer (which Egress records) is crystal clear.
        defaultVideoPublishOptions: const VideoPublishOptions(
          videoEncoding: VideoEncoding(
            maxBitrate: 6000000, // 6 Mbps — maximum sharpness for calligraphy
            maxFramerate: 30,
          ),
          simulcast: true,
          // For calligraphy, resolution > framerate. When bandwidth drops,
          // keep pen strokes sharp even if video becomes slightly choppy.
          degradationPreference: DegradationPreference.maintainResolution,
          videoCodec: 'h264', // Hardware-accelerated and generally sharper on mobile
          backupVideoCodec: BackupVideoCodec(codec: 'vp8'), // Fallback for older Androids
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
        // ENABLED adaptive stream — LiveKit will automatically send the
        // lightweight 360p or 720p layer to students on mobile phones,
        // while the server records the full 1080p stream.
        adaptiveStream: true,
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
        _playJoinSound();
        _sortParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((e) {
        _log('👤 Participant left: ${e.participant.identity}');
        _playLeaveSound();
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
      })
      ..on<ActiveSpeakersChangedEvent>((e) {
        if (mounted) {
          setState(() {
            _activeSpeakerIdentities = e.speakers.map((s) => s.identity).toSet();
          });
        }
      })
      ..on<TrackMutedEvent>((e) {
        _log('🔇 Track muted: ${e.publication.kind} from ${e.participant.identity}');
        _sortParticipants();
      })
      ..on<TrackUnmutedEvent>((e) {
        _log('🔊 Track unmuted: ${e.publication.kind} from ${e.participant.identity}');
        _sortParticipants();
      })
      ..on<DataReceivedEvent>((e) {
        // Listen for "end meeting" command from the teacher
        try {
          final decoded = utf8.decode(e.data);
          final msg = jsonDecode(decoded);
          if (msg['type'] == 'end_meeting_for_all') {
            _log('🛑 Teacher ended the meeting for everyone');
            if (mounted) {
              Navigator.pop(context);
            }
          }
        } catch (_) {}
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
      
      // Start meeting duration timer
      _meetingStartTime = DateTime.now();
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _meetingDuration = DateTime.now().difference(_meetingStartTime!);
          });
        }
      });
      
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
      // Find the camera track specifically (not screen share)
      final cameraPub = lp.videoTrackPublications
          .where((pub) => pub.source == TrackSource.camera)
          .firstOrNull;
      tracks.add(ParticipantTrack(
        participant: lp,
        videoTrack: cameraPub?.track,
      ));
    }

    for (var p in room.remoteParticipants.values) {
      // Find the camera track specifically (not screen share)
      final cameraPub = p.videoTrackPublications
          .where((pub) => pub.source == TrackSource.camera)
          .firstOrNull;
      tracks.add(ParticipantTrack(
        participant: p,
        videoTrack: cameraPub?.track,
      ));
      // Also add screen share as a separate track if present
      final screenPub = p.videoTrackPublications
          .where((pub) => pub.source == TrackSource.screenShareVideo)
          .firstOrNull;
      if (screenPub?.track != null) {
        tracks.add(ParticipantTrack(
          participant: p,
          videoTrack: screenPub!.track,
        ));
      }
    }

    if (mounted) setState(() { _participantTracks = tracks; });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _durationTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
    
    // Capture orientation synchronously before async gap
    final currentOrientation = MediaQuery.of(context).orientation == Orientation.landscape ? 'landscape' : 'portrait';
    
    try {
      _log("🔴 Waiting for camera/mic tracks to publish...");
      
      String? audioTrackId;
      String? videoTrackId;
      
      // Wait until both tracks are successfully published to LiveKit (timeout after 20s)
      int waitMs = 0;
      while (mounted && waitMs < 20000) {
        audioTrackId = _room?.localParticipant?.audioTrackPublications.firstOrNull?.sid;
        videoTrackId = _room?.localParticipant?.videoTrackPublications.firstOrNull?.sid;
        
        if (audioTrackId != null && videoTrackId != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
        waitMs += 500;
      }

      if (audioTrackId == null && videoTrackId == null) {
         _log("❌ Recording timeout: tracks never published.");
         if (mounted) {
           setState(() => _isRecording = false);
           AppMessenger.showSnackBar(context, title: AppLocalizations.of(context)!.recordingError, message: AppLocalizations.of(context)!.recordingTimeout, type: MessengerType.error);
         }
         return;
      }
      
      if (!mounted) return;

      _log("🔴 Starting automated R2 recording with tracks: Video=$videoTrackId, Audio=$audioTrackId, Orientation=$currentOrientation");
      await FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable('livekit-startAutomatedRecording')
          .call({
            'courseId': widget.courseId,
            'audioTrackId': audioTrackId,
            'videoTrackId': videoTrackId,
            'orientation': currentOrientation,
          });
      _log("✅ Recording started successfully");
      if (mounted) {
        AppMessenger.showSnackBar(context, title: AppLocalizations.of(context)!.recordingStarted, message: AppLocalizations.of(context)!.classIsBeingRecorded, type: MessengerType.success);
      }
    } catch (e) {
      _log("❌ Recording failed: $e");
      if (mounted) {
        setState(() => _isRecording = false);
        AppMessenger.showSnackBar(context, title: AppLocalizations.of(context)!.recordingError, message: e.toString(), type: MessengerType.error);
      }
    }
  }

  // ── Leave Confirmation Dialog ────────────────────────────────────────
  Future<void> _showLeaveConfirmation() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13151A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.leaveClass,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.leaveClassroomConfirmation,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.leave, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      _log('☎️ User confirmed leave via dialog');
      Navigator.pop(context);
    }
  }

  // ── End Meeting for All (Teacher only) ────────────────────────────────
  Future<void> _endMeetingForAll() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13151A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.endMeetingForEveryone,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.endMeetingConfirmation,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.endForAll, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      _log('🛑 Teacher ending meeting for all participants');
      try {
        // Send "end meeting" signal via LiveKit data channel to all participants
        final message = jsonEncode({'type': 'end_meeting_for_all'});
        await _room?.localParticipant?.publishData(
          utf8.encode(message),
          reliable: true,
        );
        // Small delay to let the message propagate before we disconnect
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        _log('⚠️ Failed to send end-meeting signal: $e');
      }
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Format duration as MM:SS ──────────────────────────────────────────
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: const Color(0xFF0F1115),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C23),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEBB937).withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    color: Color(0xFFEBB937),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  l10n.connectingToClassroom,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    l10n.connectingDisclaimer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                TextButton.icon(
                  onPressed: () {
                    _log("⚠️ User explicitly pressed 'Cancel Connection' button!");
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                  label: Text(
                    l10n.cancelConnection,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          _buildDebugConsole(),
        ],
      ),
    );
  }

  Widget _buildConnectedBody(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: Stack(
          children: [
            Column(
              children: [
                // Top Bar
                if (!isLandscape)
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
                          // Meeting Duration Timer
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDuration(_meetingDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_isRecording) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'REC',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else if (widget.isTeacher) ...[
                            IconButton(
                              icon: const Icon(Icons.radio_button_unchecked, color: Colors.white54),
                              tooltip: AppLocalizations.of(context)!.startRecording,
                              onPressed: () => _startRecording(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Leave or End for All button (depending on role)
                          IconButton(
                            icon: const Icon(Icons.call_end, color: Colors.red),
                            tooltip: widget.isTeacher ? AppLocalizations.of(context)!.endForAll : AppLocalizations.of(context)!.leave,
                            onPressed: widget.isTeacher ? _endMeetingForAll : _showLeaveConfirmation,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

            // Video Grid
            Expanded(
              child: _participantTracks.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context)!.waitingForOthersToJoin, style: const TextStyle(color: Colors.white54)))
                  : _buildGoogleMeetLayout(),
            ),

            // Bottom Controls
            if (!isLandscape)
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
                           ));
                        } else {
                           await p.setCameraEnabled(false);
                        }
                        _sortParticipants();
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
    
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    ParticipantTrack? focusTrack;
    
    // Priority 1: Screen Share
    for (var track in _participantTracks) {
      if (track.videoTrack?.source == TrackSource.screenShareVideo) {
        focusTrack = track;
        break;
      }
    }

    // Priority 2: Teacher (ALWAYS the big screen if no screen share)
    if (focusTrack == null) {
      for (var track in _participantTracks) {
        // Local participant if we are the teacher
        if (track.participant == _room?.localParticipant && widget.isTeacher) {
          focusTrack = track;
          break;
        }
        // Remote participant who is a teacher
        try {
          final meta = track.participant.metadata;
          if (meta != null && meta.contains('"role":"moderator"')) {
            focusTrack = track;
            break;
          }
        } catch (_) {}
      }
    }

    // Priority 3: Active Speaker (Fallback if no teacher)
    if (focusTrack == null && _room?.activeSpeakers.isNotEmpty == true) {
      final speaker = _room!.activeSpeakers.first;
      for (var track in _participantTracks) {
        if (track.participant.identity == speaker.identity && track.videoTrack?.source != TrackSource.screenShareVideo) {
          focusTrack = track;
          break;
        }
      }
    }

    // Fallback: Just take the first one
    focusTrack ??= _participantTracks.first;

    final carouselTracks = _participantTracks.where((t) => t != focusTrack).toList();

    return Stack(
      children: [
        // Main View (Teacher / Focus) - Takes up the entire screen edge-to-edge
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(color: Colors.black),
            clipBehavior: Clip.antiAlias,
            child: ParticipantWidget(track: focusTrack),
          ),
        ),
        
        // Carousel View (Floating horizontal strip at the bottom right)
        if (carouselTracks.isNotEmpty && !isLandscape)
          Positioned(
            bottom: 16,
            right: 16,
            left: 16,
            child: SizedBox(
              height: 120, // PiP height
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                reverse: true, // Align items to the bottom right corner
                itemCount: carouselTracks.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 90, // PiP width
                    margin: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ParticipantWidget(track: carouselTracks[index]),
                  );
                },
              ),
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
                Text(
                  AppLocalizations.of(context)!.reconnecting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.connectionDropped,
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
                Text(
                  AppLocalizations.of(context)!.connectionLost,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.sessionEndedOrCouldNotBeEstablished,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
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

    // Active speaker glow
    final isSpeaking = track.participant.isSpeaking;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpeaking ? const Color(0xFF22C55E) : Colors.white12,
          width: isSpeaking ? 2.5 : 1,
        ),
        boxShadow: [
          if (isSpeaking)
            BoxShadow(
              color: const Color(0xFF22C55E).withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Read the LIVE video track directly from the participant's publications
          // instead of relying on the stale ParticipantTrack.videoTrack reference.
          // This fixes the grey screen caused by stale track references.
          Builder(
            builder: (context) {
              // Get the live camera track from the participant's current publications
              VideoTrack? liveVideoTrack;
              try {
                final camPub = track.participant.videoTrackPublications
                    .where((pub) => pub.source == TrackSource.camera)
                    .firstOrNull;
                if (camPub != null && camPub.track != null && camPub.track is VideoTrack && !camPub.muted) {
                  liveVideoTrack = camPub.track as VideoTrack;
                }
              } catch (_) {}

              if (isCameraOn && liveVideoTrack != null)
                return ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: VideoTrackRenderer(liveVideoTrack),
                );
              else
                return Container(
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
                );
            },
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
