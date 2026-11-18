import 'package:calligro_app/features/meet/domain/meet_policies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';

/// Tests the REAL decision rules used by calligro_meet_page.dart.
void main() {
  // ═══════════════════════════════════════════════════════════════════════
  group('DisconnectPolicy', () {
    test('while we are ending/leaving on purpose, every disconnect is ignored', () {
      for (final reason in MeetDisconnectReason.values) {
        expect(DisconnectPolicy.decide(reason, isEndingMeeting: true), DisconnectDecision.ignore,
            reason: '$reason');
      }
    });

    test('room deleted on the server → the teacher ended the class → leave', () {
      expect(DisconnectPolicy.decide(MeetDisconnectReason.roomDeleted, isEndingMeeting: false),
          DisconnectDecision.leaveMeetingEnded);
    });

    test('removed by the server → kicked → leave without offering Rejoin', () {
      expect(DisconnectPolicy.decide(MeetDisconnectReason.participantRemoved, isEndingMeeting: false),
          DisconnectDecision.leaveKicked);
    });

    test('our own disconnect (leaving, rejoin cleanup) never shows the "connection lost" overlay', () {
      expect(DisconnectPolicy.decide(MeetDisconnectReason.clientInitiated, isEndingMeeting: false),
          DisconnectDecision.ignore);
    });

    test('every other reason (network, server restart, unknown) → Rejoin overlay', () {
      final others = MeetDisconnectReason.values.where((r) =>
          r != MeetDisconnectReason.roomDeleted &&
          r != MeetDisconnectReason.participantRemoved &&
          r != MeetDisconnectReason.clientInitiated);
      for (final reason in others) {
        expect(DisconnectPolicy.decide(reason, isEndingMeeting: false), DisconnectDecision.showReconnectOverlay,
            reason: '$reason');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('RecordingPolicy', () {
    RecordingStartDecision eval({bool teacher = true, bool recording = false, String? a = 'TR_a', String? v = 'TR_v'}) =>
        RecordingPolicy.evaluate(isTeacher: teacher, isRecording: recording, audioTrackSid: a, videoTrackSid: v);

    test('students never start a recording', () {
      expect(eval(teacher: false), RecordingStartDecision.notTeacher);
      expect(eval(teacher: false, a: null, v: null), RecordingStartDecision.notTeacher);
    });

    test('never starts a second recording while one is running/starting', () {
      expect(eval(recording: true), RecordingStartDecision.alreadyRecording);
      expect(eval(recording: true, a: null), RecordingStartDecision.alreadyRecording);
    });

    test('waits until BOTH mic and camera tracks are published', () {
      expect(eval(a: null), RecordingStartDecision.waitingForTracks);
      expect(eval(v: null), RecordingStartDecision.waitingForTracks);
      expect(eval(a: null, v: null), RecordingStartDecision.waitingForTracks);
    });

    test('teacher + not recording + both tracks → start', () {
      expect(eval(), RecordingStartDecision.start);
    });

    test('recordings always use landscape (the meet page is locked to landscape)', () {
      expect(RecordingPolicy.orientation, 'landscape');
    });

    test('3 attempts with 1.2s, 2.4s backoff', () {
      expect(RecordingPolicy.maxStartAttempts, 3);
      expect(RecordingPolicy.retryDelay(1), const Duration(milliseconds: 1200));
      expect(RecordingPolicy.retryDelay(2), const Duration(milliseconds: 2400));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('LifecycleCameraPolicy', () {
    test('backgrounding: students with camera on turn it off', () {
      expect(LifecycleCameraPolicy.shouldDisableCameraOnPause(isTeacher: false, cameraEnabled: true), isTrue);
    });

    test('backgrounding: the teacher keeps the camera on (the recording must not break)', () {
      expect(LifecycleCameraPolicy.shouldDisableCameraOnPause(isTeacher: true, cameraEnabled: true), isFalse);
    });

    test('backgrounding: nothing to do when the camera is already off', () {
      expect(LifecycleCameraPolicy.shouldDisableCameraOnPause(isTeacher: false, cameraEnabled: false), isFalse);
    });

    test('resume: restore only a camera WE turned off, and never in audio-only mode', () {
      expect(LifecycleCameraPolicy.shouldRestoreCameraOnResume(disabledOnPause: true, audioOnlyMode: false), isTrue);
      expect(LifecycleCameraPolicy.shouldRestoreCameraOnResume(disabledOnPause: true, audioOnlyMode: true), isFalse);
      expect(LifecycleCameraPolicy.shouldRestoreCameraOnResume(disabledOnPause: false, audioOnlyMode: false), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('StageLayoutPolicy.select (who is full-screen, who is the PiP)', () {
    const local = StageCandidate(identity: 'me', isLocal: true);
    const teacherCam = StageCandidate(identity: 'T1', isModerator: true);
    const teacherScreen = StageCandidate(identity: 'T1', isModerator: true, isScreenShare: true);
    const s1 = StageCandidate(identity: 's1');
    const s2Speaking = StageCandidate(identity: 's2', isSpeaking: true);
    const s3Video = StageCandidate(identity: 's3', hasLiveVideo: true);

    test('nothing to show → null', () {
      expect(StageLayoutPolicy.select([], localIsTeacher: false), isNull);
    });

    test('a single tile is focused with no PiP', () {
      final sel = StageLayoutPolicy.select([local], localIsTeacher: false)!;
      expect(sel.focusIndex, 0);
      expect(sel.pipIndex, isNull);
    });

    test('screen share always wins the stage', () {
      final sel = StageLayoutPolicy.select([local, teacherCam, teacherScreen], localIsTeacher: false)!;
      expect(sel.focusIndex, 2);
    });

    test('a student sees the teacher full-screen', () {
      final sel = StageLayoutPolicy.select([local, s1, teacherCam], localIsTeacher: false)!;
      expect(sel.focusIndex, 2);
    });

    test('the teacher sees themself full-screen', () {
      final sel = StageLayoutPolicy.select([local, s1, s2Speaking], localIsTeacher: true)!;
      expect(sel.focusIndex, 0);
    });

    test('no teacher present → the active speaker (camera, not their screen) is focused', () {
      final sel = StageLayoutPolicy.select([local, s1, s3Video], localIsTeacher: false, activeSpeakerIdentity: 's3')!;
      expect(sel.focusIndex, 2);
    });

    test('active speaker who is not in the list → first tile', () {
      final sel = StageLayoutPolicy.select([local, s1], localIsTeacher: false, activeSpeakerIdentity: 'ghost')!;
      expect(sel.focusIndex, 0);
    });

    test('PiP prefers someone speaking, then someone with live video, then the first other tile', () {
      expect(StageLayoutPolicy.select([teacherCam, s1, s3Video, s2Speaking], localIsTeacher: false)!.pipIndex, 3);
      expect(StageLayoutPolicy.select([teacherCam, s1, s3Video], localIsTeacher: false)!.pipIndex, 2);
      expect(StageLayoutPolicy.select([teacherCam, s1, local], localIsTeacher: false)!.pipIndex, 1);
    });

    group('the COURSE TEACHER is always the big screen (an admin is a moderator too)', () {
      const courseTeacher = StageCandidate(identity: 'T1_mobile', isModerator: true, isCourseTeacher: true);
      const admin = StageCandidate(identity: 'admin1', isModerator: true, isSpeaking: true, hasLiveVideo: true);
      const adminScreen = StageCandidate(identity: 'admin1', isModerator: true, isScreenShare: true);
      const meAdmin = StageCandidate(identity: 'admin1', isLocal: true, isModerator: true);

      test('a student: the admin joined (and listed / speaking first) → still the teacher (THE BUG)', () {
        final sel = StageLayoutPolicy.select([local, admin, courseTeacher], localIsTeacher: false)!;
        expect(sel.focusIndex, 2);
        expect(sel.pipIndex, 1, reason: 'the speaking admin can be the small picture');
      });

      test('the admin\'s own phone: the teacher, not themself', () {
        final sel = StageLayoutPolicy.select([meAdmin, s1, courseTeacher], localIsTeacher: false)!;
        expect(sel.focusIndex, 2);
      });

      test('the teacher\'s own phone: themself, whoever joins', () {
        const meTeacher = StageCandidate(identity: 'T1_mobile', isLocal: true, isModerator: true, isCourseTeacher: true);
        final sel = StageLayoutPolicy.select([meTeacher, admin, s2Speaking], localIsTeacher: true)!;
        expect(sel.focusIndex, 0);
      });

      test('an admin sharing their screen does not take the stage from the teacher', () {
        final sel = StageLayoutPolicy.select([local, courseTeacher, admin, adminScreen], localIsTeacher: false)!;
        expect(sel.focusIndex, 1);
      });

      test('the TEACHER sharing their screen: the share is the big screen', () {
        const teacherShare = StageCandidate(identity: 'T1', isModerator: true, isScreenShare: true, isCourseTeacher: true);
        final sel = StageLayoutPolicy.select([local, admin, courseTeacher, teacherShare], localIsTeacher: false)!;
        expect(sel.focusIndex, 3);
      });

      test('the teacher is not in the class (yet): the old order (a moderator, e.g. the admin)', () {
        final sel = StageLayoutPolicy.select([local, s1, admin], localIsTeacher: false)!;
        expect(sel.focusIndex, 2);
      });
    });

    test('the PiP is never the focused tile', () {
      final sel = StageLayoutPolicy.select([s2Speaking, teacherCam], localIsTeacher: false)!;
      expect(sel.focusIndex, 1);
      expect(sel.pipIndex, 0);
      final speakingTeacher = StageLayoutPolicy.select(
        [const StageCandidate(identity: 'T1', isModerator: true, isSpeaking: true), s1],
        localIsTeacher: false,
      )!;
      expect(speakingTeacher.pipIndex, isNot(speakingTeacher.focusIndex));
    });
  });

  group('StageLayoutPolicy.gridColumns', () {
    test('2 columns up to 2 tiles, 3 up to 6, then 4', () {
      final expected = {1: 2, 2: 2, 3: 3, 6: 3, 7: 4, 30: 4};
      expected.forEach((tiles, cols) => expect(StageLayoutPolicy.gridColumns(tiles), cols, reason: '$tiles tiles'));
    });
  });
}
