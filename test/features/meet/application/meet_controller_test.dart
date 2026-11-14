import 'package:calligro_app/features/meet/application/meet_controller.dart';
import 'package:calligro_app/features/meet/application/connection_quality_monitor.dart';
import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/domain/meet_participant.dart';
import 'package:calligro_app/features/meet/domain/meet_protocol.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';
import '../fakes/fake_meet_room.dart';

/// Behaviour of the whole live class, driven through a fake room and fake
/// Cloud Functions. Written BEFORE MeetController (test-first).
void main() {
  late FakeMeetRoom room;
  late FakeFunctions fn;
  late List<MeetEffect> effects;
  late List<Duration> waits;
  late MeetController c;

  const teacherMeta = '{"role":"moderator","teacherId":"T1"}';
  const studentMeta = '{"role":"participant","teacherId":"T1"}';

  MeetController make({
    bool teacher = false,
    bool mic = false,
    bool camera = false,
    MeetCameraPosition position = MeetCameraPosition.front,
    ConnectionQualityMonitor? qualityMonitor,
  }) {
    if (teacher) {
      room.identityOnConnect = 'T1_mobile';
      room.nameOnConnect = 'Teacher One';
      room.metadataOnConnect = teacherMeta;
    }
    final controller = MeetController(
      room: room,
      backend: MeetBackend(courseId: 'c1', call: fn.call, delay: (d) async => waits.add(d)),
      token: 'jwt-1',
      serverUrl: 'wss://lk',
      isTeacher: teacher,
      teacherId: 'T1',
      startWithMic: mic,
      startWithCamera: camera,
      cameraPosition: position,
      qualityMonitor: qualityMonitor ?? ConnectionQualityMonitor(),
      connectGrace: Duration.zero,
      endMeetingSignalDelay: Duration.zero,
    );
    controller.effects.listen(effects.add);
    return controller;
  }

  Future<MeetController> joined({bool teacher = false, bool mic = false, bool camera = false}) async {
    final controller = make(teacher: teacher, mic: mic, camera: camera);
    await controller.join();
    await pumpEventQueue();
    return controller;
  }

  List<String?> actions() =>
      fn.calls.where((x) => x.$1 == MeetBackend.moderateFunction).map((x) => x.$2['action'] as String?).toList();
  int recordingStarts() => fn.calls.where((x) => x.$1 == MeetBackend.startRecordingFunction).length;
  T? effect<T>() => effects.whereType<T>().firstOrNull;

  setUp(() {
    room = FakeMeetRoom();
    fn = FakeFunctions();
    effects = [];
    waits = [];
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('joining', () {
    test('connects with the token, becomes connected and lists us first', () async {
      c = make();
      expect(c.phase, MeetPhase.connecting);
      await c.join();
      expect(room.connects.single, (url: 'wss://lk', token: 'jwt-1', forceRelay: false));
      expect(c.phase, MeetPhase.connected);
      expect(c.connectedAt, isNotNull);
      expect(c.participants.first.isLocal, isTrue);
    });

    test('turns on mic and camera (at the chosen position) only when asked to', () async {
      c = make(mic: true, camera: true, position: MeetCameraPosition.back);
      await c.join();
      expect(room.isMicrophoneEnabled, isTrue);
      expect(room.isCameraEnabled, isTrue);
      expect(room.cameraPositions, [MeetCameraPosition.back]);

      room = FakeMeetRoom();
      c = make();
      await c.join();
      expect(room.isMicrophoneEnabled, isFalse);
      expect(room.isCameraEnabled, isFalse);
    });

    test('network failure → retries once through the relay and connects', () async {
      room.connectResults.add(Exception('ice failed'));
      c = make();
      await c.join();
      expect(room.connects.map((x) => x.forceRelay), [false, true]);
      expect(c.phase, MeetPhase.connected);
    });

    test('relay also fails → failed with an error, nothing else happens', () async {
      room.connectResults.addAll([Exception('ice'), Exception('relay')]);
      c = make(teacher: true, mic: true, camera: true);
      await c.join();
      expect(c.phase, MeetPhase.failed);
      expect(effect<MeetErrorEffect>(), isNotNull);
      expect(recordingStarts(), 0);
    });

    test('a non-network error (e.g. bad token) is not retried through the relay', () async {
      room.connectResults.add(Exception('not allowed'));
      room.retryWithRelay = false;
      c = make();
      await c.join();
      expect(room.connects, hasLength(1));
      expect(c.phase, MeetPhase.failed);
    });

    test('a camera error AFTER connecting keeps us in class (no relay reconnect)', () async {
      room.cameraError = Exception('camera busy');
      c = make(mic: true, camera: true);
      await c.join();
      expect(room.connects, hasLength(1));
      expect(c.phase, MeetPhase.connected);
      expect(room.isMicrophoneEnabled, isTrue);
      expect(effect<MeetErrorEffect>()!.message, contains('camera busy'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('recording', () {
    test('the teacher with mic + camera starts exactly one landscape recording', () async {
      c = await joined(teacher: true, mic: true, camera: true);
      final starts = fn.calls.where((x) => x.$1 == MeetBackend.startRecordingFunction).toList();
      expect(starts, hasLength(1), reason: 'mic and camera both publish, but only one recording may start');
      expect(starts.single.$2, {
        'courseId': 'c1',
        'audioTrackId': 'TR_mic_T1_mobile',
        'videoTrackId': 'TR_cam_T1_mobile',
        'orientation': 'landscape',
      });
      expect(c.isRecording, isTrue);
      expect(effects.whereType<MeetNoticeEffect>().map((e) => e.notice), contains(MeetNotice.recordingStarted));
    });

    test('teacher with mic only: waits, then starts when the camera is turned on', () async {
      c = await joined(teacher: true, mic: true);
      expect(recordingStarts(), 0);
      expect(c.isRecording, isFalse);
      await c.toggleCamera();
      await pumpEventQueue();
      expect(recordingStarts(), 1);
      expect(c.isRecording, isTrue);
    });

    test('mic and camera published at the same moment in class → one recording', () async {
      c = await joined(teacher: true);
      await room.setMicrophoneEnabled(true);
      await room.setCameraEnabled(true); // both LocalTrackPublished events arrive together
      await pumpEventQueue();
      expect(recordingStarts(), 1);
    });

    test('students never record', () async {
      c = await joined(mic: true, camera: true);
      expect(recordingStarts(), 0);
    });

    test('server keeps failing → 3 attempts, then not recording + a failure message', () async {
      fn.failWith(Exception('egress unavailable'));
      c = await joined(teacher: true, mic: true, camera: true);
      expect(recordingStarts(), greaterThanOrEqualTo(3));
      expect(c.isRecording, isFalse);
      expect(effect<RecordingFailedEffect>()!.message, contains('egress unavailable'));
    });

    test('the server recording flag is reflected', () async {
      c = await joined(teacher: true);
      room.emit(const RecordingStatusChanged(true));
      await pumpEventQueue();
      expect(c.isRecording, isTrue);
    });

    test('manual start (REC button) after a failed attempt; never twice', () async {
      fn
        ..failWith(Exception('busy'))
        ..failWith(Exception('busy'))
        ..failWith(Exception('busy'))
        ..answerWith({'status': 'started'});
      c = await joined(teacher: true, mic: true, camera: true);
      expect(c.isRecording, isFalse, reason: 'the automatic start failed 3 times');
      await c.startRecording(); // teacher taps REC
      expect(c.isRecording, isTrue);
      expect(recordingStarts(), 4);
      await c.startRecording();
      expect(recordingStarts(), 4, reason: 'already recording → no second start');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('disconnects', () {
    test('teacher ended the class (room deleted) → notice + leave, no rejoin overlay', () async {
      c = await joined();
      room.emit(const RoomDisconnected(MeetDisconnectReason.roomDeleted));
      await pumpEventQueue();
      expect(effects.whereType<MeetNoticeEffect>().single.notice, MeetNotice.teacherEndedMeeting);
      expect(effect<LeaveMeetingEffect>(), isNotNull);
      expect(c.phase, MeetPhase.ended);
    });

    test('removed by the teacher → kicked notice + leave', () async {
      c = await joined();
      room.emit(const RoomDisconnected(MeetDisconnectReason.participantRemoved));
      await pumpEventQueue();
      expect(effects.whereType<MeetNoticeEffect>().single.notice, MeetNotice.kicked);
      expect(effect<LeaveMeetingEffect>(), isNotNull);
    });

    test('network drop → disconnected (Rejoin overlay); reconnecting/reconnected phases', () async {
      c = await joined();
      room.emit(const RoomReconnecting());
      await pumpEventQueue();
      expect(c.phase, MeetPhase.reconnecting);
      room.emit(const RoomReconnected());
      await pumpEventQueue();
      expect(c.phase, MeetPhase.connected);
      room.emit(const RoomDisconnected(MeetDisconnectReason.other));
      await pumpEventQueue();
      expect(c.phase, MeetPhase.disconnected);
      expect(effect<LeaveMeetingEffect>(), isNull);
    });

    test('our own disconnect is ignored', () async {
      c = await joined();
      room.emit(const RoomDisconnected(MeetDisconnectReason.clientInitiated));
      await pumpEventQueue();
      expect(c.phase, MeetPhase.connected);
    });

    test('rejoin fetches a FRESH token and reconnects with it', () async {
      c = await joined();
      room.emit(const RoomDisconnected(MeetDisconnectReason.other));
      await pumpEventQueue();
      fn.answerWith({'token': 'jwt-2', 'serverUrl': 'wss://lk2', 'roomName': 'r'});
      await c.rejoin();
      expect(fn.calls.first.$1, MeetBackend.tokenFunction);
      expect(room.connects.last, (url: 'wss://lk2', token: 'jwt-2', forceRelay: false));
      expect(c.phase, MeetPhase.connected);
    });

    test('rejoin refused (e.g. kicked) → error + leave, no reconnect', () async {
      c = await joined();
      fn.failWith(Exception('permission-denied: removed'));
      await c.rejoin();
      expect(room.connects, hasLength(1));
      expect(effect<MeetErrorEffect>()!.message, contains('removed'));
      expect(effect<LeaveMeetingEffect>(), isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('people joining / leaving', () {
    test('play join/leave sounds and refresh the participant list', () async {
      c = await joined();
      room.addRemote(const MeetParticipant(identity: 's2', name: 'Student Two'));
      await pumpEventQueue();
      expect(c.participants.map((p) => p.identity), ['s1', 's2']);
      room.removeRemote('s2');
      await pumpEventQueue();
      expect(c.participants.map((p) => p.identity), ['s1']);
      expect(effects.whereType<PlaySoundEffect>().map((e) => e.sound), [MeetSound.join, MeetSound.leave]);
    });

    test('stage: a student sees the teacher full-screen, PiP is someone else', () async {
      c = await joined();
      room.addRemote(const MeetParticipant(identity: 's2'));
      room.addRemote(const MeetParticipant(identity: 'T1_mobile', metadata: teacherMeta));
      await pumpEventQueue();
      expect(c.stage!.focus.identity, 'T1_mobile');
      expect(c.stage!.pip!.identity, isNot('T1_mobile'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('teacher commands received by a student', () {
    test('mute all → our mic goes off + notice', () async {
      c = await joined(mic: true);
      room.receiveFromTeacher({'cmd': 'mute_all'});
      await pumpEventQueue();
      expect(room.isMicrophoneEnabled, isFalse);
      expect(effects.whereType<MeetNoticeEffect>().last.notice, MeetNotice.mutedByTeacher);
    });

    test('targeted mic / camera mute', () async {
      c = await joined(mic: true, camera: true);
      room.receiveFromTeacher(MeetProtocol.muteMessage('s1', mic: true));
      await pumpEventQueue();
      expect(room.isMicrophoneEnabled, isFalse);
      expect(room.isCameraEnabled, isTrue);
      room.receiveFromTeacher(MeetProtocol.muteMessage('s1', mic: false));
      await pumpEventQueue();
      expect(room.isCameraEnabled, isFalse);
      expect(effects.whereType<MeetNoticeEffect>().last.notice, MeetNotice.cameraDisabledByTeacher);
    });

    test('end meeting → leave', () async {
      c = await joined();
      room.receiveFromTeacher(MeetProtocol.endMeetingMessage());
      await pumpEventQueue();
      expect(effect<LeaveMeetingEffect>(), isNotNull);
      expect(c.phase, MeetPhase.ended);
    });

    test('kick → kicked + leave', () async {
      c = await joined();
      room.receiveFromTeacher(MeetProtocol.kickMessage('s1'));
      await pumpEventQueue();
      expect(effects.whereType<MeetNoticeEffect>().last.notice, MeetNotice.kicked);
      expect(effect<LeaveMeetingEffect>(), isNotNull);
    });

    test("the teacher's own device ignores mute-all (even from an admin)", () async {
      c = await joined(teacher: true, mic: true);
      room.receive({'cmd': 'mute_all'}, identity: 'admin1', metadata: teacherMeta);
      await pumpEventQueue();
      expect(room.isMicrophoneEnabled, isTrue);
      expect(effects.whereType<MeetNoticeEffect>().where((e) => e.notice == MeetNotice.mutedByTeacher), isEmpty);
    });

    test('the SAME commands forged by a student do nothing', () async {
      c = await joined(mic: true, camera: true);
      for (final m in [
        {'cmd': 'mute_all'},
        MeetProtocol.endMeetingMessage(),
        MeetProtocol.kickMessage('s1'),
        MeetProtocol.muteMessage('s1', mic: true),
      ]) {
        room.receive(m, identity: 's2', metadata: studentMeta);
      }
      room.receive(MeetProtocol.endMeetingMessage()); // unknown sender
      await pumpEventQueue();
      expect(room.isMicrophoneEnabled, isTrue);
      expect(room.isCameraEnabled, isTrue);
      expect(effect<LeaveMeetingEffect>(), isNull);
      expect(c.phase, MeetPhase.connected);
    });

    test('teacher lowers MY hand → my hand goes down and I re-broadcast lower_hand', () async {
      c = await joined();
      await c.toggleHand();
      room.published.clear();
      room.receiveFromTeacher(MeetProtocol.forceLowerHandMessage('s1'));
      await pumpEventQueue();
      expect(c.isHandRaised, isFalse);
      expect(c.raisedHands, isNot(contains('s1')));
      expect(room.published, [MeetProtocol.lowerHandMessage('Student One')]);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('hands', () {
    test('raising and lowering my own hand', () async {
      c = await joined();
      await c.toggleHand();
      expect(c.isHandRaised, isTrue);
      expect(c.raisedHands, contains('s1'));
      expect(room.published.last, MeetProtocol.raiseHandMessage('Student One'));
      await c.toggleHand();
      expect(c.isHandRaised, isFalse);
      expect(c.raisedHands, isNot(contains('s1')));
      expect(room.published.last, MeetProtocol.lowerHandMessage('Student One'));
    });

    test('the teacher sees raised hands with the student name', () async {
      c = await joined(teacher: true);
      room.receive(MeetProtocol.raiseHandMessage('Ali'), identity: 's2', metadata: studentMeta);
      await pumpEventQueue();
      expect(c.raisedHands, {'s2'});
      final notice = effects.whereType<MeetNoticeEffect>().last;
      expect(notice.notice, MeetNotice.handRaised);
      expect(notice.name, 'Ali');
      room.receive(MeetProtocol.lowerHandMessage('Ali'), identity: 's2', metadata: studentMeta);
      await pumpEventQueue();
      expect(c.raisedHands, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('teacher moderation', () {
    test('mute a student: notice message to them + server-enforced mute', () async {
      c = await joined(teacher: true);
      expect(await c.muteParticipant('s2', mic: true), isTrue);
      expect(room.published.last, MeetProtocol.muteMessage('s2', mic: true));
      expect(fn.calls.last.$2, {'courseId': 'c1', 'action': 'mute_mic', 'targetIdentity': 's2'});
      expect(await c.muteParticipant('s2', mic: false), isTrue);
      expect(fn.calls.last.$2['action'], 'mute_camera');
    });

    test('kick a student: notice message + server kick', () async {
      c = await joined(teacher: true);
      expect(await c.kick('s2'), isTrue);
      expect(room.published.last, MeetProtocol.kickMessage('s2'));
      expect(fn.calls.last.$2, {'courseId': 'c1', 'action': 'kick', 'targetIdentity': 's2'});
    });

    test('server refuses → false + error message', () async {
      c = await joined(teacher: true);
      fn.failWith(Exception('permission-denied'));
      expect(await c.kick('s2'), isFalse);
      expect(effect<MeetErrorEffect>()!.message, contains('permission-denied'));
    });

    test('lower a student hand', () async {
      c = await joined(teacher: true);
      room.receive(MeetProtocol.raiseHandMessage('Ali'), identity: 's2', metadata: studentMeta);
      await pumpEventQueue();
      await c.forceLowerHand('s2');
      expect(c.raisedHands, isEmpty);
      expect(room.published.last, MeetProtocol.forceLowerHandMessage('s2'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('leaving and ending', () {
    test('teacher leaves: stops the recording but does NOT end the class', () async {
      c = await joined(teacher: true, mic: true, camera: true);
      await c.leave();
      expect(actions(), ['stop_recording']);
      expect(c.isRecording, isFalse);
      c.dispose();
      await pumpEventQueue();
      expect(actions(), ['stop_recording'], reason: 'no second stop from dispose()');
    });

    test('a student leaving makes no server calls', () async {
      c = await joined(mic: true);
      fn.calls.clear();
      await c.leave();
      expect(fn.calls, isEmpty);
    });

    test('end for all: tells everyone first, then ends the room on the server', () async {
      c = await joined(teacher: true, mic: true, camera: true);
      await c.endForAll();
      expect(room.published.last, MeetProtocol.endMeetingMessage());
      expect(actions(), ['end_room']);
      expect(c.isRecording, isFalse);
      expect(c.phase, MeetPhase.ended);
      room.emit(const RoomDisconnected(MeetDisconnectReason.roomDeleted));
      await pumpEventQueue();
      expect(effects.whereType<MeetNoticeEffect>().where((e) => e.notice == MeetNotice.teacherEndedMeeting), isEmpty,
          reason: 'our own ending must not show "teacher ended the meeting" to the teacher');
    });

    test('end for all still completes if the server call fails', () async {
      c = await joined(teacher: true);
      fn.failWith(Exception('down'));
      await expectLater(c.endForAll(), completes);
      expect(c.phase, MeetPhase.ended);
    });

    test('closing the page while recording → fail-safe stop_recording; room disposed', () async {
      c = await joined(teacher: true, mic: true, camera: true);
      c.dispose();
      await pumpEventQueue();
      expect(actions(), ['stop_recording']);
      expect(room.disposed, isTrue);
    });

    test('a student closing the page → no server calls; room disposed', () async {
      c = await joined(mic: true);
      fn.calls.clear();
      c.dispose();
      await pumpEventQueue();
      expect(fn.calls, isEmpty);
      expect(room.disposed, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('my mic / camera', () {
    test('toggle mic and camera', () async {
      c = await joined();
      await c.toggleMicrophone();
      expect(room.isMicrophoneEnabled, isTrue);
      await c.toggleMicrophone();
      expect(room.isMicrophoneEnabled, isFalse);
      await c.toggleCamera();
      expect(room.isCameraEnabled, isTrue);
    });

    test('flip camera switches between front and back', () async {
      c = await joined(camera: true);
      await c.flipCamera();
      expect(c.cameraPosition, MeetCameraPosition.back);
      expect(room.cameraPositions.last, MeetCameraPosition.back);
      await c.flipCamera();
      expect(c.cameraPosition, MeetCameraPosition.front);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('audio-only mode', () {
    test('poor connection for a while → we are asked to switch', () async {
      c = make(qualityMonitor: ConnectionQualityMonitor(poorQualityTriggerSeconds: 0));
      await c.join();
      room.emit(const LocalConnectionQualityChanged(MeetConnectionQuality.poor));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(effect<PromptAudioOnlyEffect>(), isNotNull);
    });

    test('on: stop receiving video; off: receive it again', () async {
      c = await joined();
      await c.setAudioOnly(true);
      expect(c.isAudioOnly, isTrue);
      expect(room.remoteVideoEnabled, isFalse);
      expect(effects.whereType<MeetNoticeEffect>().last.notice, MeetNotice.audioOnlyOn);
      await c.setAudioOnly(false);
      expect(room.remoteVideoEnabled, isTrue);
      expect(effects.whereType<MeetNoticeEffect>().last.notice, MeetNotice.audioOnlyOff);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('app goes to the background', () {
    test('student: camera off when backgrounded, back on when resumed', () async {
      c = await joined(camera: true);
      await c.onAppPaused();
      expect(room.isCameraEnabled, isFalse);
      await c.onAppResumed();
      expect(room.isCameraEnabled, isTrue);
    });

    test('teacher: camera stays on (the recording must not break)', () async {
      c = await joined(teacher: true, camera: true);
      await c.onAppPaused();
      expect(room.isCameraEnabled, isTrue);
    });

    test('resume in audio-only mode does not turn the camera back on', () async {
      c = await joined(camera: true);
      await c.onAppPaused();
      await c.setAudioOnly(true);
      await c.onAppResumed();
      expect(room.isCameraEnabled, isFalse);
    });

    test('a camera the student turned off themself stays off', () async {
      c = await joined();
      await c.onAppPaused();
      await c.onAppResumed();
      expect(room.isCameraEnabled, isFalse);
    });
  });
}
