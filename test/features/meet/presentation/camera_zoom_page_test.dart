import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/domain/meet_participant.dart';
import 'package:calligro_app/features/meet/presentation/pages/calligro_meet_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';
import '../fakes/fake_meet_platform.dart';
import '../fakes/fake_meet_room.dart';

/// Teacher camera zoom on the REAL meet page (fake room: no camera hardware).
void main() {
  late FakeMeetRoom room;
  setUp(() => room = FakeMeetRoom());

  Future<void> pumpFor(WidgetTester tester, [Duration d = const Duration(milliseconds: 600)]) async {
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, {bool teacher = true, bool camera = true}) async {
    if (teacher) {
      room
        ..identityOnConnect = 'T1_mobile'
        ..metadataOnConnect = '{"role":"moderator","teacherId":"T1"}';
    }
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: CalligroMeetPage(
        token: 'jwt',
        serverUrl: 'wss://lk',
        roomName: 'CG_room',
        courseId: 'c1',
        isTeacher: teacher,
        teacherId: 'T1',
        startWithCamera: camera,
        roomFactory: () => room,
        backend: MeetBackend(courseId: 'c1', call: FakeFunctions().call, delay: (_) async {}),
        platform: FakeMeetPlatform(),
        connectGrace: Duration.zero,
      ),
    ));
    await pumpFor(tester);
  }

  String label(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('camera-zoom-label'))).data!;

  testWidgets('teacher: the zoom button steps 1× → 2× → 3× and zooms the real camera', (tester) async {
    await open(tester);
    expect(label(tester), '1×');
    await tester.tap(find.byKey(const Key('camera-zoom')));
    await pumpFor(tester, const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('camera-zoom')));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(label(tester), '3×');
    expect(room.cameraZooms, [2, 3]);
  });

  testWidgets('teacher: two pinches add up (the old zoom restarted from 1× each time)', (tester) async {
    await open(tester);
    Future<void> pinch(double from, double to) async {
      final center = tester.getCenter(find.byKey(const Key('tap-layer')));
      final a = await tester.startGesture(center - Offset(from, 0));
      final b = await tester.startGesture(center + Offset(from, 0));
      await tester.pump();
      for (var i = 1; i <= 5; i++) {
        final d = from + (to - from) * i / 5;
        await a.moveTo(center - Offset(d, 0));
        await b.moveTo(center + Offset(d, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await pumpFor(tester, const Duration(milliseconds: 100));
    }

    // (Flutter starts measuring a pinch after a few pixels of slop, so a "3x spread" reads about 2.5x.)
    await pinch(50, 150);
    final first = room.cameraZooms.last;
    expect(first, greaterThan(2));
    await pinch(50, 100);
    final second = room.cameraZooms.last;
    // The second pinch CONTINUES from the first: well past what one pinch reached.
    expect(second, greaterThan(first * 1.4));
    expect(label(tester), '${second.toStringAsFixed(1)}×');
  });

  testWidgets('no zoom button for students, or with the camera off', (tester) async {
    await open(tester, teacher: false);
    expect(find.byKey(const Key('camera-zoom')), findsNothing);
  });

  testWidgets('teacher with the camera off: no zoom button', (tester) async {
    await open(tester, camera: false);
    expect(find.byKey(const Key('camera-zoom')), findsNothing);
  });

  group('teacher focus: LONG press focuses, a tap shows / hides the controls', () {
    bool controlsVisible(WidgetTester tester) =>
        tester.widget<IgnorePointer>(find.ancestor(of: find.byKey(const Key('toggle-mic')), matching: find.byType(IgnorePointer)).first).ignoring == false;

    testWidgets('a tap on their own camera picture shows / hides the controls and does NOT focus', (tester) async {
      await open(tester); // alone: their own camera is full screen
      final before = controlsVisible(tester);
      await tester.tapAt(tester.getCenter(find.byKey(const Key('stage-focus'))));
      await tester.pump();
      expect(room.cameraFocusPoints, isEmpty);
      expect(find.byKey(const Key('camera-focus-ring')), findsNothing);
      expect(controlsVisible(tester), !before);
      await tester.tapAt(tester.getCenter(find.byKey(const Key('stage-focus'))));
      await tester.pump();
      expect(controlsVisible(tester), before, reason: 'a second tap brings them back');
    });

    testWidgets('a long press on their own camera picture focuses there, shows the focus box, and keeps the controls', (tester) async {
      await open(tester); // alone: their own camera is full screen
      final before = controlsVisible(tester);
      final area = tester.getRect(find.byKey(const Key('stage-focus')));
      await tester.longPressAt(area.topLeft + Offset(area.width * 0.25, area.height * 0.5));
      await tester.pump();
      expect(room.cameraFocusPoints, hasLength(1));
      expect(room.cameraFocusPoints.single.$1, closeTo(0.25, 0.02));
      expect(room.cameraFocusPoints.single.$2, closeTo(0.5, 0.02));
      expect(find.byKey(const Key('camera-focus-ring')), findsOneWidget);
      expect(controlsVisible(tester), before);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.byKey(const Key('camera-focus-ring')), findsNothing);
    });

    testWidgets('tapping a student\'s video still shows / hides the controls (no focus)', (tester) async {
      await open(tester);
      room.addRemote(const MeetParticipant(
          identity: 's2', name: 'Student Two', metadata: '{"role":"participant","teacherId":"T1"}', isCameraEnabled: true,
          video: MeetVideo('remote-camera')));
      await pumpFor(tester);
      final focusTile = find.byKey(const Key('stage-focus'));
      final pip = find.byKey(const Key('stage-pip'));
      // Whichever tile shows the student: tap it.
      final studentTile = find.descendant(of: focusTile, matching: find.text('Student Two')).evaluate().isNotEmpty ? focusTile : pip;
      final before = controlsVisible(tester);
      await tester.tapAt(tester.getCenter(studentTile));
      await tester.pump();
      expect(room.cameraFocusPoints, isEmpty);
      expect(controlsVisible(tester), !before);
    });

    testWidgets('students: a tap or a long press never focuses anything', (tester) async {
      await open(tester, teacher: false);
      await tester.longPressAt(tester.getCenter(find.byKey(const Key('stage-focus'))));
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byKey(const Key('stage-focus'))));
      await tester.pump();
      expect(room.cameraFocusPoints, isEmpty);
    });
  });
}
