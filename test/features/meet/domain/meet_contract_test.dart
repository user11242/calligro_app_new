import 'dart:convert';
import 'dart:io';

import 'package:calligro_app/features/meet/domain/meet_message_handler.dart';
import 'package:calligro_app/features/meet/domain/meet_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Calligro Meet contract with the WEBSITE (test/fixtures/meet_messages.json):
/// the website's tests run the same cases, so app ↔ web classes keep working.
void main() {
  final contract = jsonDecode(File('test/fixtures/meet_messages.json').readAsStringSync()) as Map<String, dynamic>;
  final senders = (contract['senders'] as Map).cast<String, dynamic>();
  final receivers = (contract['receivers'] as Map).cast<String, dynamic>();

  String actionName(MeetAction a) => switch (a) {
        HandRaised() => 'handRaised',
        HandLowered() => 'handLowered',
        HandForceLowered() => 'handForceLowered',
        MutedByMuteAll() => 'mutedAll',
        MicMutedByTeacher() => 'micMuted',
        CameraDisabledByTeacher() => 'cameraDisabled',
        KickedByTeacher() => 'kicked',
        MeetingEndedByTeacher() => 'meetingEnded',
        IgnoreMessage() => 'ignored',
        SharedWorkUpdate() => 'sharedWork',
      };

  group('every message the website and the app exchange means the same here', () {
    for (final c in (contract['cases'] as List).cast<Map<String, dynamic>>()) {
      final sender = (senders[c['from']] as Map).cast<String, dynamic>();
      (c['expect'] as Map).cast<String, String>().forEach((receiverName, expected) {
        test('${c['name']} → $receiverName: $expected', () {
          final r = (receivers[receiverName] as Map).cast<String, dynamic>();
          final handler = MeetMessageHandler(
            localIdentity: r['identity'] as String,
            isTeacher: r['isTeacher'] as bool,
            isModerator: r['isModerator'] as bool,
            teacherId: 'T1',
          );
          final action = handler.handle(
            utf8.encode(jsonEncode(c['message'])),
            senderIdentity: sender['identity'] as String?,
            senderMetadata: sender['metadata'] as String?,
          );
          expect(actionName(action), expected);
        });
      });
    }
  });

  test('what the app SENDS is exactly what the website expects', () {
    final sent = (contract['sent'] as Map)['app'] as Map;
    expect(MeetProtocol.raiseHandMessage('Sara'), sent['raiseHand']);
    expect(MeetProtocol.lowerHandMessage('Sara'), sent['lowerHand']);
    expect(MeetProtocol.forceLowerHandMessage('s1'), sent['forceLowerHand']);
    expect(MeetProtocol.muteMessage('s1', mic: true), sent['muteMic']);
    expect(MeetProtocol.muteMessage('s1', mic: false), sent['muteCamera']);
    expect(MeetProtocol.kickMessage('s1'), sent['kick']);
    expect(MeetProtocol.endMeetingMessage(), sent['endMeeting']);
  });
}
