import '../data/meet_backend.dart';
import '../domain/meet_policies.dart';

enum RecordingStartResult { started, skipped, failed }

/// Owns the "is this class being recorded?" state for the teacher's app and
/// guarantees a recording is never started twice.
class RecordingController {
  final MeetBackend _backend;
  final bool isTeacher;
  final void Function(String message) _log;

  RecordingController(this._backend, {required this.isTeacher, void Function(String)? log})
      : _log = log ?? ((_) {});

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Last failure message (when [start] returned [RecordingStartResult.failed]).
  String? lastError;

  /// Starts recording if the policy allows it. The flag is set synchronously
  /// before any await, so two events at once can never start two recordings.
  Future<RecordingStartResult> start({
    required String? audioTrackSid,
    required String? videoTrackSid,
    bool Function()? shouldContinue,
  }) async {
    final decision = RecordingPolicy.evaluate(
      isTeacher: isTeacher,
      isRecording: _isRecording,
      audioTrackSid: audioTrackSid,
      videoTrackSid: videoTrackSid,
    );
    if (decision != RecordingStartDecision.start) {
      if (decision == RecordingStartDecision.waitingForTracks) {
        _log('⏳ Recording waits for both mic and camera (audio=$audioTrackSid, video=$videoTrackSid)');
      }
      return RecordingStartResult.skipped;
    }

    _isRecording = true;
    try {
      final attempts = await _backend.startRecording(
        audioTrackSid: audioTrackSid!,
        videoTrackSid: videoTrackSid!,
        shouldContinue: shouldContinue,
      );
      _log('✅ Recording started (attempt $attempts/${RecordingPolicy.maxStartAttempts})');
      return RecordingStartResult.started;
    } catch (e) {
      _isRecording = false; // release the lock so a later event can retry
      lastError = e.toString();
      _log('❌ Recording failed: $e');
      return RecordingStartResult.failed;
    }
  }

  /// Stops the recording without ending the class. Returns true when stopped.
  Future<bool> stop() async {
    if (!_isRecording) return true;
    try {
      await _backend.stopRecording();
      _isRecording = false;
      return true;
    } catch (e) {
      _log('❌ Stop recording failed: $e');
      return false;
    }
  }

  /// The class was ended on the server (end_room also stops the recording).
  void markStoppedByServer() => _isRecording = false;

  /// Mirrors the server's room-recording flag.
  void syncFromServer(bool isRecording) => _isRecording = isRecording;

  /// Fire-and-forget stop used when the page closes unexpectedly.
  void stopInBackground() {
    if (!_isRecording) return;
    _isRecording = false;
    _backend.stopRecording().catchError((Object e) => _log('Fail-safe stop failed: $e'));
  }
}
