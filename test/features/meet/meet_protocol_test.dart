import 'dart:convert';

import 'package:calligro_app/features/meet/logic/meet_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the REAL protocol code used by calligro_meet_page.dart.
/// The wire strings are shared with the web portal: if one of these values
/// changes, the web client must change too — that's why they are pinned here.
void main() {
  group('Wire values (shared with the web portal — do not change casually)', () {
    test('cmd values', () {
      expect(MeetProtocol.raiseHand, 'raise_hand');
      expect(MeetProtocol.lowerHand, 'lower_hand');
      expect(MeetProtocol.forceLowerHand, 'force_lower_hand');
      expect(MeetProtocol.muteAll, 'mute_all');
    });

    test('type values', () {
      expect(MeetProtocol.endMeetingForAll, 'end_meeting_for_all');
      expect(MeetProtocol.kickParticipant, 'kick_participant');
      expect(MeetProtocol.forceMuteMic, 'force_mute_mic');
      expect(MeetProtocol.forceMuteCamera, 'force_mute_camera');
    });
  });

  group('Outgoing message builders', () {
    test('raise / lower hand carry the sender name under "cmd"', () {
      expect(MeetProtocol.raiseHandMessage('Ali'), {'cmd': 'raise_hand', 'name': 'Ali'});
      expect(MeetProtocol.lowerHandMessage('Ali'), {'cmd': 'lower_hand', 'name': 'Ali'});
    });

    test('force lower hand targets one identity', () {
      expect(MeetProtocol.forceLowerHandMessage('s1'), {'cmd': 'force_lower_hand', 'targetId': 's1'});
    });

    test('end meeting uses "type"', () {
      expect(MeetProtocol.endMeetingMessage(), {'type': 'end_meeting_for_all'});
    });

    test('kick and mute target one identity under "type"', () {
      expect(MeetProtocol.kickMessage('s1'), {'type': 'kick_participant', 'targetId': 's1'});
      expect(MeetProtocol.muteMessage('s1', mic: true), {'type': 'force_mute_mic', 'targetId': 's1'});
      expect(MeetProtocol.muteMessage('s1', mic: false), {'type': 'force_mute_camera', 'targetId': 's1'});
    });

    test('every builder round-trips through encode → tryDecode unchanged', () {
      final all = [
        MeetProtocol.raiseHandMessage('علي'), // non-ASCII names survive UTF-8
        MeetProtocol.lowerHandMessage('Zeynep Öztürk'),
        MeetProtocol.forceLowerHandMessage('s1'),
        MeetProtocol.endMeetingMessage(),
        MeetProtocol.kickMessage('s1'),
        MeetProtocol.muteMessage('s1', mic: true),
        MeetProtocol.muteMessage('s1', mic: false),
      ];
      for (final m in all) {
        expect(MeetProtocol.tryDecode(MeetProtocol.encode(m)), m);
      }
    });
  });

  group('tryDecode rejects anything that is not a JSON object', () {
    final cases = <String, List<int>>{
      'empty bytes': <int>[],
      'invalid UTF-8': [0xff, 0xfe, 0xfd],
      'not JSON': utf8.encode('hello'),
      'JSON array': utf8.encode('[1,2,3]'),
      'JSON string': utf8.encode('"end_meeting_for_all"'),
      'JSON number': utf8.encode('42'),
      'JSON null': utf8.encode('null'),
      'truncated JSON': utf8.encode('{"type": "end_meeting'),
    };
    cases.forEach((name, bytes) {
      test(name, () => expect(MeetProtocol.tryDecode(bytes), isNull));
    });
  });

  group('displayName', () {
    test('prefers the name, then the identity, then "Student"', () {
      expect(MeetProtocol.displayName('Ali', 'u1'), 'Ali');
      expect(MeetProtocol.displayName('', 'u1'), 'u1');
      expect(MeetProtocol.displayName('', ''), 'Student');
    });
  });

  group('MeetSenderVerifier.isTeacherOrModerator', () {
    String meta(Map<String, dynamic> m) => jsonEncode(m);
    const teacher = 'T1';

    test('null sender is never trusted (even with moderator metadata)', () {
      expect(
        MeetSenderVerifier.isTeacherOrModerator(
            identity: null, metadata: meta({'role': 'moderator', 'teacherId': teacher}), teacherId: teacher),
        isFalse,
      );
    });

    test('the course teacher identity is trusted (web identity and mobile identity)', () {
      expect(MeetSenderVerifier.isTeacherOrModerator(identity: 'T1', metadata: null, teacherId: teacher), isTrue);
      expect(
          MeetSenderVerifier.isTeacherOrModerator(identity: 'T1_mobile', metadata: null, teacherId: teacher), isTrue);
    });

    test('look-alike identities are NOT trusted', () {
      for (final id in ['T1_mobile_x', 'xT1', 'T1x', 't1', 'T1_web', '_mobile', '']) {
        expect(MeetSenderVerifier.isTeacherOrModerator(identity: id, metadata: null, teacherId: teacher), isFalse,
            reason: 'identity "$id" must not be trusted');
      }
    });

    test('a moderator token for THIS course is trusted (e.g. platform admin)', () {
      expect(
        MeetSenderVerifier.isTeacherOrModerator(
            identity: 'admin1', metadata: meta({'role': 'moderator', 'teacherId': teacher}), teacherId: teacher),
        isTrue,
      );
    });

    test('a moderator token naming ANOTHER course teacher is not trusted', () {
      expect(
        MeetSenderVerifier.isTeacherOrModerator(
            identity: 'x', metadata: meta({'role': 'moderator', 'teacherId': 'OTHER'}), teacherId: teacher),
        isFalse,
      );
    });

    test('moderator metadata without teacherId is trusted when the page has no teacherId', () {
      expect(
        MeetSenderVerifier.isTeacherOrModerator(
            identity: 'x', metadata: meta({'role': 'moderator'}), teacherId: null),
        isTrue,
      );
      expect(
        MeetSenderVerifier.isTeacherOrModerator(identity: 'x', metadata: meta({'role': 'moderator'}), teacherId: ''),
        isTrue,
      );
    });

    test('students and broken metadata are never trusted', () {
      for (final m in [
        null,
        '',
        meta({'role': 'participant', 'teacherId': teacher}),
        meta({'role': 'Moderator'}), // case-sensitive
        meta({'role': ['moderator']}),
        '{"role":"moderator"', // truncated JSON
        '"moderator"', // not an object
        'role=moderator',
      ]) {
        expect(MeetSenderVerifier.isTeacherOrModerator(identity: 's1', metadata: m, teacherId: teacher), isFalse,
            reason: 'metadata $m must not be trusted');
      }
    });
  });

  group('metadata helpers', () {
    test('isModeratorMetadata', () {
      expect(MeetSenderVerifier.isModeratorMetadata('{"role":"moderator"}'), isTrue);
      expect(MeetSenderVerifier.isModeratorMetadata('{"role": "moderator"}'), isTrue); // spacing doesn't matter
      expect(MeetSenderVerifier.isModeratorMetadata('{"role":"participant"}'), isFalse);
      expect(MeetSenderVerifier.isModeratorMetadata(null), isFalse);
      expect(MeetSenderVerifier.isModeratorMetadata('not json'), isFalse);
    });

    test('avatarFromMetadata ignores missing, empty, "null" and non-string avatars', () {
      expect(MeetSenderVerifier.avatarFromMetadata('{"avatar":"https://a/b.png"}'), 'https://a/b.png');
      expect(MeetSenderVerifier.avatarFromMetadata('{"avatar":null}'), isNull);
      expect(MeetSenderVerifier.avatarFromMetadata('{"avatar":""}'), isNull);
      expect(MeetSenderVerifier.avatarFromMetadata('{"avatar":"null"}'), isNull);
      expect(MeetSenderVerifier.avatarFromMetadata('{"avatar":5}'), isNull);
      expect(MeetSenderVerifier.avatarFromMetadata(null), isNull);
      expect(MeetSenderVerifier.avatarFromMetadata('broken'), isNull);
    });
  });
}
