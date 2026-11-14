import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';

/// Deep-compares recorded calls (records compare nested maps by identity).
void expectCalls(FakeFunctions fn, List<(String, Map<String, dynamic>)> expected) {
  expect(fn.calls.map((c) => [c.$1, c.$2]).toList(), equals(expected.map((c) => [c.$1, c.$2]).toList()));
}

void main() {
  late FakeFunctions fn;
  late List<Duration> waits;
  late MeetBackend backend;

  setUp(() {
    fn = FakeFunctions();
    waits = [];
    backend = MeetBackend(
      courseId: 'c1',
      call: fn.call,
      delay: (d) async => waits.add(d),
    );
  });

  group('Contract with functions/livekit.js', () {
    test('function names and region', () {
      expect(MeetBackend.region, 'us-central1');
      expect(MeetBackend.tokenFunction, 'livekit-generateLiveKitToken');
      expect(MeetBackend.moderateFunction, 'livekit-moderateParticipant');
      expect(MeetBackend.startRecordingFunction, 'livekit-startAutomatedRecording');
      expect(MeetBackend.playbackUrlFunction, 'livekit-getRecordingPlaybackUrl');
    });

    test('moderation action names', () {
      expect(MeetModerationAction.muteMic, 'mute_mic');
      expect(MeetModerationAction.muteCamera, 'mute_camera');
      expect(MeetModerationAction.kick, 'kick');
      expect(MeetModerationAction.muteAll, 'mute_all');
      expect(MeetModerationAction.stopRecording, 'stop_recording');
      expect(MeetModerationAction.endRoom, 'end_room');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('fetchToken', () {
    test('sends courseId + source "mobile" and parses the response', () async {
      fn.answerWith({'token': 'jwt', 'serverUrl': 'wss://lk', 'roomName': 'CG_x', 'teacherId': 'T1'});
      final t = await backend.fetchToken();
      expectCalls(fn, [('livekit-generateLiveKitToken', {'courseId': 'c1', 'source': 'mobile'})]);
      expect(t.token, 'jwt');
      expect(t.serverUrl, 'wss://lk');
      expect(t.roomName, 'CG_x');
      expect(t.teacherId, 'T1');
    });

    test('teacherId is optional', () async {
      fn.answerWith({'token': 'jwt', 'serverUrl': 'wss://lk', 'roomName': 'CG_x'});
      expect((await backend.fetchToken()).teacherId, isNull);
    });

    test('rejects malformed responses instead of crashing later', () async {
      for (final bad in [
        null,
        'jwt',
        <String, dynamic>{},
        {'token': 'jwt', 'serverUrl': 'wss://lk'}, // no roomName
        {'token': 1, 'serverUrl': 'wss://lk', 'roomName': 'r'},
      ]) {
        fn = FakeFunctions()..answerWith(bad);
        backend = MeetBackend(courseId: 'c1', call: fn.call);
        await expectLater(backend.fetchToken(), throwsFormatException, reason: '$bad');
      }
    });

    test('server errors (e.g. kicked / not enrolled) propagate to the caller', () async {
      fn.failWith(Exception('permission-denied'));
      await expectLater(backend.fetchToken(), throwsException);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('moderate', () {
    test('mute mic / mute camera / kick send the target identity', () async {
      await backend.moderate(MeetModerationAction.muteMic, targetIdentity: 's1');
      await backend.moderate(MeetModerationAction.muteCamera, targetIdentity: 's1');
      await backend.moderate(MeetModerationAction.kick, targetIdentity: 's1');
      expectCalls(fn, [
        ('livekit-moderateParticipant', {'courseId': 'c1', 'action': 'mute_mic', 'targetIdentity': 's1'}),
        ('livekit-moderateParticipant', {'courseId': 'c1', 'action': 'mute_camera', 'targetIdentity': 's1'}),
        ('livekit-moderateParticipant', {'courseId': 'c1', 'action': 'kick', 'targetIdentity': 's1'}),
      ]);
    });

    test('targeted actions without a target fail locally (no server call)', () async {
      for (final action in [MeetModerationAction.muteMic, MeetModerationAction.muteCamera, MeetModerationAction.kick]) {
        await expectLater(backend.moderate(action), throwsArgumentError);
        await expectLater(backend.moderate(action, targetIdentity: ''), throwsArgumentError);
      }
      expect(fn.calls, isEmpty);
    });

    test('mute all needs no target', () async {
      await backend.moderate(MeetModerationAction.muteAll);
      expect(fn.calls.single.$2, {'courseId': 'c1', 'action': 'mute_all'});
    });

    test('stopRecording ≠ endRoom: leaving must never end the class for everyone', () async {
      await backend.stopRecording();
      await backend.endRoom();
      expect(fn.calls.map((c) => c.$2['action']), ['stop_recording', 'end_room']);
      expect(fn.calls.every((c) => c.$1 == 'livekit-moderateParticipant'), isTrue);
    });

    test('server errors propagate (the page shows "Action failed")', () async {
      fn.failWith(Exception('permission-denied'));
      await expectLater(backend.moderate(MeetModerationAction.kick, targetIdentity: 's1'), throwsException);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('startRecording', () {
    test('sends both track SIDs and landscape orientation; succeeds on first try', () async {
      final attempts = await backend.startRecording(audioTrackSid: 'TR_a', videoTrackSid: 'TR_v');
      expect(attempts, 1);
      expectCalls(fn, [
        (
          'livekit-startAutomatedRecording',
          {'courseId': 'c1', 'audioTrackId': 'TR_a', 'videoTrackId': 'TR_v', 'orientation': 'landscape'}
        )
      ]);
      expect(waits, isEmpty);
    });

    test('retries with 1.2s then 2.4s backoff and succeeds on the 3rd attempt', () async {
      fn
        ..failWith(Exception('busy'))
        ..failWith(Exception('busy'))
        ..answerWith({'status': 'started'});
      expect(await backend.startRecording(audioTrackSid: 'a', videoTrackSid: 'v'), 3);
      expect(waits, [const Duration(milliseconds: 1200), const Duration(milliseconds: 2400)]);
      expect(fn.calls, hasLength(3));
    });

    test('gives up after 3 attempts and rethrows the LAST error (no wait after the last try)', () async {
      fn
        ..failWith(Exception('e1'))
        ..failWith(Exception('e2'))
        ..failWith(Exception('e3'));
      await expectLater(
        backend.startRecording(audioTrackSid: 'a', videoTrackSid: 'v'),
        throwsA(predicate((e) => e.toString().contains('e3'))),
      );
      expect(fn.calls, hasLength(3));
      expect(waits, hasLength(2));
    });

    test('stops retrying as soon as the page is closed', () async {
      var open = true;
      fn.answer((_, _) {
        open = false; // page closed during the first attempt
        throw Exception('busy');
      });
      await expectLater(
        backend.startRecording(audioTrackSid: 'a', videoTrackSid: 'v', shouldContinue: () => open),
        throwsException,
      );
      expect(fn.calls, hasLength(1));
      expect(waits, isEmpty);
    });

    test('does not call the server at all if the page is already closed', () async {
      await expectLater(
        backend.startRecording(audioTrackSid: 'a', videoTrackSid: 'v', shouldContinue: () => false),
        throwsStateError,
      );
      expect(fn.calls, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('playback', () {
    test('asks by recordingId (never by file path) and returns the signed URL', () async {
      fn.answerWith({'success': true, 'playbackUrl': 'https://signed'});
      final p = await backend.playback('eg1');
      expect(p.url, 'https://signed');
      expect(p.qualities, {'1080p': 'https://signed'});
      expectCalls(fn, [('livekit-getRecordingPlaybackUrl', {'courseId': 'c1', 'recordingId': 'eg1'})]);
      expect(fn.calls.single.$2.containsKey('r2FilePath'), isFalse);
    });

    test('returns every signed quality the server sends, ignoring malformed entries', () async {
      fn.answerWith({
        'playbackUrl': 'https://signed/orig',
        'qualities': {'1080p': 'https://signed/orig', '720p': 'https://signed/720', '480p': '', '360p': 5, 7: 'x'},
      });
      final p = await backend.playback('eg1');
      expect(p.qualities, {'1080p': 'https://signed/orig', '720p': 'https://signed/720'});
    });

    test('missing / empty URL is an error', () async {
      for (final bad in [null, <String, dynamic>{}, {'playbackUrl': ''}, {'playbackUrl': 5}]) {
        fn = FakeFunctions()..answerWith(bad);
        backend = MeetBackend(courseId: 'c1', call: fn.call);
        await expectLater(backend.playback('eg1'), throwsFormatException, reason: '$bad');
      }
    });
  });
}
