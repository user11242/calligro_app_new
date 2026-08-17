import 'package:livekit_client/livekit_client.dart';

void test(LocalVideoTrack track) async {
  await track.restartTrack(const CameraCaptureOptions(cameraPosition: CameraPosition.back));
}
