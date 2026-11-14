import 'meet_participant.dart';
import 'meet_room.dart';

/// A running local camera preview (before joining the class).
abstract interface class MeetCameraPreview {
  MeetVideo get video;

  /// Stops the camera and frees the hardware (must happen before joining).
  Future<void> stop();
}

/// Microphone / camera access on this device.
/// Real: data/livekit_media_devices.dart · Tests: fakes/fake_media_devices.dart.
abstract interface class MeetMediaDevices {
  /// Asks the OS for permission (shows the system prompt the first time).
  Future<bool> requestMicrophonePermission();
  Future<bool> requestCameraPermission();

  /// Opens the camera for a preview. Throws if the camera can't be opened.
  Future<MeetCameraPreview> startCameraPreview(MeetCameraPosition position);
}

class MeetUserProfile {
  final String name;
  final String? avatarUrl;
  const MeetUserProfile({required this.name, this.avatarUrl});
}

/// Who is joining (name + avatar shown on the pre-join screen).
abstract interface class MeetProfileSource {
  Future<MeetUserProfile> load();
}
