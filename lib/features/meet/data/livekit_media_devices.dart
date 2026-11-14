import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/meet_media.dart';
import '../domain/meet_participant.dart';
import '../domain/meet_room.dart';

/// [MeetMediaDevices] backed by permission_handler + LiveKit local tracks.
class LiveKitMediaDevices implements MeetMediaDevices {
  const LiveKitMediaDevices();

  @override
  Future<bool> requestMicrophonePermission() async => (await Permission.microphone.request()).isGranted;

  @override
  Future<bool> requestCameraPermission() async => (await Permission.camera.request()).isGranted;

  @override
  Future<MeetCameraPreview> startCameraPreview(MeetCameraPosition position) async {
    final track = await LocalVideoTrack.createCameraTrack(CameraCaptureOptions(
      cameraPosition: position == MeetCameraPosition.back ? CameraPosition.back : CameraPosition.front,
    ));
    return _LiveKitCameraPreview(track);
  }
}

class _LiveKitCameraPreview implements MeetCameraPreview {
  final LocalVideoTrack _track;
  _LiveKitCameraPreview(this._track);

  @override
  MeetVideo get video => MeetVideo(_track);

  @override
  Future<void> stop() async {
    await _track.stop();
    await _track.dispose();
  }
}
