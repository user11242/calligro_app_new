import 'dart:ui';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:calligro_app/core/services/meet_debug_service.dart';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/features/meet/controllers/connection_resilience_controller.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:calligro_app/core/services/security_service.dart';
import 'package:calligro_app/features/meet/logic/meet_backend.dart';
import 'package:calligro_app/features/meet/logic/meet_message_handler.dart';
import 'package:calligro_app/features/meet/logic/meet_policies.dart';
import 'package:calligro_app/features/meet/logic/meet_protocol.dart';

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
  final String? teacherId;
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
    this.teacherId,
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
  bool _isEndingMeeting = false;
  List<ParticipantTrack> _participantTracks = [];
  late CameraPosition _cameraPosition;
  bool _isHandRaised = false;
  final Set<String> _raisedHands = {};

  // ── Debug Console ──────────────────────────────
  final _debug = MeetDebugService();

  void _log(String msg) => _debug.log(msg);

  bool _showDebug = false;
  final ScrollController _logScroll = ScrollController();
  
  bool _isRecording = false;

  late final ConnectionResilienceController _resilienceController;
  
  bool _isAudioOnlyMode = false;
  bool _isGridView = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  void _promptAudioOnlyMode() {
    if (!mounted || _isAudioOnlyMode) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.network_check, color: Colors.orange, size: 22),
            const SizedBox(width: 8),
            Text(
              l10n.meetWeakConnectionTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          l10n.meetWeakConnectionBody,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resilienceController.onPromptClosed();
            },
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEBB937),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _resilienceController.onPromptClosed();
              _setAudioOnlyMode(true);
            },
            child: Text(l10n.meetEnableAudioOnly, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _setAudioOnlyMode(bool enable) {
    if (_isAudioOnlyMode == enable) return;
    setState(() {
      _isAudioOnlyMode = enable;
    });

    _log('🎧 Audio-only mode set to: $enable');

    final remoteParticipants = _room?.remoteParticipants.values ?? [];
    for (final participant in remoteParticipants) {
      for (final pub in participant.videoTrackPublications) {
        if (enable) {
          pub.unsubscribe();
        } else {
          pub.subscribe();
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enable
                ? AppLocalizations.of(context)!.meetAudioOnlyOn
                : AppLocalizations.of(context)!.meetAudioOnlyOff,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFEBB937),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

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
  bool _wasCameraEnabledBeforeBackground = false;

  // ── Immersive Full-Screen Tap-to-Show Controls ──────────
  bool _showControls = true;
  Timer? _controlsTimer;

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startControlsTimer();
    // 🔒 Lock Calligro Meet strictly to Horizontal (Landscape) mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    WidgetsBinding.instance.addObserver(this);
    _initForegroundTask();
    _resilienceController = ConnectionResilienceController();
    _cameraPosition = widget.startCameraPosition;
    _log('initState — starting connection flow');
    SecurityService().enableScreenshotProtection();
    _connect();
  }

  /// All Cloud Function calls (token, moderation, recording) — see MeetBackend.
  late final MeetBackend _backend = MeetBackend(courseId: widget.courseId);

  /// Enforces a moderation action server-side (see MeetModerationAction).
  Future<bool> _moderateOnServer(String action, [String? targetIdentity]) async {
    try {
      await _backend.moderate(action, targetIdentity: targetIdentity);
      _log('✅ Server moderation "$action" succeeded for ${targetIdentity ?? 'all'}');
      return true;
    } catch (e) {
      _log('❌ Server moderation "$action" failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// Compact floating notice used for teacher actions.
  void _showPill(Widget icon, String text, {required Color background, required Color foreground, int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(color: foreground, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        duration: Duration(seconds: seconds),
        behavior: SnackBarBehavior.floating,
        width: 340, // compact pill
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: background,
      ),
    );
  }

  void _leaveAfterNotice() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  /// Performs the side effects for a decision made by MeetMessageHandler.
  void _applyMeetAction(MeetAction action) {
    final lp = _room?.localParticipant;
    switch (action) {
      case IgnoreMessage(:final reason):
        if (reason == IgnoreReason.unauthorizedSender) {
          _log('⚠️ Ignored teacher-only command from a non-moderator');
        }
      case HandRaised(:final identity, :final name):
        if (mounted) setState(() => _raisedHands.add(identity));
        _log('✋ $name raised their hand');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pan_tool, color: Colors.white, size: 18),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.of(context)!.studentRaisedHand(name),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              width: 320,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              backgroundColor: const Color(0xFF1E2028).withValues(alpha: 0.95),
            ),
          );
        }
      case HandLowered(:final identity, :final isSelf):
        if (mounted) {
          setState(() {
            _raisedHands.remove(identity);
            if (isSelf) _isHandRaised = false;
          });
        }
      case HandForceLowered(:final targetId, :final isSelf):
        if (mounted) {
          setState(() {
            _raisedHands.remove(targetId);
            if (isSelf) _isHandRaised = false;
          });
        }
        // Bounce back a standard lower_hand so every client stays in sync.
        if (isSelf && lp != null) {
          lp.publishData(
            MeetProtocol.encode(MeetProtocol.lowerHandMessage(MeetProtocol.displayName(lp.name, lp.identity))),
            reliable: true,
          );
        }
      case MeetingEndedByTeacher():
        _log('🛑 Teacher ended the meeting for everyone');
        _isEndingMeeting = true;
        if (mounted) {
          _showPill(
            const _WavingIcon(icon: Icons.waving_hand, color: Colors.black, size: 18),
            AppLocalizations.of(context)!.teacherEndedMeeting,
            background: const Color(0xFFEBB937),
            foreground: Colors.black,
            seconds: 2,
          );
          _leaveAfterNotice();
        }
      case MutedByMuteAll():
        _log('🤫 Teacher muted all students');
        lp?.setMicrophoneEnabled(false);
        if (mounted) {
          _showPill(const Icon(Icons.mic_off, color: Colors.black, size: 18),
              AppLocalizations.of(context)!.teacherMutedMic,
              background: const Color(0xFFEBB937), foreground: Colors.black);
        }
      case MicMutedByTeacher():
        _log('🤫 Teacher muted your mic');
        lp?.setMicrophoneEnabled(false);
        if (mounted) {
          _showPill(const Icon(Icons.mic_off, color: Colors.black, size: 18),
              AppLocalizations.of(context)!.teacherMutedMic,
              background: const Color(0xFFEBB937), foreground: Colors.black);
        }
      case CameraDisabledByTeacher():
        _log('🙈 Teacher disabled your camera');
        lp?.setCameraEnabled(false);
        if (mounted) {
          _showPill(const Icon(Icons.videocam_off, color: Colors.black, size: 18),
              AppLocalizations.of(context)!.teacherDisabledCamera,
              background: const Color(0xFFEBB937), foreground: Colors.black);
        }
      case KickedByTeacher():
        _log('🛑 Kicked by instructor');
        if (mounted) {
          _showPill(const Icon(Icons.person_remove, color: Colors.white, size: 18),
              AppLocalizations.of(context)!.kickedFromMeeting,
              background: Colors.redAccent, foreground: Colors.white, seconds: 2);
          _leaveAfterNotice();
        }
    }
  }

  // Token/server can be refreshed on "Rejoin" (the original token expires after 4h,
  // and a kicked participant must be re-checked by the server).
  late String _token = widget.token;
  late String _serverUrl = widget.serverUrl;

  Future<bool> _refreshToken() async {
    try {
      final fresh = await _backend.fetchToken();
      _token = fresh.token;
      _serverUrl = fresh.serverUrl;
      return true;
    } catch (e) {
      _log('❌ Could not refresh token for rejoin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rejoin: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
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
          params: VideoParametersPresets.h1080_169,
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
        final decision = DisconnectPolicy.decide(event.reason, isEndingMeeting: _isEndingMeeting);
        switch (decision) {
          case DisconnectDecision.ignore:
            _log('🔴 Ignoring disconnect UI because meeting is ending gracefully');
          case DisconnectDecision.leaveMeetingEnded:
          case DisconnectDecision.leaveKicked:
            // Server-enforced ending (room deleted / we were removed): leave, no "Rejoin".
            _isEndingMeeting = true;
            if (mounted) {
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(decision == DisconnectDecision.leaveMeetingEnded
                      ? l10n.teacherEndedMeeting
                      : l10n.kickedFromMeeting),
                  duration: const Duration(seconds: 2),
                ),
              );
              _leaveAfterNotice();
            }
          case DisconnectDecision.showReconnectOverlay:
            if (mounted) {
              setState(() {
                _isReconnecting = false;
                _isDisconnected = true;
              });
            }
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
      ..on<RoomRecordingStatusChanged>((e) {
        _log('⏺️ Server RoomRecordingStatusChanged: activeRecording=${e.activeRecording}');
        if (mounted) {
          setState(() {
            _isRecording = e.activeRecording;
          });
        }
      })
      ..on<LocalTrackPublishedEvent>((e) {
        _log('📤 Local track published: ${e.publication.kind}');
        // Teacher turned on their mic or camera on the app — start recording
        // if it hasn't started yet. The _isRecording guard inside _startRecording()
        // ensures this can never create a duplicate recording.
        if (widget.isTeacher && !_isRecording) {
          _log('🎬 Local track published — triggering recording start.');
          _startRecording();
        }
        _sortParticipants();
      })
      ..on<LocalTrackUnpublishedEvent>((e) {
        _log('📤 Local track unpublished: ${e.publication.kind}');
        _sortParticipants();
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
        _log('📶 Connection quality updated for ${e.participant.identity}: ${e.connectionQuality}');
        if (e.participant == _room?.localParticipant) {
          _resilienceController.handleConnectionQualityUpdate(
            e.connectionQuality,
            _promptAudioOnlyMode,
          );
        }
      })
      ..on<ActiveSpeakersChangedEvent>((e) {
        if (mounted) {
          setState(() {
            // Trigger rebuild to update PiP track if someone starts speaking
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
        // All protocol + security decisions live in MeetMessageHandler (unit-tested);
        // this listener only performs the resulting side effects.
        final action = MeetMessageHandler(
          localIdentity: _room?.localParticipant?.identity,
          isTeacher: widget.isTeacher,
          teacherId: widget.teacherId,
        ).handle(
          e.data,
          senderIdentity: e.participant?.identity,
          senderMetadata: e.participant?.metadata,
        );
        _applyMeetAction(action);
      });

    final startTime = DateTime.now().millisecondsSinceEpoch;
    bool connected = false;
    try {
      _log('Calling room.connect($_serverUrl)');
      await room.connect(
        _serverUrl,
        _token,
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
      connected = true;
    } catch (e, st) {
      _log('❌ CONNECT ERROR: $e');
      _log('[TELEMETRY] ConnectFailed | ErrorType: ${e.runtimeType}');
      
      if (_resilienceController.shouldRetryWithRelay(e)) {
        _log('🔄 Triggering ICE Relay Fallback over TCP/TLS...');
        _log('[TELEMETRY] IceRelayFallbackTriggered');
        try {
          await room.connect(
            _serverUrl,
            _token,
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
          connected = true;
        } catch (relayError) {
          _log('❌ ICE Relay Fallback failed: $relayError');
          _log('[TELEMETRY] IceRelayFallbackFailed');
          _handleConnectFailure(e, st);
        }
      } else {
        _handleConnectFailure(e, st);
      }
    }

    // Runs OUTSIDE the connect try/catch: a camera/mic/permission error after a successful
    // connection must not be mistaken for a network failure and trigger a relay reconnect.
    if (connected) {
      try {
        await _postConnectSetup(room, startTime);
      } catch (e) {
        _log('⚠️ Post-connect setup error (still connected): $e');
        if (mounted) {
          setState(() { _isConnected = true; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Camera/microphone error: $e'), backgroundColor: Colors.orange),
          );
        }
      }
    }
  }

  Future<void> _postConnectSetup(Room room, int startTime) async {
    if (!mounted) {
      _log('Widget unmounted after connection — aborting');
      return;
    }
    _log('✅ Connection established — room state: ${room.connectionState}');
    
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
    
    if (mounted) {
      final joinTime = DateTime.now().millisecondsSinceEpoch - startTime;
      _log('[TELEMETRY] ConnectSuccess | OS: ${Theme.of(context).platform.name} | Region/Course: ${widget.courseId} | JoinTime: ${joinTime}ms');
    }
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

    // 🛡️ INTERRUPTION RESILIENCE:
    // Never cut the camera on transient 'inactive' state (e.g. incoming phone call banner, notification shade, control center).
    // For students: mute camera if app is fully paused to background to conserve bandwidth.
    // For teachers: keep camera alive even if paused so live recording never terminates prematurely.
    if (state == AppLifecycleState.paused) {
      if (LifecycleCameraPolicy.shouldDisableCameraOnPause(
          isTeacher: widget.isTeacher,
          cameraEnabled: _room!.localParticipant?.isCameraEnabled() == true)) {
        _log('Student app backgrounded: Muting camera to prevent frozen frames');
        _wasCameraEnabledBeforeBackground = true;
        await _room!.localParticipant?.setCameraEnabled(false);
      } else {
        _wasCameraEnabledBeforeBackground = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      // App foregrounded. 
      _log('App resumed: Reconnecting UI if needed');
      if (LifecycleCameraPolicy.shouldRestoreCameraOnResume(
          disabledOnPause: _wasCameraEnabledBeforeBackground, audioOnlyMode: _isAudioOnlyMode)) {
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
    SecurityService().disableScreenshotProtection();
    _audioPlayer.dispose();
    _durationTimer?.cancel();
    _controlsTimer?.cancel();
    _resilienceController.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.stopService();
    _logScroll.dispose();
    _log('dispose() called — meeting page is closing');
    if (widget.isTeacher && _isRecording) {
      // Non-blocking fail-safe call to ensure recording buffer is flushed and saved
      _backend.stopRecording().catchError((Object e) {
        debugPrint('Fail-safe recording stop error in dispose: $e');
      });
    }
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
    if (!mounted) return;
    final lp = _room?.localParticipant;
    final audioTrackSid = lp?.audioTrackPublications.firstOrNull?.sid;
    final videoTrackSid = lp?.videoTrackPublications.firstOrNull?.sid;

    switch (RecordingPolicy.evaluate(
      isTeacher: widget.isTeacher,
      isRecording: _isRecording,
      audioTrackSid: audioTrackSid,
      videoTrackSid: videoTrackSid,
    )) {
      case RecordingStartDecision.notTeacher:
      case RecordingStartDecision.alreadyRecording:
        return;
      case RecordingStartDecision.waitingForTracks:
        // LocalTrackPublishedEvent re-triggers this once the missing track appears.
        _log('⏳ Waiting for both tracks (audio=$audioTrackSid, video=$videoTrackSid). Recording starts automatically once camera & mic are both enabled.');
        return;
      case RecordingStartDecision.start:
        break;
    }

    // Lock synchronously (before any await) so two events can never start two recordings.
    setState(() => _isRecording = true);

    try {
      final attempts = await _backend.startRecording(
        audioTrackSid: audioTrackSid!,
        videoTrackSid: videoTrackSid!,
        shouldContinue: () => mounted,
      );
      _log('✅ Recording started successfully (attempt $attempts/${RecordingPolicy.maxStartAttempts})');
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.recordingStarted,
          message: AppLocalizations.of(context)!.classIsBeingRecorded,
          type: MessengerType.success,
        );
      }
    } catch (e) {
      _log('❌ Recording failed: $e');
      if (mounted) {
        // Release the lock so the event listeners can retry automatically
        setState(() => _isRecording = false);
        AppMessenger.showSnackBar(
          context,
          title: AppLocalizations.of(context)!.recordingError,
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    }
  }

  // ── Leave Confirmation Dialog ────────────────────────────────────────
  Future<void> _showLeaveConfirmation() async {
    final l10n = AppLocalizations.of(context)!;

    if (widget.isTeacher) {
      final choice = await showDialog<String>(
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
            l10n.meetTeacherLeaveOrEnd,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('leave'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
              child: Text(l10n.meetLeaveOnly),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('end_all'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.endForAll, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (choice == 'end_all') {
        await _endMeetingForAll();
      } else if (choice == 'leave' && mounted) {
        _log('☎️ Teacher confirmed leave without ending meeting for others');
        if (_isRecording) {
          _log('☁️ Teacher leaving room — stopping recording...');
          if (await _moderateOnServer(MeetModerationAction.stopRecording)) {
            _isRecording = false; // skip the redundant dispose() fail-safe
          }
        }
        if (mounted) Navigator.pop(context);
      }
      return;
    }

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
      if (mounted) Navigator.pop(context);
    }
  }

  // ── End Meeting for All (Teacher only) ────────────────────────────────
  // The teacher already chose "End for all" in the leave dialog, so no second confirmation.
  Future<void> _endMeetingForAll() async {
    if (mounted) {
      _log('🛑 Teacher ending meeting for all participants');
      _isEndingMeeting = true;
      // The server stops the recording, lets it flush, then deletes the room (~5-10s):
      // show progress so the teacher doesn't think the app froze.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator(color: Color(0xFFEBB937))),
        ),
      );
      
      // 1. Send "end meeting" signal via LiveKit data channel as a UI fallback FIRST
      // This ensures students receive the command to gracefully exit before the room is forcefully deleted.
      try {
        await _room?.localParticipant?.publishData(
          MeetProtocol.encode(MeetProtocol.endMeetingMessage()),
          reliable: true,
        );
        // Small delay to let the message propagate before we disconnect
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        _log('⚠️ Failed to send end-meeting signal: $e');
      }

      // 2. Tell the server to forcibly delete the room and stop all recordings
      try {
        _log('☁️ Calling Cloud Function to delete room and stop egress...');
        // end_room = stop recording + delete the LiveKit room, which disconnects
        // every participant server-side (works even if they missed the data message).
        await _backend.endRoom();
        _log('✅ Cloud Function executed successfully.');
        _isRecording = false; // already stopped server-side; skip the dispose() fail-safe
      } catch (e) {
        _log('⚠️ Cloud Function failed: $e');
      }

      if (mounted) Navigator.pop(context); // close progress dialog
      if (mounted) Navigator.pop(context); // leave the meet page
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
                        color: const Color(0xFFEBB937).withValues(alpha: 0.15),
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
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Full-Screen Edge-to-Edge Video Stage ─────────────────────
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: _participantTracks.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context)!.waitingForOthersToJoin,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : (_isGridView ? _buildGridLayout() : _buildGoogleMeetLayout()),
          ),
        ),

        // ── 2. Full-Screen Tap Layer to Toggle Controls ─────────────────
        // Sits directly above the video stage to capture taps reliably even
        // when native VideoTrackRenderer / RTCVideoView is actively rendering.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleControls,
            child: const SizedBox.expand(),
          ),
        ),

        // ── 3. Floating Animated Top Bar ────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          top: _showControls ? 0 : -90,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showControls,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _showControls ? 1.0 : 0.0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
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
                              color: Colors.white.withValues(alpha: 0.15),
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
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
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
                              onPressed: () {
                                _startControlsTimer();
                                _startRecording();
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Grid / Focus layout toggle button
                          IconButton(
                            icon: Icon(
                              _isGridView ? Icons.featured_play_list_outlined : Icons.grid_view,
                              color: _isGridView ? const Color(0xFFEBB937) : Colors.white70,
                            ),
                            tooltip: _isGridView
                                ? AppLocalizations.of(context)!.meetSpeakerView
                                : AppLocalizations.of(context)!.meetGridView,
                            onPressed: () {
                              _startControlsTimer();
                              setState(() {
                                _isGridView = !_isGridView;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          // Leave or End for All button (depending on role)
                          IconButton(
                            icon: const Icon(Icons.call_end, color: Colors.red),
                            tooltip: widget.isTeacher ? AppLocalizations.of(context)!.endForAll : AppLocalizations.of(context)!.leave,
                            onPressed: () {
                              _startControlsTimer();
                              _showLeaveConfirmation();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── 4. Floating Animated Bottom Controls Pill ───────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          bottom: _showControls ? 14 : -90,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showControls,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _showControls ? 1.0 : 0.0,
              child: SafeArea(
                top: false,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ControlButton(
                          icon: _room?.localParticipant?.isMicrophoneEnabled() == true ? Icons.mic : Icons.mic_off,
                          isActive: _room?.localParticipant?.isMicrophoneEnabled() == true,
                          onTap: () async {
                            _startControlsTimer();
                            final p = _room?.localParticipant;
                            if (p != null) {
                              await p.setMicrophoneEnabled(!(p.isMicrophoneEnabled()));
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                        const SizedBox(width: 14),
                        _ControlButton(
                          icon: _room?.localParticipant?.isCameraEnabled() == true ? Icons.videocam : Icons.videocam_off,
                          isActive: _room?.localParticipant?.isCameraEnabled() == true,
                          onTap: () async {
                            _startControlsTimer();
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
                        if (_room?.localParticipant?.isCameraEnabled() == true) ...[
                          const SizedBox(width: 14),
                          _ControlButton(
                            icon: Icons.flip_camera_ios,
                            isActive: true,
                            onTap: () async {
                              _startControlsTimer();
                              setState(() {
                                _cameraPosition = _cameraPosition == CameraPosition.front 
                                    ? CameraPosition.back 
                                    : CameraPosition.front;
                              });
                              final p = _room?.localParticipant;
                              if (p != null) {
                                final pub = p.videoTrackPublications.firstWhereOrNull((pub) => pub.track is LocalVideoTrack);
                                final track = pub?.track;
                                if (track is LocalVideoTrack) {
                                  await track.restartTrack(CameraCaptureOptions(
                                    cameraPosition: _cameraPosition,
                                  ));
                                }
                              }
                            },
                          ),
                        ],
                        const SizedBox(width: 14),
                        // Way back out of audio-only mode (it was previously one-way).
                        if (_isAudioOnlyMode) ...[
                          _ControlButton(
                            icon: Icons.headset,
                            color: const Color(0xFFEBB937),
                            iconColor: Colors.black,
                            onTap: () {
                              _startControlsTimer();
                              _setAudioOnlyMode(false);
                            },
                          ),
                          const SizedBox(width: 14),
                        ],
                        if (widget.isTeacher)
                          _ControlButton(
                            icon: Icons.people,
                            isActive: true,
                            onTap: () {
                              _startControlsTimer();
                              _showParticipantsBottomSheet();
                            },
                          ),
                        if (!widget.isTeacher)
                          _ControlButton(
                            icon: Icons.pan_tool,
                            color: _isHandRaised ? const Color(0xFFEBB937) : Colors.white24,
                            iconColor: _isHandRaised ? Colors.black : Colors.white,
                            onTap: () {
                              _startControlsTimer();
                              _handleRaiseHand();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── 5. Debug Console Overlay ───────────────────────────────────
        _buildDebugConsole(),
      ],
    );
  }

  void _handleRaiseHand() async {
    final newState = !_isHandRaised;
    setState(() {
      _isHandRaised = newState;
      final lp = _room?.localParticipant;
      if (lp != null) {
        if (newState) {
          _raisedHands.add(lp.identity);
        } else {
          _raisedHands.remove(lp.identity);
        }
      }
    });
    
    final lp = _room?.localParticipant;
    if (lp != null) {
      final name = MeetProtocol.displayName(lp.name, lp.identity);
      await lp.publishData(
        MeetProtocol.encode(newState ? MeetProtocol.raiseHandMessage(name) : MeetProtocol.lowerHandMessage(name)),
        reliable: true,
      );
    }
  }

  void _showParticipantsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13151A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final localIdentity = _room?.localParticipant?.identity ?? '';
        final uniqueParticipants = <String, Participant>{};
        for (final t in _participantTracks) {
          uniqueParticipants[t.participant.identity] = t.participant;
        }
        final allParticipants = uniqueParticipants.values.toList();
        allParticipants.sort((a, b) {
          final aIsLocal = a.identity == localIdentity;
          final bIsLocal = b.identity == localIdentity;
          if (aIsLocal && !bIsLocal) return -1;
          if (!aIsLocal && bIsLocal) return 1;
          return 0;
        });

        // Track locally-muted participants so icons update instantly
        final mutedMic = <String, bool>{};
        final mutedCamera = <String, bool>{};

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> confirmAndMute(Participant p, bool isMic) async {
              final l10n = AppLocalizations.of(context)!;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E2028),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    l10n.confirmMuteTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    isMic ? l10n.confirmMuteMic : l10n.confirmMuteCamera,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.confirm),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                // Data message = friendly notice on the student's screen.
                // Server call = the actual enforcement (cannot be ignored by a modified client).
                await _room?.localParticipant?.publishData(
                  MeetProtocol.encode(MeetProtocol.muteMessage(p.identity, mic: isMic)),
                  reliable: true,
                );
                await _moderateOnServer(
                    isMic ? MeetModerationAction.muteMic : MeetModerationAction.muteCamera, p.identity);
                setSheetState(() {
                  if (isMic) {
                    mutedMic[p.identity] = true;
                  } else {
                    mutedCamera[p.identity] = true;
                  }
                });
              }
            }

            Future<void> confirmAndKick(Participant p) async {
              final l10n = AppLocalizations.of(context)!;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E2028),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    l10n.removeParticipantTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    l10n.removeParticipantConfirm,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l10n.confirm),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await _room?.localParticipant?.publishData(
                  MeetProtocol.encode(MeetProtocol.kickMessage(p.identity)),
                  reliable: true,
                );
                // Server removes the participant and blocks them from rejoining this session.
                await _moderateOnServer(MeetModerationAction.kick, p.identity);
              }
            }

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.participants,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${allParticipants.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (allParticipants.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.noOtherParticipants,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: allParticipants.length,
                        itemBuilder: (context, index) {
                          final p = allParticipants[index];
                          final isLocalUser = p.identity == localIdentity;
                          final name = p.name.isNotEmpty ? p.name : p.identity;

                          final String? avatar = MeetSenderVerifier.avatarFromMetadata(p.metadata);
                          final bool isModerator = MeetSenderVerifier.isModeratorMetadata(p.metadata);

                          // Local override: once we send a mute command, flip the icon immediately
                          final isMicOn = mutedMic.containsKey(p.identity) ? false : p.isMicrophoneEnabled();
                          final isCamOn = mutedCamera.containsKey(p.identity) ? false : p.isCameraEnabled();

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFEBB937),
                                  radius: 18,
                                  backgroundImage: avatar != null && avatar.isNotEmpty
                                      ? NetworkImage(avatar)
                                      : null,
                                  child: avatar == null || avatar.isEmpty
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                              color: Colors.black, fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          isLocalUser ? '$name ${AppLocalizations.of(context)!.youLabel}' : name,
                                          style: const TextStyle(color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isModerator) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blueAccent),
                                          ),
                                          child: Text(
                                            AppLocalizations.of(context)!.adminLabel,
                                            style: const TextStyle(
                                                color: Colors.blueAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_raisedHands.contains(p.identity)) ...[
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        // Teacher lowers the hand
                                        _room?.localParticipant?.publishData(
                                          MeetProtocol.encode(MeetProtocol.forceLowerHandMessage(p.identity)),
                                          reliable: true,
                                        );
                                        // Optimitic update
                                        setState(() {
                                          _raisedHands.remove(p.identity);
                                        });
                                        setSheetState(() {});
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.pan_tool, color: Color(0xFFEBB937), size: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                if (!isLocalUser) ...[
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => confirmAndMute(p, true),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          isMicOn ? Icons.mic : Icons.mic_off,
                                          color: isMicOn ? Colors.white : Colors.red,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => confirmAndMute(p, false),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          isCamOn ? Icons.videocam : Icons.videocam_off,
                                          color: isCamOn ? Colors.white : Colors.red,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.isTeacher) ...[
                                    const SizedBox(width: 4),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => confirmAndKick(p),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.person_remove,
                                            color: Colors.redAccent,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
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

  Widget _buildGridLayout() {
    if (_participantTracks.isEmpty) return const SizedBox();

    final count = _participantTracks.length;
    // Compute responsive columns for horizontal landscape mode
    final crossAxisCount = StageLayoutPolicy.gridColumns(count);

    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(
        12, 
        _showControls ? 70 : 12, 
        12, 
        _showControls ? 80 : 12,
      ),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 16 / 9,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final track = _participantTracks[index];
          final isHandRaised = _raisedHands.contains(track.participant.identity);
          final isTeacherTrack = track.participant == _room?.localParticipant 
              ? widget.isTeacher 
              : MeetSenderVerifier.isModeratorMetadata(track.participant.metadata);

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF13151A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTeacherTrack ? const Color(0xFFEBB937).withValues(alpha: 0.6) : Colors.white12,
                width: isTeacherTrack ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isGridView = false;
                });
              },
              child: ParticipantWidget(
                track: track,
                isHandRaised: isHandRaised,
                isPiP: true,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoogleMeetLayout() {
    if (_participantTracks.isEmpty) return const SizedBox();

    // Focus/PiP choice is a pure, unit-tested rule (StageLayoutPolicy).
    final selection = StageLayoutPolicy.select(
      [
        for (final t in _participantTracks)
          StageCandidate(
            identity: t.participant.identity,
            isLocal: t.participant == _room?.localParticipant,
            isScreenShare: t.videoTrack?.source == TrackSource.screenShareVideo,
            isModerator: MeetSenderVerifier.isModeratorMetadata(t.participant.metadata),
            isSpeaking: t.participant.isSpeaking,
            hasLiveVideo: t.videoTrack != null && !t.videoTrack!.muted,
          ),
      ],
      localIsTeacher: widget.isTeacher,
      activeSpeakerIdentity: _room?.activeSpeakers.firstOrNull?.identity,
    )!;
    final ParticipantTrack focusTrack = _participantTracks[selection.focusIndex];
    final ParticipantTrack? pipTrack =
        selection.pipIndex == null ? null : _participantTracks[selection.pipIndex!];

    return Stack(
      children: [
        // Main View (Teacher / Focus) - Takes up the entire screen edge-to-edge
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: ParticipantWidget(
              track: focusTrack,
              isHandRaised: _raisedHands.contains(focusTrack.participant.identity),
              isPiP: false,
            ),
          ),
        ),
        
        // Single Floating Participant PiP (Widescreen 16:9)
        if (pipTrack != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            bottom: _showControls ? 80 : 16,
            left: 16,
            child: Container(
              width: 120, // 16:9 PiP width
              height: 75, // 16:9 PiP height
              decoration: BoxDecoration(
                color: const Color(0xFF13151A),
                borderRadius: BorderRadius.circular(12),
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
              child: ParticipantWidget(
                track: pipTrack,
                isHandRaised: _raisedHands.contains(pipTrack.participant.identity),
                isPiP: true,
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
                    onPressed: () async {
                      _log('🔄 User pressed Rejoin button');
                      setState(() {
                        _isConnected = false;
                        _isDisconnected = false;
                        _isReconnecting = false;
                      });
                      if (await _refreshToken()) {
                        _connect();
                      } else if (mounted) {
                        Navigator.pop(context);
                      }
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
  final bool isHandRaised;
  final bool isPiP;

  const ParticipantWidget({
    Key? key,
    required this.track,
    this.isHandRaised = false,
    this.isPiP = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the name to display (fallback to identity if name is empty)
    final displayName = (track.participant.name.isNotEmpty)
        ? track.participant.name
        : track.participant.identity;

    // Parse metadata for avatar
    final String? avatarUrl = MeetSenderVerifier.avatarFromMetadata(track.participant.metadata);

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
      decoration: isPiP
          ? BoxDecoration(
              color: const Color(0xFF13151A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSpeaking
                    ? const Color(0xFF22C55E)
                    : (isHandRaised ? const Color(0xFFEBB937) : Colors.white24),
                width: isSpeaking || isHandRaised ? 2 : 1,
              ),
            )
          : const BoxDecoration(color: Colors.black),
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

              if (isCameraOn && liveVideoTrack != null) {
                return isPiP
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: VideoTrackRenderer(liveVideoTrack, fit: VideoViewFit.cover),
                      )
                    : VideoTrackRenderer(liveVideoTrack, fit: VideoViewFit.contain);
              } else {
                return Container(
                  color: const Color(0xFF13151A),
                  child: Center(
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? CircleAvatar(
                            radius: isPiP ? 20 : 48,
                            backgroundImage: NetworkImage(avatarUrl),
                          )
                        : CircleAvatar(
                            radius: isPiP ? 20 : 48,
                            backgroundColor: const Color(0xFFEBB937),
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: isPiP ? 16 : 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                  ),
                );
              }
            },
          ),

          // ── Connection Quality & Hand Raised Indicator (top-left) ──
          Positioned(
            top: 8,
            left: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(qualityIcon, color: qualityColor, size: isPiP ? 10 : 14),
                ),
                if (isHandRaised) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBB937),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.pan_tool, color: Colors.black, size: isPiP ? 10 : 14),
                  ),
                ],
              ],
            ),
          ),
            
          // Compact Floating Name Tag Overlay
          Positioned(
            bottom: isPiP ? 6 : 16,
            left: isPiP ? 6 : 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isPiP ? 6 : 10,
                    vertical: isPiP ? 3 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isPiP ? 80 : 160),
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: isPiP ? 10 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isMicOn) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.mic_off, color: Colors.white, size: isPiP ? 8 : 10),
                        ),
                      ],
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
  final Color? color;
  final Color iconColor;

  const _ControlButton({
    required this.icon, 
    required this.onTap, 
    this.isActive = true,
    this.color,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? (isActive ? Colors.white24 : Colors.red.withValues(alpha: 0.8)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class _WavingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _WavingIcon({required this.icon, required this.color, required this.size});

  @override
  State<_WavingIcon> createState() => _WavingIconState();
}

class _WavingIconState extends State<_WavingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: -0.1, end: 0.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}
