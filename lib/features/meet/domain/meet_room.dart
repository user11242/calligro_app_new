import 'meet_participant.dart';

/// Front-camera / back-camera, independent of the video SDK.
enum MeetCameraPosition { front, back }

/// Why the room disconnected (only the reasons the app reacts to differently).
enum MeetDisconnectReason {
  /// The teacher ended the class (room deleted on the server).
  roomDeleted,

  /// The server removed this participant (kick).
  participantRemoved,

  /// We disconnected on purpose.
  clientInitiated,

  /// Anything else: network loss, server restart, unknown…
  other,
}

enum MeetConnectionQuality { excellent, good, poor, unknown }

/// Join / leave chimes.
enum MeetSound { join, leave }

/// Events coming out of a [MeetRoom].
sealed class MeetRoomEvent {
  const MeetRoomEvent();
}

class RoomDisconnected extends MeetRoomEvent {
  final MeetDisconnectReason reason;
  const RoomDisconnected(this.reason);
}

class RoomReconnecting extends MeetRoomEvent {
  const RoomReconnecting();
}

class RoomReconnected extends MeetRoomEvent {
  const RoomReconnected();
}

class ParticipantJoined extends MeetRoomEvent {
  final String identity;
  const ParticipantJoined(this.identity);
}

class ParticipantLeft extends MeetRoomEvent {
  final String identity;
  const ParticipantLeft(this.identity);
}

/// Tracks were published/subscribed/muted, someone started speaking… —
/// re-read [MeetRoom.participants].
class ParticipantsChanged extends MeetRoomEvent {
  const ParticipantsChanged();
}

/// One of OUR tracks (mic/camera) was published.
class LocalTrackPublished extends MeetRoomEvent {
  const LocalTrackPublished();
}

/// The server's room-recording flag changed.
class RecordingStatusChanged extends MeetRoomEvent {
  final bool isRecording;
  const RecordingStatusChanged(this.isRecording);
}

/// Connection quality of OUR participant.
class LocalConnectionQualityChanged extends MeetRoomEvent {
  final MeetConnectionQuality quality;
  const LocalConnectionQualityChanged(this.quality);
}

/// A data-channel message. Sender is null when unknown.
class DataMessageReceived extends MeetRoomEvent {
  final List<int> data;
  final String? senderIdentity;
  final String? senderMetadata;
  const DataMessageReceived(this.data, {this.senderIdentity, this.senderMetadata});
}

/// The live class room, as Calligro Meet needs it.
///
/// The real implementation wraps LiveKit (data/livekit_meet_room.dart); tests use
/// a fake (test/features/meet/fakes/fake_meet_room.dart). Nothing outside
/// data/ may depend on LiveKit types — that's what makes the controller and the
/// page testable.
abstract interface class MeetRoom {
  Stream<MeetRoomEvent> get events;

  bool get isConnected;

  /// Our own identity / name (null / empty before connecting).
  String? get localIdentity;
  String get localName;

  bool get isMicrophoneEnabled;
  bool get isCameraEnabled;

  /// Server ids of our published mic / camera tracks (needed to start recording).
  String? get localAudioTrackSid;
  String? get localVideoTrackSid;

  /// Local participant first, then everyone else (screen shares included).
  List<MeetParticipant> get participants;

  /// Identity of the loudest current speaker, if any.
  String? get activeSpeakerIdentity;

  /// Connects. With [forceRelay] all media goes through TURN over TCP/TLS 443
  /// (for networks that block UDP).
  Future<void> connect(String url, String token, {bool forceRelay = false});

  /// True when a failed [connect] is worth retrying through the relay.
  bool shouldRetryWithRelay(Object error);

  Future<void> setMicrophoneEnabled(bool enabled);
  Future<void> setCameraEnabled(bool enabled, {MeetCameraPosition position = MeetCameraPosition.front});
  Future<void> switchCamera(MeetCameraPosition position);

  /// Zooms our own camera (1 = no zoom). The phone stops at its camera's own limit.
  /// Throws where the device cannot zoom (e.g. desktop).
  Future<void> setCameraZoom(double zoom);

  /// Focuses (and meters exposure for) our own camera on a spot of its picture:
  /// [x], [y] are fractions 0..1. Throws where the device cannot.
  Future<void> setCameraFocus(double x, double y);

  /// Sends a reliable data message to everyone in the room.
  Future<void> publish(Map<String, dynamic> message);

  /// Audio-only mode: stop (false) or resume (true) receiving other people's video,
  /// including video published later.
  Future<void> setRemoteVideoEnabled(bool enabled);

  Future<void> disconnect();
  Future<void> dispose();
}
