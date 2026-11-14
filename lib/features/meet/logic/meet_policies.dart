import 'package:livekit_client/livekit_client.dart' show DisconnectReason;

// ─────────────────────────────────────────────────────────────────────────────
// Small, pure decision rules used by the Calligro Meet page.
// Each one is unit-tested in test/features/meet/meet_policies_test.dart.
// ─────────────────────────────────────────────────────────────────────────────

/// What to do when the LiveKit room disconnects.
enum DisconnectDecision {
  /// We are already leaving on purpose (teacher ended / we left) — do nothing.
  ignore,

  /// The teacher ended the class (room deleted on the server) → message + leave.
  leaveMeetingEnded,

  /// The teacher removed us (server-side kick) → message + leave. No "Rejoin":
  /// the server blocks the kicked user from getting a new token anyway.
  leaveKicked,

  /// Any other drop (network, server restart…) → show the "Rejoin" overlay.
  showReconnectOverlay,
}

class DisconnectPolicy {
  DisconnectPolicy._();

  static DisconnectDecision decide(DisconnectReason? reason, {required bool isEndingMeeting}) {
    if (isEndingMeeting) return DisconnectDecision.ignore;
    if (reason == DisconnectReason.roomDeleted) return DisconnectDecision.leaveMeetingEnded;
    if (reason == DisconnectReason.participantRemoved) return DisconnectDecision.leaveKicked;
    return DisconnectDecision.showReconnectOverlay;
  }
}

/// Whether the teacher's app should ask the server to start recording.
enum RecordingStartDecision {
  /// Students never record.
  notTeacher,

  /// A recording is already running / starting — never start a second one.
  alreadyRecording,

  /// The server needs BOTH the mic and camera track. Wait silently; publishing
  /// the missing track re-triggers the check.
  waitingForTracks,

  start,
}

class RecordingPolicy {
  RecordingPolicy._();

  /// Calligro Meet is locked to landscape, so recordings always use the
  /// landscape encoding preset.
  static const orientation = 'landscape';

  static const maxStartAttempts = 3;

  /// Backoff before retry number [attempt] (1-based) → 1.2s, 2.4s, …
  static Duration retryDelay(int attempt) => Duration(milliseconds: 1200 * attempt);

  static RecordingStartDecision evaluate({
    required bool isTeacher,
    required bool isRecording,
    required String? audioTrackSid,
    required String? videoTrackSid,
  }) {
    if (!isTeacher) return RecordingStartDecision.notTeacher;
    if (isRecording) return RecordingStartDecision.alreadyRecording;
    if (audioTrackSid == null || videoTrackSid == null) return RecordingStartDecision.waitingForTracks;
    return RecordingStartDecision.start;
  }
}

/// Camera handling when the app goes to the background and comes back.
class LifecycleCameraPolicy {
  LifecycleCameraPolicy._();

  /// Students turn their camera off when the app is backgrounded (it would show a
  /// frozen frame). Teachers keep it on so the live recording never breaks.
  static bool shouldDisableCameraOnPause({required bool isTeacher, required bool cameraEnabled}) =>
      !isTeacher && cameraEnabled;

  /// Restore the camera on resume only if WE turned it off, and not in audio-only mode.
  static bool shouldRestoreCameraOnResume({required bool disabledOnPause, required bool audioOnlyMode}) =>
      disabledOnPause && !audioOnlyMode;
}

/// One tile candidate for the stage (a participant's camera or screen share).
class StageCandidate {
  final String identity;
  final bool isLocal;
  final bool isScreenShare;
  final bool isModerator;
  final bool isSpeaking;

  /// Has a video track that is present and not muted.
  final bool hasLiveVideo;

  const StageCandidate({
    required this.identity,
    this.isLocal = false,
    this.isScreenShare = false,
    this.isModerator = false,
    this.isSpeaking = false,
    this.hasLiveVideo = false,
  });
}

/// Which candidate goes full-screen and which one is the floating PiP.
class StageSelection {
  final int focusIndex;
  final int? pipIndex;
  const StageSelection(this.focusIndex, this.pipIndex);
}

class StageLayoutPolicy {
  StageLayoutPolicy._();

  /// Focus priority: screen share → the teacher (us if we teach, else any
  /// moderator) → the active speaker's camera → the first tile.
  /// PiP priority among the rest: someone speaking → someone with live video → first.
  /// Returns null when there is nothing to show.
  static StageSelection? select(
    List<StageCandidate> c, {
    required bool localIsTeacher,
    String? activeSpeakerIdentity,
  }) {
    if (c.isEmpty) return null;

    int focus = c.indexWhere((t) => t.isScreenShare);
    if (focus < 0) {
      focus = c.indexWhere((t) => (t.isLocal && localIsTeacher) || t.isModerator);
    }
    if (focus < 0 && activeSpeakerIdentity != null) {
      focus = c.indexWhere((t) => t.identity == activeSpeakerIdentity && !t.isScreenShare);
    }
    if (focus < 0) focus = 0;

    final rest = [for (var i = 0; i < c.length; i++) if (i != focus) i];
    int? pip;
    if (rest.isNotEmpty) {
      pip = rest.firstWhere((i) => c[i].isSpeaking, orElse: () => -1);
      if (pip < 0) pip = rest.firstWhere((i) => c[i].hasLiveVideo, orElse: () => -1);
      if (pip < 0) pip = rest.first;
    }
    return StageSelection(focus, pip);
  }

  /// Grid columns for the landscape gallery view.
  static int gridColumns(int tileCount) => tileCount <= 2 ? 2 : (tileCount <= 6 ? 3 : 4);
}
