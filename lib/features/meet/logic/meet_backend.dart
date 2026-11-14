import 'package:cloud_functions/cloud_functions.dart';

import 'meet_policies.dart';

/// Calls a Cloud Function by name and returns its `data`.
typedef MeetCallable = Future<Object?> Function(String functionName, Map<String, dynamic> data);

/// Waits between retries (injectable so tests run instantly).
typedef MeetDelay = Future<void> Function(Duration duration);

/// Moderation actions understood by `livekit-moderateParticipant`.
class MeetModerationAction {
  MeetModerationAction._();
  static const muteMic = 'mute_mic';
  static const muteCamera = 'mute_camera';
  static const kick = 'kick';
  static const muteAll = 'mute_all';
  static const stopRecording = 'stop_recording';
  static const endRoom = 'end_room';
}

class MeetToken {
  final String token;
  final String serverUrl;
  final String roomName;
  final String? teacherId;
  const MeetToken({required this.token, required this.serverUrl, required this.roomName, this.teacherId});
}

class PlaybackInfo {
  /// Signed URL of the original recording.
  final String url;

  /// Signed URL per quality label ("1080p" = original, plus available renditions).
  final Map<String, String> qualities;
  const PlaybackInfo({required this.url, required this.qualities});
}

/// Every Cloud Function call made by Calligro Meet, in one place.
///
/// Function names, regions and payload shapes are part of the contract with
/// functions/livekit.js and are pinned by test/features/meet/meet_backend_test.dart.
class MeetBackend {
  static const region = 'us-central1';
  static const tokenFunction = 'livekit-generateLiveKitToken';
  static const moderateFunction = 'livekit-moderateParticipant';
  static const startRecordingFunction = 'livekit-startAutomatedRecording';
  static const playbackUrlFunction = 'livekit-getRecordingPlaybackUrl';

  final String courseId;
  final MeetCallable _call;
  final MeetDelay _delay;

  MeetBackend({required this.courseId, MeetCallable? call, MeetDelay? delay})
      : _call = call ?? _firebaseCall,
        _delay = delay ?? Future<void>.delayed;

  static Future<Object?> _firebaseCall(String name, Map<String, dynamic> data) async {
    final result = await FirebaseFunctions.instanceFor(region: region).httpsCallable(name).call(data);
    return result.data;
  }

  /// New LiveKit token (used on join and on "Rejoin"). The mobile app always
  /// identifies as `source: mobile` (the teacher's mobile identity gets `_mobile`).
  Future<MeetToken> fetchToken() async {
    final data = await _call(tokenFunction, {'courseId': courseId, 'source': 'mobile'});
    if (data is! Map) throw const FormatException('Token response is not a map');
    final token = data['token'], serverUrl = data['serverUrl'], roomName = data['roomName'];
    if (token is! String || serverUrl is! String || roomName is! String) {
      throw const FormatException('Token response is missing token/serverUrl/roomName');
    }
    final teacherId = data['teacherId'];
    return MeetToken(
      token: token,
      serverUrl: serverUrl,
      roomName: roomName,
      teacherId: teacherId is String ? teacherId : null,
    );
  }

  /// Server-enforced moderation. [targetIdentity] is required for mute/kick.
  Future<void> moderate(String action, {String? targetIdentity}) async {
    const needsTarget = {MeetModerationAction.muteMic, MeetModerationAction.muteCamera, MeetModerationAction.kick};
    if (needsTarget.contains(action) && (targetIdentity == null || targetIdentity.isEmpty)) {
      throw ArgumentError('"$action" needs a targetIdentity');
    }
    await _call(moderateFunction, {
      'courseId': courseId,
      'action': action,
      if (targetIdentity != null) 'targetIdentity': targetIdentity,
    });
  }

  /// Stops the recording WITHOUT ending the class (teacher leaving / app closing).
  Future<void> stopRecording() => moderate(MeetModerationAction.stopRecording);

  /// Stops the recording AND deletes the LiveKit room (disconnects everyone).
  Future<void> endRoom() => moderate(MeetModerationAction.endRoom);

  /// Asks the server to start recording, retrying up to
  /// [RecordingPolicy.maxStartAttempts] times with growing backoff.
  /// [shouldContinue] stops retrying early (e.g. the page was closed).
  /// Returns the number of attempts used; rethrows the last error on failure.
  Future<int> startRecording({
    required String audioTrackSid,
    required String videoTrackSid,
    bool Function()? shouldContinue,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= RecordingPolicy.maxStartAttempts; attempt++) {
      if (shouldContinue != null && !shouldContinue()) break;
      try {
        await _call(startRecordingFunction, {
          'courseId': courseId,
          'audioTrackId': audioTrackSid,
          'videoTrackId': videoTrackSid,
          'orientation': RecordingPolicy.orientation,
        });
        return attempt;
      } catch (e) {
        lastError = e;
        final canRetry = attempt < RecordingPolicy.maxStartAttempts && (shouldContinue?.call() ?? true);
        if (canRetry) await _delay(RecordingPolicy.retryDelay(attempt));
      }
    }
    throw lastError ?? StateError('Recording start cancelled');
  }

  /// Short-lived signed playback URLs for one of this course's recordings:
  /// the original plus every transcoded quality that exists ("720p", "480p", "360p").
  Future<PlaybackInfo> playback(String recordingId) async {
    final data = await _call(playbackUrlFunction, {'courseId': courseId, 'recordingId': recordingId});
    final url = data is Map ? data['playbackUrl'] : null;
    if (url is! String || url.isEmpty) throw const FormatException('No playbackUrl in response');
    final qualities = <String, String>{};
    final raw = data is Map ? data['qualities'] : null;
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is String && v.isNotEmpty) qualities[k] = v;
      });
    }
    qualities.putIfAbsent('1080p', () => url);
    return PlaybackInfo(url: url, qualities: qualities);
  }
}
