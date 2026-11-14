import 'dart:async';

import 'package:calligro_app/features/meet/application/pre_join_controller.dart';
import 'package:calligro_app/features/meet/domain/meet_media.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_media_devices.dart';

/// The pre-join screen's behaviour, driven through fake devices.
/// Written BEFORE PreJoinController (test-first).
void main() {
  late FakeMediaDevices devices;
  late FakeProfileSource profile;
  late PreJoinController c;

  PreJoinController make({bool teacher = false}) =>
      PreJoinController(devices: devices, profile: profile, isTeacher: teacher);

  Future<PreJoinController> ready({bool teacher = false}) async {
    final controller = make(teacher: teacher);
    await controller.init();
    return controller;
  }

  setUp(() {
    devices = FakeMediaDevices();
    profile = FakeProfileSource();
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('starting', () {
    test('a student starts with mic and camera OFF and no preview', () async {
      c = await ready();
      expect(c.micOn, isFalse);
      expect(c.cameraOn, isFalse);
      expect(c.preview, isNull);
      expect(devices.previews, isEmpty);
    });

    test('a teacher starts with mic ON (permission asked) and a live camera preview', () async {
      c = await ready(teacher: true);
      expect(devices.micRequests, 1, reason: 'the mic must not be switched on without permission');
      expect(c.micOn, isTrue);
      expect(c.cameraOn, isTrue);
      expect(c.preview, isNotNull);
      expect(devices.running.single.position, MeetCameraPosition.front);
    });

    test('teacher denied mic / camera → they start off', () async {
      devices
        ..micGranted = false
        ..cameraGranted = false;
      c = await ready(teacher: true);
      expect(c.micOn, isFalse);
      expect(c.cameraOn, isFalse);
      expect(devices.previews, isEmpty);
    });

    test('teacher camera fails to open → camera off, with a reason', () async {
      devices.nextCameraError = Exception('camera in use');
      c = await ready(teacher: true);
      expect(c.cameraOn, isFalse);
      expect(c.preview, isNull);
      expect(c.lastError, contains('camera in use'));
    });

    test('loads the name and avatar', () async {
      c = make();
      expect(c.userName, isNull, reason: 'loading');
      await c.init();
      expect(c.userName, 'Student One');
      expect(c.avatarUrl, 'https://img/s1.png');
    });

    test('profile can\'t be loaded → a fallback name instead of "Loading..." forever', () async {
      profile.error = Exception('offline');
      c = await ready();
      expect(c.userName, PreJoinController.fallbackName);
      expect(c.avatarUrl, isNull);
    });

    test('an empty avatar is treated as none', () async {
      profile.profile = const MeetUserProfile(name: 'Ali', avatarUrl: '');
      c = await ready();
      expect(c.avatarUrl, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('microphone', () {
    test('turning it on asks for permission; off needs nothing', () async {
      c = await ready();
      await c.toggleMicrophone();
      expect(c.micOn, isTrue);
      expect(devices.micRequests, 1);
      await c.toggleMicrophone();
      expect(c.micOn, isFalse);
      expect(devices.micRequests, 1);
    });

    test('permission denied → stays off', () async {
      devices.micGranted = false;
      c = await ready();
      await c.toggleMicrophone();
      expect(c.micOn, isFalse);
      expect(c.lastError, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('camera', () {
    test('on → permission + preview; off → preview stopped', () async {
      c = await ready();
      await c.toggleCamera();
      expect(c.cameraOn, isTrue);
      expect(devices.cameraRequests, 1);
      expect(devices.running, hasLength(1));
      await c.toggleCamera();
      expect(c.cameraOn, isFalse);
      expect(c.preview, isNull);
      expect(devices.running, isEmpty);
    });

    test('permission denied → stays off, no preview', () async {
      devices.cameraGranted = false;
      c = await ready();
      await c.toggleCamera();
      expect(c.cameraOn, isFalse);
      expect(devices.previews, isEmpty);
    });

    test('double-tap while the camera is opening → only ONE camera is opened', () async {
      c = await ready();
      devices.cameraGate = Completer<void>();
      final first = c.toggleCamera();
      final second = c.toggleCamera(); // impatient double tap
      expect(c.isBusy, isTrue);
      devices.cameraGate!.complete();
      await Future.wait([first, second]);
      expect(devices.previews, hasLength(1));
      expect(c.cameraOn, isTrue);
    });

    test('flip: new camera at the other position, old one stopped', () async {
      c = await ready();
      await c.toggleCamera();
      await c.flipCamera();
      expect(c.cameraPosition, MeetCameraPosition.back);
      expect(devices.running.single.position, MeetCameraPosition.back);
      expect(devices.previews.first.stopped, isTrue);
      await c.flipCamera();
      expect(c.cameraPosition, MeetCameraPosition.front);
      expect(devices.running, hasLength(1));
    });

    test('flip fails → camera reported OFF (no "on" without a preview), nothing left running', () async {
      c = await ready();
      await c.toggleCamera();
      devices.nextCameraError = Exception('back camera unavailable');
      await c.flipCamera();
      expect(c.cameraOn, isFalse);
      expect(c.preview, isNull);
      expect(devices.running, isEmpty);
      expect(c.lastError, contains('back camera unavailable'));
    });

    test('flip with the camera off does nothing', () async {
      c = await ready();
      await c.flipCamera();
      expect(c.cameraPosition, MeetCameraPosition.front);
      expect(devices.previews, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('joining', () {
    test('returns the chosen settings and frees the camera first', () async {
      c = await ready();
      await c.toggleMicrophone();
      await c.toggleCamera();
      await c.flipCamera();
      final settings = await c.join();
      expect(settings, isNotNull);
      expect(settings!.startWithMic, isTrue);
      expect(settings.startWithCamera, isTrue);
      expect(settings.cameraPosition, MeetCameraPosition.back);
      expect(devices.running, isEmpty, reason: 'the class needs the camera hardware');
      expect(c.isJoining, isTrue);
    });

    test('permissions are re-checked; a revoked one starts the class without that device', () async {
      c = await ready();
      await c.toggleMicrophone();
      await c.toggleCamera();
      devices
        ..micGranted = false
        ..cameraGranted = false; // revoked in Settings meanwhile
      final settings = await c.join();
      expect(settings!.startWithMic, isFalse);
      expect(settings.startWithCamera, isFalse);
    });

    test('joining twice (double tap) only joins once', () async {
      c = await ready();
      final results = await Future.wait([c.join(), c.join()]);
      expect(results.whereType<PreJoinSettings>(), hasLength(1));
      expect(results.where((r) => r == null), hasLength(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('leaving the screen', () {
    test('back → the preview is stopped', () async {
      c = await ready();
      await c.toggleCamera();
      c.dispose();
      expect(devices.running, isEmpty);
    });

    test('back while the camera is still opening → it is stopped as soon as it opens', () async {
      devices.cameraGate = Completer<void>();
      c = make(teacher: true);
      final init = c.init();
      await pumpEventQueue();
      c.dispose();
      devices.cameraGate!.complete();
      await init;
      expect(devices.previews, hasLength(1));
      expect(devices.running, isEmpty, reason: 'no camera left running after leaving');
    });

    test('a profile arriving after leaving does not crash', () async {
      final gate = Completer<void>();
      final slow = _SlowProfile(gate.future);
      final controller = PreJoinController(devices: devices, profile: slow, isTeacher: false);
      final init = controller.init();
      controller.dispose();
      gate.complete();
      await expectLater(init, completes);
    });
  });
}

class _SlowProfile implements MeetProfileSource {
  final Future<void> gate;
  _SlowProfile(this.gate);
  @override
  Future<MeetUserProfile> load() async {
    await gate;
    return const MeetUserProfile(name: 'Late');
  }
}
