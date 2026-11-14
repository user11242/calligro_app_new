import 'dart:async';

import 'package:calligro_app/features/meet/domain/meet_media.dart';
import 'package:calligro_app/features/meet/domain/meet_participant.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';

class FakeCameraPreview implements MeetCameraPreview {
  final MeetCameraPosition position;
  bool stopped = false;
  FakeCameraPreview(this.position);

  @override
  MeetVideo get video => MeetVideo('preview-${position.name}');

  @override
  Future<void> stop() async => stopped = true;
}

/// Controllable camera/mic/permissions. Every preview ever opened is kept in
/// [previews] so tests can prove none is left running.
class FakeMediaDevices implements MeetMediaDevices {
  bool micGranted = true;
  bool cameraGranted = true;

  /// Error for the next startCameraPreview (null = success).
  Object? nextCameraError;

  /// When set, startCameraPreview waits for it (to simulate a slow camera).
  Completer<void>? cameraGate;

  int micRequests = 0;
  int cameraRequests = 0;
  final previews = <FakeCameraPreview>[];

  List<FakeCameraPreview> get running => previews.where((p) => !p.stopped).toList();

  @override
  Future<bool> requestMicrophonePermission() async {
    micRequests++;
    return micGranted;
  }

  @override
  Future<bool> requestCameraPermission() async {
    cameraRequests++;
    return cameraGranted;
  }

  @override
  Future<MeetCameraPreview> startCameraPreview(MeetCameraPosition position) async {
    if (cameraGate != null) await cameraGate!.future;
    final error = nextCameraError;
    if (error != null) {
      nextCameraError = null;
      throw error;
    }
    final preview = FakeCameraPreview(position);
    previews.add(preview);
    return preview;
  }
}

class FakeProfileSource implements MeetProfileSource {
  MeetUserProfile profile = const MeetUserProfile(name: 'Student One', avatarUrl: 'https://img/s1.png');
  Object? error;

  @override
  Future<MeetUserProfile> load() async {
    if (error != null) throw error!;
    return profile;
  }
}
