import 'dart:io';

import 'package:calligro_app/features/meet/logic/meet_backend.dart';
import 'package:calligro_app/features/meet/logic/meet_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guard rails: these fail when someone changes Calligro Meet in a way that
/// silently bypasses the tested logic, or breaks the contract with the backend.
///
/// The meet page itself can't run in a unit test (it needs a live LiveKit room),
/// so instead we make sure it keeps delegating every decision to the tested
/// classes in lib/features/meet/logic/.
void main() {
  final page = File('lib/features/meet/pages/calligro_meet_page.dart').readAsStringSync();
  final backendJs = File('functions/livekit.js').readAsStringSync();

  group('The meet page delegates decisions to the tested logic', () {
    test('incoming data messages go through MeetMessageHandler', () {
      expect(page, contains('MeetMessageHandler('));
      expect(page, contains('_applyMeetAction(action)'));
    });

    test('the page does not decode data messages or check senders by itself', () {
      expect(page, isNot(contains('jsonDecode(')), reason: 'decode via MeetProtocol.tryDecode');
      expect(page, isNot(contains("'role'")), reason: 'role checks belong in MeetSenderVerifier');
      expect(page, isNot(contains('"role":"moderator"')), reason: 'no string matching on metadata');
    });

    test('no hand-written protocol strings in the page (use MeetProtocol builders)', () {
      for (final wire in [
        MeetProtocol.raiseHand,
        MeetProtocol.lowerHand,
        MeetProtocol.forceLowerHand,
        MeetProtocol.muteAll,
        MeetProtocol.endMeetingForAll,
        MeetProtocol.kickParticipant,
        MeetProtocol.forceMuteMic,
        MeetProtocol.forceMuteCamera,
      ]) {
        expect(page, isNot(contains("'$wire'")), reason: '"$wire" is hard-coded in the page');
      }
    });

    test('no direct Cloud Function calls from the page (use MeetBackend)', () {
      expect(page, isNot(contains('httpsCallable')));
      expect(page, isNot(contains('FirebaseFunctions')));
      for (final action in ["'stop_recording'", "'end_room'", "'mute_mic'", "'mute_camera'", "'kick'"]) {
        expect(page, isNot(contains(action)), reason: 'use MeetModerationAction instead of $action');
      }
    });

    test('disconnects, recording start, lifecycle and stage layout use the tested policies', () {
      expect(page, contains('DisconnectPolicy.decide('));
      expect(page, contains('RecordingPolicy.evaluate('));
      expect(page, contains('_backend.startRecording('));
      expect(page, contains('LifecycleCameraPolicy.shouldDisableCameraOnPause('));
      expect(page, contains('LifecycleCameraPolicy.shouldRestoreCameraOnResume('));
      expect(page, contains('StageLayoutPolicy.select('));
      expect(page, contains('StageLayoutPolicy.gridColumns('));
    });

    test('teacher moderation is enforced on the server, not only by a data message', () {
      expect(page, contains('_moderateOnServer(MeetModerationAction.kick'));
      expect(page, contains('MeetModerationAction.muteMic'));
      expect(page, contains('_backend.endRoom()'));
    });

    test('leaving as teacher stops the recording but never ends the class', () {
      expect(page, contains('_moderateOnServer(MeetModerationAction.stopRecording)'));
      expect(page, contains('_backend.stopRecording()'), reason: 'dispose() fail-safe');
    });

    test('"Rejoin" fetches a fresh token instead of reusing the original one', () {
      expect(page, contains('_backend.fetchToken()'));
      expect(page, contains('_refreshToken()'));
    });
  });

  group('Contract with functions/livekit.js', () {
    String fnName(String full) => full.replaceFirst('livekit-', '');

    test('every Cloud Function the app calls is exported by the backend', () {
      for (final f in [
        MeetBackend.tokenFunction,
        MeetBackend.moderateFunction,
        MeetBackend.startRecordingFunction,
        MeetBackend.playbackUrlFunction,
      ]) {
        expect(backendJs, contains('exports.${fnName(f)} = onCall('), reason: '$f is not exported');
      }
    });

    test('every moderation action the app sends is handled by the backend', () {
      for (final action in [
        MeetModerationAction.muteMic,
        MeetModerationAction.muteCamera,
        MeetModerationAction.kick,
        MeetModerationAction.muteAll,
        MeetModerationAction.stopRecording,
        MeetModerationAction.endRoom,
      ]) {
        expect(backendJs, contains('action === "$action"'), reason: 'backend does not handle "$action"');
      }
    });

    test('the backend reads the exact request fields the app sends', () {
      expect(backendJs, contains('const { courseId, source } = request.data'));
      expect(backendJs, contains('const { courseId, targetIdentity, action } = request.data'));
      expect(backendJs, contains('const { courseId, audioTrackId, videoTrackId, orientation } = request.data'));
      expect(backendJs, contains('const { courseId, recordingId } = request.data'));
    });

    test('the token response contains what the app parses', () {
      for (final field in ['token,', 'roomName:', 'serverUrl:', 'teacherId:']) {
        expect(backendJs, contains(field));
      }
    });

    test('moderator role written by the backend matches what the app trusts', () {
      expect(backendJs, contains('role: isModerator ? "moderator" : "participant"'));
      expect(backendJs, contains('canUpdateOwnMetadata: false'),
          reason: 'if students can edit metadata, MeetSenderVerifier can be fooled');
      expect(backendJs, contains('`\${uid}_mobile`'), reason: 'teacher mobile identity format');
    });
  });
}
