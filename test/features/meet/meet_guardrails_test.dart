import 'dart:io';

import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/domain/meet_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// Architecture guard rails for Calligro Meet.
///
///   presentation → application → domain ← data
///
/// These fail when a change breaks the layering (which is what keeps the meet
/// testable), bypasses the tested logic, or breaks the contract with the backend.
void main() {
  const root = 'lib/features/meet';
  final backendJs = File('functions/livekit.js').readAsStringSync();

  Map<String, String> sources(String dir) => {
        for (final f in Directory('$root/$dir').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
      };

  final domain = sources('domain');
  final application = sources('application');
  final data = sources('data');
  final presentation = sources('presentation');

  void expectNone(Map<String, String> files, Pattern pattern, String why, {Set<String> allow = const {}}) {
    for (final entry in files.entries) {
      if (allow.any(entry.key.endsWith)) continue;
      expect(entry.value.contains(pattern), isFalse, reason: '${entry.key}: $why');
    }
  }

  String file(Map<String, String> layer, String name) => layer.entries.firstWhere((e) => e.key.endsWith(name)).value;

  group('Layering', () {
    test('all four layers exist', () {
      for (final layer in [domain, application, data, presentation]) {
        expect(layer, isNotEmpty);
      }
    });

    test('domain is pure Dart: no Flutter, Firebase, LiveKit or other layers', () {
      expectNone(domain, 'package:flutter/', 'domain must not depend on Flutter');
      expectNone(domain, 'package:livekit_client', 'domain must not depend on LiveKit');
      expectNone(domain, 'firebase', 'domain must not depend on Firebase');
      expectNone(domain, '/application/', 'domain must not depend on application');
      expectNone(domain, '/data/', 'domain must not depend on data');
      expectNone(domain, '/presentation/', 'domain must not depend on presentation');
    });

    test('application talks to the outside only through interfaces (no LiveKit / Firebase / UI)', () {
      expectNone(application, 'package:livekit_client', 'use the MeetRoom interface');
      expectNone(application, 'cloud_functions', 'use MeetBackend');
      expectNone(application, 'package:flutter/material.dart', 'no widgets in the application layer');
      expectNone(application, '/presentation/', 'application must not depend on presentation');
    });

    test('data does not depend on application or presentation', () {
      expectNone(data, '/application/', 'data must not depend on application');
      expectNone(data, '/presentation/', 'data must not depend on presentation');
    });

    test('only the data layer touches LiveKit (the one exception: the video renderer)', () {
      expectNone(presentation, 'package:livekit_client', 'use MeetRoom / MeetMediaDevices / MeetVideo',
          allow: {'participant_tile.dart'});
      expect(file(presentation, 'participant_tile.dart'), contains('show VideoTrack, VideoTrackRenderer, VideoViewFit'),
          reason: 'the tile may only use LiveKit to render video');
    });

    test('the UI never asks for permissions or reads Firebase itself', () {
      expectNone(presentation, 'permission_handler', 'use MeetMediaDevices');
      expectNone(presentation, 'cloud_firestore', 'use MeetProfileSource / MeetBackend');
      expectNone(presentation, 'firebase_auth', 'use MeetProfileSource');
      expectNone(application, 'permission_handler', 'use MeetMediaDevices');
    });

    test('the UI never calls Cloud Functions or decodes data messages itself', () {
      expectNone(presentation, 'httpsCallable', 'use MeetController / MeetBackend');
      expectNone(presentation, 'FirebaseFunctions', 'use MeetController / MeetBackend');
      expectNone(presentation, 'jsonDecode(', 'decoding belongs in MeetProtocol');
      expectNone(application, 'jsonDecode(', 'decoding belongs in MeetProtocol');
    });

    test('protocol strings live only in MeetProtocol', () {
      final outside = <String, String>{
        ...application,
        ...data,
        ...presentation,
        for (final e in domain.entries)
          if (!e.key.endsWith('meet_protocol.dart')) e.key: e.value,
      };
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
        // The server action "mute_all" (MeetModerationAction) shares the name with the data-message command.
        expectNone(outside, "'$wire'", '"$wire" must come from MeetProtocol',
            allow: wire == MeetProtocol.muteAll ? {'meet_backend.dart'} : const {});
      }
    });

    test('moderation action names live only in MeetBackend', () {
      final outside = {...application, ...presentation, ...domain};
      for (final action in ["'stop_recording'", "'end_room'", "'mute_mic'", "'mute_camera'", "'kick'"]) {
        expectNone(outside, action, 'use MeetModerationAction instead of $action');
      }
    });
  });

  group('The controller delegates every decision to tested rules', () {
    late final controller = file(application, 'meet_controller.dart');
    late final recording = file(application, 'recording_controller.dart');

    test('messages, disconnects, lifecycle and layout', () {
      expect(controller, contains('MeetMessageHandler('));
      expect(controller, contains('DisconnectPolicy.decide('));
      expect(controller, contains('LifecycleCameraPolicy.shouldDisableCameraOnPause('));
      expect(controller, contains('LifecycleCameraPolicy.shouldRestoreCameraOnResume('));
      expect(controller, contains('StageLayoutPolicy.select('));
      expect(controller, contains('StageLayoutPolicy.gridColumns('));
    });

    test('recording start goes through RecordingPolicy and MeetBackend retries', () {
      expect(recording, contains('RecordingPolicy.evaluate('));
      expect(recording, contains('_backend.startRecording('));
    });

    test('moderation is server-enforced; leaving never ends the class', () {
      expect(controller, contains('MeetModerationAction.kick'));
      expect(controller, contains('MeetModerationAction.muteMic'));
      expect(controller, contains('_backend.endRoom()'));
      expect(recording, contains('_backend.stopRecording()'));
    });

    test('the pre-join screen goes through PreJoinController', () {
      final page = file(presentation, 'calligro_pre_join_page.dart');
      expect(page, contains('PreJoinController('));
      expect(page, contains('_controller.join()'));
      expect(page, isNot(contains('createCameraTrack')));
    });

    test('"Rejoin" fetches a fresh token', () {
      expect(controller, contains('_backend.fetchToken()'));
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

    test('the responses contain what the app parses', () {
      for (final field in ['token,', 'roomName:', 'serverUrl:', 'teacherId:', 'playbackUrl, qualities']) {
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
