import 'meet_protocol.dart';
import 'meet_room.dart';

/// A video stream that the UI can render. [handle] is opaque here (the real
/// room puts the SDK's track object in it; the renderer knows what to do).
class MeetVideo {
  final Object handle;
  final bool isScreenShare;
  final bool isMuted;

  /// Our own camera (its pinch gestures are the teacher's camera zoom, handled by the meet page).
  final bool isLocalCamera;
  const MeetVideo(this.handle, {this.isScreenShare = false, this.isMuted = false, this.isLocalCamera = false});
}

/// One tile on the stage: a participant's camera, or their screen share.
class MeetParticipant {
  final String identity;
  final String name;
  final String? metadata;
  final bool isLocal;
  final bool isSpeaking;
  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;
  final MeetConnectionQuality connectionQuality;

  /// The video of THIS tile (camera, or screen share when [isScreenShareTile]).
  final MeetVideo? video;

  const MeetParticipant({
    required this.identity,
    this.name = '',
    this.metadata,
    this.isLocal = false,
    this.isSpeaking = false,
    this.isMicrophoneEnabled = false,
    this.isCameraEnabled = false,
    this.connectionQuality = MeetConnectionQuality.unknown,
    this.video,
  });

  bool get isScreenShareTile => video?.isScreenShare ?? false;
  bool get isModerator => MeetSenderVerifier.isModeratorMetadata(metadata);
  String? get avatarUrl => MeetSenderVerifier.avatarFromMetadata(metadata);
  String get displayName => name.isNotEmpty ? name : identity;

  /// Camera tile with a live (present, unmuted) camera.
  bool get hasLiveVideo => video != null && !video!.isMuted;
}
