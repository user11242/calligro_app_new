import 'package:calligro_app/features/meet/application/connection_quality_monitor.dart';
import 'package:calligro_app/features/meet/application/meet_controller.dart';
import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/domain/meet_participant.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';
import '../fakes/fake_meet_room.dart';

/// A platform admin in a class: the course teacher stays the big screen, and the
/// admin can moderate students like the teacher (but not record or end the class).
void main() {
  const adminMeta = '{"role":"moderator","teacherId":"T1"}';
  const teacher = MeetParticipant(identity: 'T1_mobile', name: 'Teacher', metadata: adminMeta, isCameraEnabled: true);
  const student = MeetParticipant(identity: 's2', name: 'Student', metadata: '{"role":"participant","teacherId":"T1"}');
  late FakeMeetRoom room;
  late FakeFunctions fn;

  Future<MeetController> join({required String identity, required String metadata, bool isTeacher = false}) async {
    room
      ..identityOnConnect = identity
      ..metadataOnConnect = metadata;
    final c = MeetController(
      room: room,
      backend: MeetBackend(courseId: 'c1', call: fn.call, delay: (_) async {}),
      token: 'jwt',
      serverUrl: 'wss://lk',
      isTeacher: isTeacher,
      teacherId: 'T1',
      qualityMonitor: ConnectionQualityMonitor(),
      connectGrace: Duration.zero,
    );
    await c.join();
    await pumpEventQueue();
    return c;
  }

  setUp(() {
    room = FakeMeetRoom();
    fn = FakeFunctions();
  });

  test('the admin\'s own phone: the TEACHER is the big screen, not the admin (THE BUG)', () async {
    final c = await join(identity: 'admin1', metadata: adminMeta);
    room.addRemote(student);
    room.addRemote(teacher);
    await pumpEventQueue();
    expect(c.stage!.focus.identity, 'T1_mobile');
  });

  test('a student\'s phone: the admin joining first does not take the teacher\'s place', () async {
    final c = await join(identity: 's1', metadata: '{"role":"participant","teacherId":"T1"}');
    room.addRemote(const MeetParticipant(identity: 'admin1', name: 'Admin', metadata: adminMeta, isSpeaking: true));
    room.addRemote(teacher);
    await pumpEventQueue();
    expect(c.stage!.focus.identity, 'T1_mobile');
  });

  test('the admin can mute, turn off the camera of and remove a student (server-enforced)', () async {
    final c = await join(identity: 'admin1', metadata: adminMeta);
    expect(c.canModerate, isTrue);
    await c.muteParticipant('s2', mic: true);
    await c.muteParticipant('s2', mic: false);
    await c.kick('s2');
    expect(fn.calls.map((x) => x.$2['action']), ['mute_mic', 'mute_camera', 'kick']);
  });

  test('...but is not the course teacher: no recording, no show-work, no camera zoom', () async {
    final c = await join(identity: 'admin1', metadata: adminMeta);
    expect(c.isTeacher, isFalse);
    expect(c.canZoomCamera, isFalse);
    expect(fn.calls.where((x) => x.$1 == MeetBackend.startRecordingFunction), isEmpty);
  });

  test('a student cannot moderate', () async {
    final c = await join(identity: 's1', metadata: '{"role":"participant","teacherId":"T1"}');
    expect(c.canModerate, isFalse);
  });
}
