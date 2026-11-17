import 'package:calligro_app/features/meet/application/connection_quality_monitor.dart';
import 'package:calligro_app/features/meet/application/meet_controller.dart';
import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/domain/meet_policies.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';
import '../fakes/fake_meet_room.dart';

/// The teacher zooms their camera (students see the close-up). Written first.
/// THE OLD LIMIT: LiveKit's built-in pinch set the zoom to ONE pinch's spread
/// (about 2-4x on a phone) and every new pinch started again from 1x.
void main() {
  late FakeMeetRoom room;

  Future<MeetController> joined({bool teacher = true, bool camera = true}) async {
    if (teacher) {
      room.identityOnConnect = 'T1_mobile';
      room.metadataOnConnect = '{"role":"moderator","teacherId":"T1"}';
    }
    final c = MeetController(
      room: room,
      backend: MeetBackend(courseId: 'c1', call: FakeFunctions().call, delay: (_) async {}),
      token: 'jwt',
      serverUrl: 'wss://lk',
      isTeacher: teacher,
      teacherId: 'T1',
      startWithCamera: camera,
      qualityMonitor: ConnectionQualityMonitor(),
      connectGrace: Duration.zero,
    );
    await c.join();
    await pumpEventQueue();
    return c;
  }

  setUp(() => room = FakeMeetRoom());

  group('CameraZoomPolicy', () {
    test('1x to 10x', () {
      expect(CameraZoomPolicy.clamp(0.4), 1);
      expect(CameraZoomPolicy.clamp(4.2), 4.2);
      expect(CameraZoomPolicy.clamp(37), CameraZoomPolicy.max);
      expect(CameraZoomPolicy.max, 10);
    });
    test('pinches add up: each pinch continues from the current zoom', () {
      expect(CameraZoomPolicy.afterPinch(start: 3, pinchScale: 2), 6);
      expect(CameraZoomPolicy.afterPinch(start: 6, pinchScale: 3), 10);
      expect(CameraZoomPolicy.afterPinch(start: 2, pinchScale: 0.25), 1);
    });
    test('the zoom button steps 1 → 2 → 3 → 5 → 10 → back to 1', () {
      var z = 1.0;
      final seen = <double>[];
      for (var i = 0; i < 5; i++) {
        z = CameraZoomPolicy.nextPreset(z);
        seen.add(z);
      }
      expect(seen, [2, 3, 5, 10, 1]);
      expect(CameraZoomPolicy.nextPreset(2.4), 3); // after a pinch: the next step up
    });
  });

  group('teacher camera zoom', () {
    test('two pinches in a row reach 6x on the real camera (the old zoom would be back near 2x)', () async {
      final c = await joined();
      c.setCameraZoom(CameraZoomPolicy.afterPinch(start: c.cameraZoom, pinchScale: 3));
      c.setCameraZoom(CameraZoomPolicy.afterPinch(start: c.cameraZoom, pinchScale: 2));
      await pumpEventQueue();
      expect(c.cameraZoom, 6);
      expect(room.cameraZooms.last, 6);
    });

    test('never past 10x', () async {
      final c = await joined();
      c.setCameraZoom(50);
      await pumpEventQueue();
      expect(c.cameraZoom, 10);
      expect(room.cameraZooms.last, 10);
    });

    test('the button cycles the presets', () async {
      final c = await joined();
      c.nextCameraZoom();
      c.nextCameraZoom();
      await pumpEventQueue();
      expect(c.cameraZoom, 3);
      expect(room.cameraZooms, [2, 3]);
    });

    test('flipping the camera or turning it off and on starts again at 1x', () async {
      final c = await joined();
      c.setCameraZoom(4);
      await c.flipCamera();
      expect(c.cameraZoom, 1);
      c.setCameraZoom(4);
      await c.toggleCamera(); // off
      await c.toggleCamera(); // on again
      expect(c.cameraZoom, 1);
    });

    test('no camera on: nothing happens', () async {
      final c = await joined(camera: false);
      c.setCameraZoom(4);
      await pumpEventQueue();
      expect(c.cameraZoom, 1);
      expect(room.cameraZooms, isEmpty);
    });

    test('students do not get camera zoom', () async {
      final c = await joined(teacher: false);
      c.setCameraZoom(4);
      c.nextCameraZoom();
      await pumpEventQueue();
      expect(c.cameraZoom, 1);
      expect(room.cameraZooms, isEmpty);
    });

    test('a phone that cannot zoom does not break the class', () async {
      final c = await joined();
      room.zoomError = Exception('setZoom only support for mobile devices!');
      c.setCameraZoom(3);
      await pumpEventQueue();
      expect(c.phase, MeetPhase.connected);
    });
  });

  group('teacher tap-to-focus', () {
    test('focuses the real camera on the tapped spot (kept inside the picture)', () async {
      final c = await joined();
      c.focusCamera(0.25, 0.75);
      c.focusCamera(-1, 3);
      await pumpEventQueue();
      expect(room.cameraFocusPoints, [(0.25, 0.75), (0.0, 1.0)]);
    });
    test('students, or no camera: nothing happens', () async {
      final student = await joined(teacher: false);
      student.focusCamera(0.5, 0.5);
      room = FakeMeetRoom();
      final noCamera = await joined(camera: false);
      noCamera.focusCamera(0.5, 0.5);
      await pumpEventQueue();
      expect(room.cameraFocusPoints, isEmpty);
    });
    test('a phone that cannot focus does not break the class', () async {
      final c = await joined();
      room.zoomError = Exception('not supported');
      c.focusCamera(0.5, 0.5);
      await pumpEventQueue();
      expect(c.phase, MeetPhase.connected);
    });
  });

  test('MeetCameraPosition still flips (sanity)', () async {
    final c = await joined();
    await c.flipCamera();
    expect(c.cameraPosition, MeetCameraPosition.back);
  });
}
