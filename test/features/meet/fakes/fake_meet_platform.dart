import 'package:calligro_app/features/meet/data/meet_platform.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';

/// Records device-service calls instead of touching native plugins.
class FakeMeetPlatform implements MeetPlatform {
  final calls = <String>[];
  final sounds = <MeetSound>[];

  @override
  Future<void> enterMeeting() async => calls.add('enter');
  @override
  Future<void> startBackgroundAudio() async => calls.add('backgroundAudio');
  @override
  Future<void> exitMeeting() async => calls.add('exit');
  @override
  Future<void> playSound(MeetSound sound) async => sounds.add(sound);
}
