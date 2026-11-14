import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:livekit_client/livekit_client.dart';

import '../domain/meet_participant.dart';
import '../domain/meet_room.dart';

/// [MeetRoom] backed by LiveKit. This is the ONLY place in Calligro Meet that
/// talks to the LiveKit SDK (adapter pattern).
class LiveKitMeetRoom implements MeetRoom {
  LiveKitMeetRoom({void Function(String)? log}) : _log = log ?? ((_) {});

  final void Function(String) _log;
  final _events = StreamController<MeetRoomEvent>.broadcast();

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _remoteVideoEnabled = true;

  // Calligraphy needs sharp pen strokes: capture 1080p, publish up to 6 Mbps with
  // simulcast (students get lighter layers), keep resolution when bandwidth drops.
  static RoomOptions _roomOptions() => const RoomOptions(
        defaultCameraCaptureOptions: CameraCaptureOptions(
          params: VideoParametersPresets.h1080_169,
          maxFrameRate: 30,
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          videoEncoding: VideoEncoding(maxBitrate: 6000000, maxFramerate: 30),
          simulcast: true,
          degradationPreference: DegradationPreference.maintainResolution,
          videoCodec: 'h264',
          backupVideoCodec: BackupVideoCodec(codec: 'vp8'),
        ),
        // DTX saves bandwidth in silence; RED resends audio so drops don't cut speech.
        defaultAudioPublishOptions: AudioPublishOptions(dtx: true, red: true),
        defaultAudioCaptureOptions: AudioCaptureOptions(
          noiseSuppression: true,
          echoCancellation: true,
          autoGainControl: true,
          typingNoiseDetection: true,
        ),
        defaultAudioOutputOptions: AudioOutputOptions(speakerOn: true),
        adaptiveStream: true,
        dynacast: true,
      );

  // Longer than the 10s defaults: students on slow 3G/4G worldwide.
  static const _timeouts = Timeouts(
    connection: Duration(seconds: 30),
    debounce: Duration(milliseconds: 20),
    publish: Duration(seconds: 15),
    subscribe: Duration(seconds: 15),
    peerConnection: Duration(seconds: 30),
    iceRestart: Duration(seconds: 15),
  );

  @override
  Stream<MeetRoomEvent> get events => _events.stream;

  @override
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  LocalParticipant? get _local => _room?.localParticipant;

  @override
  String? get localIdentity => _local?.identity;
  @override
  String get localName => _local?.name ?? '';
  @override
  bool get isMicrophoneEnabled => _local?.isMicrophoneEnabled() ?? false;
  @override
  bool get isCameraEnabled => _local?.isCameraEnabled() ?? false;
  @override
  String? get localAudioTrackSid => _local?.audioTrackPublications.firstOrNull?.sid;
  @override
  String? get localVideoTrackSid => _local?.videoTrackPublications.firstOrNull?.sid;
  @override
  String? get activeSpeakerIdentity => _room?.activeSpeakers.firstOrNull?.identity;

  @override
  List<MeetParticipant> get participants {
    final room = _room;
    if (room == null) return const [];
    return [
      if (room.localParticipant != null) ..._tiles(room.localParticipant!, isLocal: true),
      for (final p in room.remoteParticipants.values) ..._tiles(p, isLocal: false),
    ];
  }

  Iterable<MeetParticipant> _tiles(Participant p, {required bool isLocal}) sync* {
    final camera = p.videoTrackPublications.firstWhereOrNull((pub) => pub.source == TrackSource.camera);
    final screen = p.videoTrackPublications.firstWhereOrNull((pub) => pub.source == TrackSource.screenShareVideo);
    MeetParticipant tile(TrackPublication? pub, {bool isScreen = false}) => MeetParticipant(
          identity: p.identity,
          name: p.name,
          metadata: p.metadata,
          isLocal: isLocal,
          isSpeaking: p.isSpeaking,
          isMicrophoneEnabled: p.isMicrophoneEnabled(),
          isCameraEnabled: p.isCameraEnabled(),
          connectionQuality: _quality(p.connectionQuality),
          video: pub?.track is VideoTrack
              ? MeetVideo(pub!.track!, isScreenShare: isScreen, isMuted: pub.muted)
              : null,
        );
    yield tile(camera);
    if (!isLocal && screen?.track != null) yield tile(screen, isScreen: true);
  }

  static MeetConnectionQuality _quality(ConnectionQuality q) => switch (q) {
        ConnectionQuality.excellent => MeetConnectionQuality.excellent,
        ConnectionQuality.good => MeetConnectionQuality.good,
        ConnectionQuality.poor => MeetConnectionQuality.poor,
        _ => MeetConnectionQuality.unknown,
      };

  static MeetDisconnectReason _reason(DisconnectReason? r) => switch (r) {
        DisconnectReason.roomDeleted => MeetDisconnectReason.roomDeleted,
        DisconnectReason.participantRemoved => MeetDisconnectReason.participantRemoved,
        DisconnectReason.clientInitiated => MeetDisconnectReason.clientInitiated,
        _ => MeetDisconnectReason.other,
      };

  /// Always 1080p@30 — passing only the position would drop the room's 1080p default.
  static CameraCaptureOptions _capture(MeetCameraPosition p) => CameraCaptureOptions(
        cameraPosition: p == MeetCameraPosition.back ? CameraPosition.back : CameraPosition.front,
        params: VideoParametersPresets.h1080_169,
        maxFrameRate: 30,
      );

  @override
  Future<void> connect(String url, String token, {bool forceRelay = false}) async {
    await _teardown();
    final room = Room(roomOptions: _roomOptions());
    _room = room;
    _listen(room);
    _log('Connecting to $url${forceRelay ? ' (forced TURN relay)' : ''}');
    await room.connect(
      url,
      token,
      connectOptions: ConnectOptions(
        timeouts: _timeouts,
        // Relay: all media through TURN over TCP/TLS 443 — passes strict firewalls.
        rtcConfiguration: forceRelay
            ? const RTCConfiguration(iceTransportPolicy: RTCIceTransportPolicy.relay)
            : const RTCConfiguration(),
      ),
    );
  }

  void _listen(Room room) {
    void emit(MeetRoomEvent e) {
      if (!_events.isClosed) _events.add(e);
    }

    _listener = room.createListener()
      ..on<RoomDisconnectedEvent>((e) => emit(RoomDisconnected(_reason(e.reason))))
      ..on<RoomReconnectingEvent>((_) => emit(const RoomReconnecting()))
      ..on<RoomReconnectedEvent>((_) => emit(const RoomReconnected()))
      ..on<ParticipantConnectedEvent>((e) => emit(ParticipantJoined(e.participant.identity)))
      ..on<ParticipantDisconnectedEvent>((e) => emit(ParticipantLeft(e.participant.identity)))
      ..on<TrackSubscribedEvent>((e) {
        if (!_remoteVideoEnabled && e.track.kind == TrackType.VIDEO) {
          _log('Audio-only: unsubscribing new video from ${e.participant.identity}');
          e.publication.unsubscribe();
        }
        emit(const ParticipantsChanged());
      })
      ..on<TrackUnsubscribedEvent>((_) => emit(const ParticipantsChanged()))
      ..on<TrackMutedEvent>((_) => emit(const ParticipantsChanged()))
      ..on<TrackUnmutedEvent>((_) => emit(const ParticipantsChanged()))
      ..on<ActiveSpeakersChangedEvent>((_) => emit(const ParticipantsChanged()))
      ..on<LocalTrackUnpublishedEvent>((_) => emit(const ParticipantsChanged()))
      ..on<LocalTrackPublishedEvent>((_) => emit(const LocalTrackPublished()))
      ..on<RoomRecordingStatusChanged>((e) => emit(RecordingStatusChanged(e.activeRecording)))
      ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
        if (e.participant == room.localParticipant) {
          emit(LocalConnectionQualityChanged(_quality(e.connectionQuality)));
        }
        emit(const ParticipantsChanged());
      })
      ..on<DataReceivedEvent>((e) => emit(DataMessageReceived(
            e.data,
            senderIdentity: e.participant?.identity,
            senderMetadata: e.participant?.metadata,
          )));
  }

  @override
  bool shouldRetryWithRelay(Object error) => isRelayRetryable(error);

  /// Is a failed connect worth retrying through the TURN relay?
  /// Network / timeout / ICE problems: yes. Bad token or encryption keys: no.
  static bool isRelayRetryable(Object error) {
    if (error is ConnectException) return error.reason != ConnectionErrorReason.NotAllowed;
    if (error is TimeoutException || error is NegotiationError) return true;
    if (error is LiveKitE2EEException) return false;
    return true; // unknown (e.g. socket errors): worth one relay attempt
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async => _local?.setMicrophoneEnabled(enabled);

  @override
  Future<void> setCameraEnabled(bool enabled, {MeetCameraPosition position = MeetCameraPosition.front}) async {
    await _local?.setCameraEnabled(
      enabled,
      cameraCaptureOptions: enabled ? _capture(position) : null,
    );
  }

  @override
  Future<void> switchCamera(MeetCameraPosition position) async {
    final track = _local?.videoTrackPublications
        .firstWhereOrNull((pub) => pub.track is LocalVideoTrack && pub.source == TrackSource.camera)
        ?.track;
    if (track is LocalVideoTrack) {
      await track.restartTrack(_capture(position));
    }
  }

  @override
  Future<void> publish(Map<String, dynamic> message) async {
    await _local?.publishData(utf8.encode(jsonEncode(message)), reliable: true);
  }

  @override
  Future<void> setRemoteVideoEnabled(bool enabled) async {
    _remoteVideoEnabled = enabled;
    for (final p in _room?.remoteParticipants.values ?? const <RemoteParticipant>[]) {
      for (final pub in p.videoTrackPublications) {
        enabled ? await pub.subscribe() : await pub.unsubscribe();
      }
    }
  }

  @override
  Future<void> disconnect() async => _room?.disconnect();

  Future<void> _teardown() async {
    try {
      await _listener?.dispose();
      _listener = null;
      await _room?.disconnect();
      await _room?.dispose();
    } catch (e) {
      _log('Room cleanup error (ignored): $e');
    }
    _room = null;
  }

  @override
  Future<void> dispose() async {
    await _teardown();
    await _events.close();
  }
}
