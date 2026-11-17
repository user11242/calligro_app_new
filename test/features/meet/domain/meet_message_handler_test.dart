import 'dart:convert';

import 'package:calligro_app/features/meet/domain/meet_message_handler.dart';
import 'package:calligro_app/features/meet/domain/meet_protocol.dart';
import 'package:calligro_app/features/meet/domain/shared_work.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the REAL decision logic behind every incoming data message in
/// calligro_meet_page.dart — including every "can a student fake the teacher?"
/// attack we know about.
void main() {
  const teacherId = 'T1';
  const studentId = 's1';
  const otherStudent = 's2';

  // ── Senders ────────────────────────────────────────────────────────────
  // (identity, metadata) pairs as LiveKit would deliver them.
  const teacherWeb = ('T1', '{"role":"moderator","teacherId":"T1"}');
  const teacherMobile = ('T1_mobile', '{"role":"moderator","teacherId":"T1"}');
  const admin = ('admin1', '{"role":"moderator","teacherId":"T1"}');
  const student = ('s2', '{"role":"participant","teacherId":"T1"}');
  const otherCourseModerator = ('T9', '{"role":"moderator","teacherId":"T9"}');
  const unknownSender = (null, null);

  final trusted = {'teacher (web)': teacherWeb, 'teacher (mobile)': teacherMobile, 'platform admin': admin};
  final untrusted = {
    'a student': student,
    'a moderator of ANOTHER course': otherCourseModerator,
    'an unknown sender (null participant)': unknownSender,
    'a student with self-written moderator metadata but wrong teacherId': (
      's3',
      '{"role":"moderator","teacherId":"FAKE"}'
    ),
  };

  MeetMessageHandler studentHandler({String? local = studentId}) =>
      MeetMessageHandler(localIdentity: local, isTeacher: false, teacherId: teacherId);
  const teacherHandler = MeetMessageHandler(localIdentity: 'T1_mobile', isTeacher: true, teacherId: teacherId);

  MeetAction send(MeetMessageHandler h, Object message, (String?, String?) sender) {
    final bytes = message is List<int> ? message : utf8.encode(message is String ? message : jsonEncode(message));
    return h.handle(bytes, senderIdentity: sender.$1, senderMetadata: sender.$2);
  }

  Matcher ignored(IgnoreReason reason) =>
      isA<IgnoreMessage>().having((a) => a.reason, 'reason', reason);

  // ═══════════════════════════════════════════════════════════════════════
  group('Teacher-only commands are obeyed ONLY from the teacher / moderators', () {
    final commands = <String, (Map<String, dynamic>, TypeMatcher<MeetAction>)>{
      'end meeting for all': (MeetProtocol.endMeetingMessage(), isA<MeetingEndedByTeacher>()),
      'mute all': ({'cmd': 'mute_all'}, isA<MutedByMuteAll>()),
      'kick me': (MeetProtocol.kickMessage(studentId), isA<KickedByTeacher>()),
      'mute my mic': (MeetProtocol.muteMessage(studentId, mic: true), isA<MicMutedByTeacher>()),
      'turn off my camera': (MeetProtocol.muteMessage(studentId, mic: false), isA<CameraDisabledByTeacher>()),
      'force lower my hand': (
        MeetProtocol.forceLowerHandMessage(studentId),
        isA<HandForceLowered>().having((a) => a.isSelf, 'isSelf', true)
      ),
    };

    commands.forEach((name, spec) {
      final (message, expected) = spec;
      trusted.forEach((who, sender) {
        test('"$name" from $who → obeyed', () {
          expect(send(studentHandler(), message, sender), expected);
        });
      });
      untrusted.forEach((who, sender) {
        test('"$name" from $who → IGNORED', () {
          expect(send(studentHandler(), message, sender), ignored(IgnoreReason.unauthorizedSender));
        });
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('Targeted commands only affect their target', () {
    for (final type in ['kick_participant', 'force_mute_mic', 'force_mute_camera']) {
      test('$type aimed at another student → not for me', () {
        expect(send(studentHandler(), {'type': type, 'targetId': otherStudent}, teacherMobile),
            ignored(IgnoreReason.notForMe));
      });
      test('$type with no / empty / non-string target → ignored', () {
        for (final target in [null, '', 42, true]) {
          expect(
              send(studentHandler(), {'type': type, if (target != null) 'targetId': target}, teacherMobile),
              ignored(IgnoreReason.missingTarget),
              reason: 'target $target');
        }
      });
      test('$type before our room identity is known → not for me', () {
        expect(send(studentHandler(local: null), {'type': type, 'targetId': studentId}, teacherMobile),
            ignored(IgnoreReason.notForMe));
      });
    }

    test('force_lower_hand for another student → lower their hand (not ours)', () {
      expect(
        send(studentHandler(), MeetProtocol.forceLowerHandMessage(otherStudent), teacherWeb),
        isA<HandForceLowered>()
            .having((a) => a.targetId, 'targetId', otherStudent)
            .having((a) => a.isSelf, 'isSelf', false),
      );
    });

    test('force_lower_hand with no target → ignored', () {
      expect(send(studentHandler(), {'cmd': 'force_lower_hand'}, teacherWeb), ignored(IgnoreReason.missingTarget));
      expect(send(studentHandler(), {'cmd': 'force_lower_hand', 'targetId': ''}, teacherWeb),
          ignored(IgnoreReason.missingTarget));
    });

    test('a forged kick for another student is rejected as not-for-me before trust is even checked', () {
      expect(send(studentHandler(), MeetProtocol.kickMessage(otherStudent), student), ignored(IgnoreReason.notForMe));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('Mute-all', () {
    test('does not mute the teacher who sent it (or any teacher device)', () {
      expect(send(teacherHandler, {'cmd': 'mute_all'}, teacherWeb), ignored(IgnoreReason.notApplicableToTeacher));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('Raise / lower hand (participants speak only for themselves)', () {
    test('raise_hand is attributed to the SENDER identity, not to a name in the payload', () {
      expect(
        send(teacherHandler, {'cmd': 'raise_hand', 'name': 'Ali', 'targetId': 'someone_else'}, student),
        isA<HandRaised>().having((a) => a.identity, 'identity', 's2').having((a) => a.name, 'name', 'Ali'),
      );
    });

    test('raise_hand with missing / empty / non-string name falls back to "Student"', () {
      for (final name in [null, '', 7]) {
        expect(
          send(teacherHandler, {'cmd': 'raise_hand', if (name != null) 'name': name}, student),
          isA<HandRaised>().having((a) => a.name, 'name', 'Student'),
        );
      }
    });

    test('lower_hand from another participant', () {
      expect(send(studentHandler(), MeetProtocol.lowerHandMessage('x'), student),
          isA<HandLowered>().having((a) => a.identity, 'identity', 's2').having((a) => a.isSelf, 'isSelf', false));
    });

    test('our own lower_hand echo resets our button', () {
      expect(send(studentHandler(), MeetProtocol.lowerHandMessage('me'), ('s1', null)),
          isA<HandLowered>().having((a) => a.isSelf, 'isSelf', true));
    });

    test('raise/lower from an unknown sender cannot be attributed → ignored', () {
      expect(send(teacherHandler, MeetProtocol.raiseHandMessage('x'), unknownSender), ignored(IgnoreReason.unknownSender));
      expect(send(teacherHandler, MeetProtocol.lowerHandMessage('x'), unknownSender), ignored(IgnoreReason.unknownSender));
    });

    test('anyone (even a student) may raise their own hand', () {
      expect(send(teacherHandler, MeetProtocol.raiseHandMessage('Ali'), student), isA<HandRaised>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('Garbage and unknown messages never crash and never act', () {
    final garbage = <String, Object>{
      'binary noise': <int>[0, 1, 2, 255, 254],
      'plain text': 'end_meeting_for_all',
      'JSON array': '["end_meeting_for_all"]',
      'empty object': <String, dynamic>{},
      'unknown cmd': {'cmd': 'self_destruct'},
      'unknown type': {'type': 'delete_everything', 'targetId': studentId},
      'web-only alias kick_student (Flutter relies on kick_participant + server kick)': {
        'cmd': 'kick_student',
        'identity': studentId
      },
      'cmd/type swapped: end meeting sent as cmd': {'cmd': 'end_meeting_for_all'},
      'cmd/type swapped: mute_all sent as type': {'type': 'mute_all'},
    };
    garbage.forEach((name, message) {
      test('$name (even from the teacher)', () {
        final action = send(studentHandler(), message, teacherWeb);
        expect(action, isA<IgnoreMessage>());
      });
    });

    test('malformed bytes are reported as malformed', () {
      expect(send(studentHandler(), <int>[0xff], teacherWeb), ignored(IgnoreReason.malformed));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('Round-trip: what the teacher app SENDS is what the student app OBEYS', () {
    test('every teacher message built by MeetProtocol produces the intended action', () {
      final pairs = <Map<String, dynamic>, TypeMatcher<MeetAction>>{
        MeetProtocol.endMeetingMessage(): isA<MeetingEndedByTeacher>(),
        MeetProtocol.kickMessage(studentId): isA<KickedByTeacher>(),
        MeetProtocol.muteMessage(studentId, mic: true): isA<MicMutedByTeacher>(),
        MeetProtocol.muteMessage(studentId, mic: false): isA<CameraDisabledByTeacher>(),
        MeetProtocol.forceLowerHandMessage(studentId): isA<HandForceLowered>(),
      };
      pairs.forEach((message, expected) {
        final action = studentHandler().handle(
          MeetProtocol.encode(message),
          senderIdentity: teacherMobile.$1,
          senderMetadata: teacherMobile.$2,
        );
        expect(action, expected, reason: '$message');
      });
    });
  });

  group('showing a student\'s work to the class (teacher only)', () {
    final show = SharedWorkProtocol.show(
      shareId: 'sh1',
      url: 'https://firebasestorage.googleapis.com/v0/b/x/o/a.jpg?alt=media&token=t',
      kind: SharedWorkKind.image,
      studentName: 'Sara',
      assignmentTitle: 'Alif',
    );
    final stop = SharedWorkProtocol.stop('sh1');

    trusted.forEach((who, sender) {
      test('$who can show, draw and stop', () {
        expect(send(studentHandler(), show, sender), isA<SharedWorkUpdate>().having((a) => a.message, 'message', isA<ShowWork>()));
        expect(send(studentHandler(), stop, sender), isA<SharedWorkUpdate>().having((a) => a.message, 'message', isA<StopWork>()));
      });
    });

    untrusted.forEach((who, sender) {
      test('$who cannot put anything on everyone\'s screen', () {
        expect(send(studentHandler(), show, sender), ignored(IgnoreReason.unauthorizedSender));
        expect(send(studentHandler(), stop, sender), ignored(IgnoreReason.unauthorizedSender));
      });
    });

    test('a teacher message with a bad link or junk is dropped', () {
      expect(send(studentHandler(), {...show, 'url': 'https://evil.example.com/a.jpg'}, teacherMobile), ignored(IgnoreReason.malformed));
      expect(send(studentHandler(), {'type': MeetProtocol.workStroke, 'shareId': 'sh1'}, teacherMobile), ignored(IgnoreReason.malformed));
    });
  });
}
