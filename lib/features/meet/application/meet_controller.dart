import 'dart:async';

import 'package:flutter/foundation.dart';

import 'connection_quality_monitor.dart';
import '../data/meet_backend.dart';
import '../domain/meet_message_handler.dart';
import '../domain/meet_participant.dart';
import '../domain/meet_policies.dart';
import '../domain/meet_protocol.dart';
import '../domain/meet_room.dart';
import 'recording_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State + one-shot UI effects
// ─────────────────────────────────────────────────────────────────────────────

enum MeetPhase {
  /// Connecting for the first time / after "Rejoin".
  connecting,
  connected,

  /// Connection dropped, LiveKit is trying to recover.
  reconnecting,

  /// Connection lost for good → "Rejoin" overlay.
  disconnected,

  /// Could not connect at all.
  failed,

  /// The class ended for us (ended, kicked, left) → the page closes.
  ended,
}

enum MeetNotice {
  handRaised,
  teacherEndedMeeting,
  mutedByTeacher,
  cameraDisabledByTeacher,
  kicked,
  recordingStarted,
  audioOnlyOn,
  audioOnlyOff,
}

/// Something the UI should do once (snackbar, sound, dialog, close the page).
sealed class MeetEffect {
  const MeetEffect();
}

class MeetNoticeEffect extends MeetEffect {
  final MeetNotice notice;

  /// Student name for [MeetNotice.handRaised].
  final String? name;
  const MeetNoticeEffect(this.notice, {this.name});
}

class MeetErrorEffect extends MeetEffect {
  final String message;
  const MeetErrorEffect(this.message);
}

class RecordingFailedEffect extends MeetEffect {
  final String message;
  const RecordingFailedEffect(this.message);
}

class PlaySoundEffect extends MeetEffect {
  final MeetSound sound;
  const PlaySoundEffect(this.sound);
}

class PromptAudioOnlyEffect extends MeetEffect {
  const PromptAudioOnlyEffect();
}

/// Close the meet page after [delay] (lets the user read the notice).
class LeaveMeetingEffect extends MeetEffect {
  final Duration delay;
  const LeaveMeetingEffect(this.delay);
}

/// What is on screen in the speaker layout.
class MeetStage {
  final MeetParticipant focus;
  final MeetParticipant? pip;
  const MeetStage(this.focus, this.pip);
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

/// Runs one live class for one user. The UI only reads state and calls methods;
/// every rule lives in the domain classes this delegates to.
class MeetController extends ChangeNotifier {
  final MeetRoom _room;
  final MeetBackend _backend;
  final bool isTeacher;
  final String? teacherId;
  final bool _startWithMic;
  final bool _startWithCamera;
  final ConnectionQualityMonitor _qualityMonitor;
  final Duration _connectGrace;
  final Duration _endMeetingSignalDelay;
  final Duration _leaveDelay;
  final void Function(String) _log;
  late final RecordingController _recording;

  String _token;
  String _serverUrl;

  MeetController({
    required MeetRoom room,
    required MeetBackend backend,
    required String token,
    required String serverUrl,
    required this.isTeacher,
    this.teacherId,
    bool startWithMic = false,
    bool startWithCamera = false,
    MeetCameraPosition cameraPosition = MeetCameraPosition.front,
    ConnectionQualityMonitor? qualityMonitor,
    Duration connectGrace = const Duration(milliseconds: 800),
    Duration endMeetingSignalDelay = const Duration(milliseconds: 500),
    Duration leaveDelay = const Duration(seconds: 2),
    void Function(String message)? log,
  })  : _room = room,
        _backend = backend,
        _token = token,
        _serverUrl = serverUrl,
        _startWithMic = startWithMic,
        _startWithCamera = startWithCamera,
        _cameraPosition = cameraPosition,
        _qualityMonitor = qualityMonitor ?? ConnectionQualityMonitor(),
        _connectGrace = connectGrace,
        _endMeetingSignalDelay = endMeetingSignalDelay,
        _leaveDelay = leaveDelay,
        _log = log ?? ((_) {}) {
    _recording = RecordingController(backend, isTeacher: isTeacher, log: _log);
    _subscription = _room.events.listen(_onRoomEvent);
  }

  late final StreamSubscription<MeetRoomEvent> _subscription;
  // Synchronous: listeners see an effect at the same moment the state changes.
  final _effects = StreamController<MeetEffect>.broadcast(sync: true);
  bool _disposed = false;

  // ── State ──────────────────────────────────────────────────────────────
  MeetPhase _phase = MeetPhase.connecting;
  MeetPhase get phase => _phase;

  DateTime? _connectedAt;
  DateTime? get connectedAt => _connectedAt;

  List<MeetParticipant> _participants = const [];
  List<MeetParticipant> get participants => _participants;

  final Set<String> _raisedHands = {};
  Set<String> get raisedHands => Set.unmodifiable(_raisedHands);

  bool _isHandRaised = false;
  bool get isHandRaised => _isHandRaised;

  bool get isRecording => _recording.isRecording;

  bool _isAudioOnly = false;
  bool get isAudioOnly => _isAudioOnly;

  MeetCameraPosition _cameraPosition;
  MeetCameraPosition get cameraPosition => _cameraPosition;

  bool get isMicrophoneEnabled => _room.isMicrophoneEnabled;
  bool get isCameraEnabled => _room.isCameraEnabled;
  String? get localIdentity => _room.localIdentity;

  /// Leaving on purpose (end for all / left / ended) → ignore disconnect noise.
  bool _isEnding = false;
  bool _cameraDisabledOnPause = false;

  Stream<MeetEffect> get effects => _effects.stream;

  /// Speaker layout: who is full-screen and who is the floating PiP.
  MeetStage? get stage {
    final sel = StageLayoutPolicy.select(
      [
        for (final p in _participants)
          StageCandidate(
            identity: p.identity,
            isLocal: p.isLocal,
            isScreenShare: p.isScreenShareTile,
            isModerator: p.isModerator,
            isSpeaking: p.isSpeaking,
            hasLiveVideo: p.hasLiveVideo,
          ),
      ],
      localIsTeacher: isTeacher,
      activeSpeakerIdentity: _room.activeSpeakerIdentity,
    );
    if (sel == null) return null;
    return MeetStage(_participants[sel.focusIndex], sel.pipIndex == null ? null : _participants[sel.pipIndex!]);
  }

  int get gridColumns => StageLayoutPolicy.gridColumns(_participants.length);

  // ── Joining ────────────────────────────────────────────────────────────
  Future<void> join() async {
    _setPhase(MeetPhase.connecting);
    if (_connectGrace > Duration.zero) await Future<void>.delayed(_connectGrace);
    if (_disposed) return;

    if (!await _connectWithRelayFallback()) {
      _setPhase(MeetPhase.failed);
      return;
    }

    // Separate from connecting: a camera/mic problem must not look like a network failure.
    try {
      if (_startWithCamera) await _room.setCameraEnabled(true, position: _cameraPosition);
    } catch (e) {
      _log('⚠️ Camera could not start: $e');
      _emit(MeetErrorEffect('Camera/microphone error: $e'));
    }
    try {
      if (_startWithMic) await _room.setMicrophoneEnabled(true);
    } catch (e) {
      _log('⚠️ Microphone could not start: $e');
      _emit(MeetErrorEffect('Camera/microphone error: $e'));
    }

    _connectedAt = DateTime.now();
    _refreshParticipants();
    _setPhase(MeetPhase.connected);
    if (isTeacher) await startRecording();
  }

  Future<bool> _connectWithRelayFallback() async {
    try {
      await _room.connect(_serverUrl, _token);
      return true;
    } catch (e) {
      _log('❌ Connect failed: $e');
      if (_room.shouldRetryWithRelay(e)) {
        try {
          _log('🔄 Retrying through the TURN relay (TCP/TLS 443)…');
          await _room.connect(_serverUrl, _token, forceRelay: true);
          return true;
        } catch (relayError) {
          _log('❌ Relay connect failed: $relayError');
        }
      }
      _emit(MeetErrorEffect('Failed to connect: $e'));
      return false;
    }
  }

  /// "Rejoin": a fresh token (the old one may have expired; a kicked user is refused).
  Future<void> rejoin() async {
    try {
      final fresh = await _backend.fetchToken();
      _token = fresh.token;
      _serverUrl = fresh.serverUrl;
    } catch (e) {
      _emit(MeetErrorEffect('Failed to rejoin: $e'));
      _endFor(const LeaveMeetingEffect(Duration.zero));
      return;
    }
    await join();
  }

  // ── Recording ──────────────────────────────────────────────────────────
  Future<void> startRecording() async {
    if (_disposed) return;
    final result = await _recording.start(
      audioTrackSid: _room.localAudioTrackSid,
      videoTrackSid: _room.localVideoTrackSid,
      shouldContinue: () => !_disposed,
    );
    if (_disposed) return;
    switch (result) {
      case RecordingStartResult.started:
        _emit(const MeetNoticeEffect(MeetNotice.recordingStarted));
      case RecordingStartResult.failed:
        _emit(RecordingFailedEffect(_recording.lastError ?? 'Recording failed'));
      case RecordingStartResult.skipped:
        break;
    }
    _notify();
  }

  // ── My mic / camera / hand ─────────────────────────────────────────────
  Future<void> toggleMicrophone() async {
    await _room.setMicrophoneEnabled(!_room.isMicrophoneEnabled);
    _refreshParticipants();
  }

  Future<void> toggleCamera() async {
    await _room.setCameraEnabled(!_room.isCameraEnabled, position: _cameraPosition);
    _refreshParticipants();
  }

  Future<void> flipCamera() async {
    _cameraPosition = _cameraPosition == MeetCameraPosition.front ? MeetCameraPosition.back : MeetCameraPosition.front;
    _notify();
    await _room.switchCamera(_cameraPosition);
  }

  Future<void> toggleHand() async {
    final raise = !_isHandRaised;
    final me = _room.localIdentity;
    _isHandRaised = raise;
    if (me != null) raise ? _raisedHands.add(me) : _raisedHands.remove(me);
    _notify();
    final name = MeetProtocol.displayName(_room.localName, me ?? '');
    await _room.publish(raise ? MeetProtocol.raiseHandMessage(name) : MeetProtocol.lowerHandMessage(name));
  }

  // ── Teacher moderation (data message = notice, server = enforcement) ───
  Future<bool> muteParticipant(String identity, {required bool mic}) async {
    await _room.publish(MeetProtocol.muteMessage(identity, mic: mic));
    return _moderate(mic ? MeetModerationAction.muteMic : MeetModerationAction.muteCamera, identity);
  }

  Future<bool> kick(String identity) async {
    await _room.publish(MeetProtocol.kickMessage(identity));
    return _moderate(MeetModerationAction.kick, identity);
  }

  Future<void> forceLowerHand(String identity) async {
    _raisedHands.remove(identity);
    _notify();
    await _room.publish(MeetProtocol.forceLowerHandMessage(identity));
  }

  Future<bool> _moderate(String action, String identity) async {
    try {
      await _backend.moderate(action, targetIdentity: identity);
      _log('✅ Server moderation "$action" for $identity');
      return true;
    } catch (e) {
      _log('❌ Server moderation "$action" failed: $e');
      _emit(MeetErrorEffect('Action failed: $e'));
      return false;
    }
  }

  // ── Leaving ────────────────────────────────────────────────────────────
  /// Leave the class (the class continues for everyone else).
  Future<void> leave() async {
    _isEnding = true;
    if (isTeacher) await _recording.stop();
    _setPhase(MeetPhase.ended);
  }

  /// Teacher: end the class for everyone.
  Future<void> endForAll() async {
    _isEnding = true;
    try {
      // UI fallback first, so students see the message before the room disappears.
      await _room.publish(MeetProtocol.endMeetingMessage());
      if (_endMeetingSignalDelay > Duration.zero) await Future<void>.delayed(_endMeetingSignalDelay);
    } catch (e) {
      _log('⚠️ Could not send end-meeting signal: $e');
    }
    try {
      // Stops the recording, then deletes the room → disconnects everyone server-side.
      await _backend.endRoom();
      _recording.markStoppedByServer();
    } catch (e) {
      _log('⚠️ end_room failed: $e');
    }
    _setPhase(MeetPhase.ended);
  }

  // ── Audio-only / app lifecycle ─────────────────────────────────────────
  Future<void> setAudioOnly(bool enabled) async {
    if (_isAudioOnly == enabled) return;
    _isAudioOnly = enabled;
    _notify();
    await _room.setRemoteVideoEnabled(!enabled);
    _emit(MeetNoticeEffect(enabled ? MeetNotice.audioOnlyOn : MeetNotice.audioOnlyOff));
  }

  /// Call when the audio-only prompt is dismissed (accepted or not).
  void audioOnlyPromptClosed() => _qualityMonitor.onPromptClosed();

  Future<void> onAppPaused() async {
    if (!_room.isConnected) return;
    _cameraDisabledOnPause = LifecycleCameraPolicy.shouldDisableCameraOnPause(
      isTeacher: isTeacher,
      cameraEnabled: _room.isCameraEnabled,
    );
    if (_cameraDisabledOnPause) {
      _log('App backgrounded: turning the camera off');
      await _room.setCameraEnabled(false);
    }
  }

  Future<void> onAppResumed() async {
    if (!_room.isConnected) return;
    if (LifecycleCameraPolicy.shouldRestoreCameraOnResume(
      disabledOnPause: _cameraDisabledOnPause,
      audioOnlyMode: _isAudioOnly,
    )) {
      _log('App resumed: restoring the camera');
      await _room.setCameraEnabled(true, position: _cameraPosition);
    }
    _cameraDisabledOnPause = false;
  }

  // ── Room events ────────────────────────────────────────────────────────
  void _onRoomEvent(MeetRoomEvent event) {
    if (_disposed) return;
    switch (event) {
      case RoomDisconnected(:final reason):
        _onDisconnected(reason);
      case RoomReconnecting():
        if (!_isEnding) _setPhase(MeetPhase.reconnecting);
      case RoomReconnected():
        if (!_isEnding) _setPhase(MeetPhase.connected);
      case ParticipantJoined():
        _emit(const PlaySoundEffect(MeetSound.join));
        _refreshParticipants();
      case ParticipantLeft():
        _emit(const PlaySoundEffect(MeetSound.leave));
        _refreshParticipants();
      case ParticipantsChanged():
        _refreshParticipants();
      case LocalTrackPublished():
        _refreshParticipants();
        if (isTeacher && !_recording.isRecording && _phase == MeetPhase.connected) startRecording();
      case RecordingStatusChanged(:final isRecording):
        _recording.syncFromServer(isRecording);
        _notify();
      case LocalConnectionQualityChanged(:final quality):
        _qualityMonitor.handleConnectionQualityUpdate(quality, () => _emit(const PromptAudioOnlyEffect()));
      case DataMessageReceived(:final data, :final senderIdentity, :final senderMetadata):
        _applyAction(MeetMessageHandler(
          localIdentity: _room.localIdentity,
          isTeacher: isTeacher,
          teacherId: teacherId,
        ).handle(data, senderIdentity: senderIdentity, senderMetadata: senderMetadata));
    }
  }

  void _onDisconnected(MeetDisconnectReason reason) {
    switch (DisconnectPolicy.decide(reason, isEndingMeeting: _isEnding)) {
      case DisconnectDecision.ignore:
        break;
      case DisconnectDecision.leaveMeetingEnded:
        _emit(const MeetNoticeEffect(MeetNotice.teacherEndedMeeting));
        _endFor(LeaveMeetingEffect(_leaveDelay));
      case DisconnectDecision.leaveKicked:
        _emit(const MeetNoticeEffect(MeetNotice.kicked));
        _endFor(LeaveMeetingEffect(_leaveDelay));
      case DisconnectDecision.showReconnectOverlay:
        _setPhase(MeetPhase.disconnected);
    }
  }

  void _applyAction(MeetAction action) {
    switch (action) {
      case IgnoreMessage(:final reason):
        if (reason == IgnoreReason.unauthorizedSender) _log('⚠️ Ignored a teacher-only command from a non-moderator');
      case HandRaised(:final identity, :final name):
        _raisedHands.add(identity);
        _notify();
        _emit(MeetNoticeEffect(MeetNotice.handRaised, name: name));
      case HandLowered(:final identity, :final isSelf):
        _raisedHands.remove(identity);
        if (isSelf) _isHandRaised = false;
        _notify();
      case HandForceLowered(:final targetId, :final isSelf):
        _raisedHands.remove(targetId);
        if (isSelf) {
          _isHandRaised = false;
          // Re-broadcast a normal lower_hand so every client stays in sync.
          _room.publish(MeetProtocol.lowerHandMessage(
              MeetProtocol.displayName(_room.localName, _room.localIdentity ?? '')));
        }
        _notify();
      case MeetingEndedByTeacher():
        _emit(const MeetNoticeEffect(MeetNotice.teacherEndedMeeting));
        _endFor(LeaveMeetingEffect(_leaveDelay));
      case MutedByMuteAll():
      case MicMutedByTeacher():
        _room.setMicrophoneEnabled(false).then((_) => _refreshParticipants());
        _emit(const MeetNoticeEffect(MeetNotice.mutedByTeacher));
      case CameraDisabledByTeacher():
        _room.setCameraEnabled(false).then((_) => _refreshParticipants());
        _emit(const MeetNoticeEffect(MeetNotice.cameraDisabledByTeacher));
      case KickedByTeacher():
        _emit(const MeetNoticeEffect(MeetNotice.kicked));
        _endFor(LeaveMeetingEffect(_leaveDelay));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  void _endFor(LeaveMeetingEffect leave) {
    _isEnding = true;
    _setPhase(MeetPhase.ended);
    _emit(leave);
  }

  void _refreshParticipants() {
    if (_disposed) return;
    _participants = _room.participants;
    _notify();
  }

  void _setPhase(MeetPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _emit(MeetEffect effect) {
    if (!_disposed && !_effects.isClosed) _effects.add(effect);
  }

  @override
  void dispose() {
    _disposed = true;
    // Fail-safe: the teacher's app closed while recording → stop it (NOT end the class).
    if (isTeacher) _recording.stopInBackground();
    _qualityMonitor.dispose();
    _subscription.cancel();
    _effects.close();
    _room.dispose();
    super.dispose();
  }
}
