import 'dart:async';
import 'dart:convert';

import 'package:calligro_app/features/meet/domain/meet_participant.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';

/// A controllable, stateful stand-in for a live class room.
///
/// Tests drive it like the LiveKit server would ([emit], [addRemote], [receive])
/// and inspect what the app did ([published], [connects], mic/camera state…).
class FakeMeetRoom implements MeetRoom {
  final _events = StreamController<MeetRoomEvent>.broadcast();

  // ── Behaviour knobs ────────────────────────────────────────────────────
  /// Errors thrown by successive connect() calls (null = success).
  final List<Object?> connectResults = [];
  bool retryWithRelay = true;
  String identityOnConnect = 's1';
  String nameOnConnect = 'Student One';
  String? metadataOnConnect = '{"role":"participant","teacherId":"T1"}';
  Object? cameraError;

  // ── Recorded calls / state ─────────────────────────────────────────────
  final connects = <({String url, String token, bool forceRelay})>[];
  final published = <Map<String, dynamic>>[];
  final cameraPositions = <MeetCameraPosition>[];
  int disconnectCalls = 0;
  bool disposed = false;
  bool remoteVideoEnabled = true;
  bool _connected = false;
  bool _mic = false;
  bool _camera = false;
  String? _identity;
  String _name = '';
  String? _metadata;
  final remotes = <MeetParticipant>[];
  @override
  String? activeSpeakerIdentity;

  @override
  Stream<MeetRoomEvent> get events => _events.stream;

  // ── Test drivers ───────────────────────────────────────────────────────
  void emit(MeetRoomEvent event) => _events.add(event);

  void addRemote(MeetParticipant p, {bool announce = true}) {
    remotes.add(p);
    if (announce) emit(ParticipantJoined(p.identity));
  }

  void removeRemote(String identity) {
    remotes.removeWhere((p) => p.identity == identity);
    emit(ParticipantLeft(identity));
  }

  /// A data message from [identity] (with its server-issued [metadata]).
  void receive(Map<String, dynamic> message, {String? identity, String? metadata}) => emit(
        DataMessageReceived(utf8.encode(jsonEncode(message)), senderIdentity: identity, senderMetadata: metadata),
      );

  /// The course teacher (mobile identity) sending a message.
  void receiveFromTeacher(Map<String, dynamic> message) => receive(message,
      identity: 'T1_mobile', metadata: '{"role":"moderator","teacherId":"T1"}');

  // ── MeetRoom ───────────────────────────────────────────────────────────
  @override
  bool get isConnected => _connected;
  @override
  String? get localIdentity => _identity;
  @override
  String get localName => _name;
  @override
  bool get isMicrophoneEnabled => _mic;
  @override
  bool get isCameraEnabled => _camera;
  @override
  String? get localAudioTrackSid => _mic ? 'TR_mic_$_identity' : null;
  @override
  String? get localVideoTrackSid => _camera ? 'TR_cam_$_identity' : null;

  @override
  List<MeetParticipant> get participants => [
        if (_connected)
          MeetParticipant(
            identity: _identity!,
            name: _name,
            metadata: _metadata,
            isLocal: true,
            isMicrophoneEnabled: _mic,
            isCameraEnabled: _camera,
            video: _camera ? const MeetVideo('local-camera', isLocalCamera: true) : null,
          ),
        ...remotes,
      ];

  @override
  Future<void> connect(String url, String token, {bool forceRelay = false}) async {
    connects.add((url: url, token: token, forceRelay: forceRelay));
    final result = connectResults.isEmpty ? null : connectResults.removeAt(0);
    if (result != null) throw result;
    _connected = true;
    _identity = identityOnConnect;
    _name = nameOnConnect;
    _metadata = metadataOnConnect;
  }

  @override
  bool shouldRetryWithRelay(Object error) => retryWithRelay;

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _mic = enabled;
    if (enabled) emit(const LocalTrackPublished());
  }

  @override
  Future<void> setCameraEnabled(bool enabled, {MeetCameraPosition position = MeetCameraPosition.front}) async {
    if (enabled && cameraError != null) throw cameraError!;
    _camera = enabled;
    if (enabled) {
      cameraPositions.add(position);
      emit(const LocalTrackPublished());
    }
  }

  @override
  Future<void> switchCamera(MeetCameraPosition position) async => cameraPositions.add(position);

  /// Camera focus points the app asked for (fractions of the picture), in order.
  final cameraFocusPoints = <(double, double)>[];

  @override
  Future<void> setCameraFocus(double x, double y) async {
    if (zoomError != null) throw zoomError!;
    cameraFocusPoints.add((x, y));
  }

  /// Camera zoom levels the app asked for, in order.
  final cameraZooms = <double>[];
  Object? zoomError;

  @override
  Future<void> setCameraZoom(double zoom) async {
    if (zoomError != null) throw zoomError!;
    cameraZooms.add(zoom);
  }

  @override
  Future<void> publish(Map<String, dynamic> message) async => published.add(message);

  @override
  Future<void> setRemoteVideoEnabled(bool enabled) async => remoteVideoEnabled = enabled;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    _connected = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }
}
