import 'dart:async';

import 'package:calligro_app/features/meet/application/pre_join_controller.dart';
import 'package:calligro_app/features/meet/domain/meet_media.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';
import 'package:calligro_app/features/meet/presentation/pages/calligro_pre_join_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_media_devices.dart';

/// Widget tests of the REAL pre-join page with fake camera/permissions/profile.
void main() {
  late FakeMediaDevices devices;
  late FakeProfileSource profile;
  late List<PreJoinSettings> joined;

  setUp(() {
    devices = FakeMediaDevices();
    // No avatar URL: widget tests can't load network images.
    profile = FakeProfileSource()..profile = const MeetUserProfile(name: 'Student One');
    joined = [];
  });

  Future<void> pumpFor(WidgetTester tester, [Duration d = const Duration(milliseconds: 600)]) async {
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, {bool isTeacher = false}) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CalligroPreJoinPage(
                  token: 'jwt',
                  serverUrl: 'wss://lk',
                  roomName: 'r',
                  courseId: 'c1',
                  isTeacher: isTeacher,
                  teacherId: 'T1',
                  devices: devices,
                  profile: profile,
                  meetPageBuilder: (settings) {
                    joined.add(settings);
                    return const Scaffold(body: Text('MEET PAGE'));
                  },
                ),
              )),
              child: const Text('HOME'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('HOME'));
    await pumpFor(tester);
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  }

  Finder previewVideo() =>
      find.descendant(of: find.byKey(const Key('prejoin-preview')), matching: find.byKey(const Key('meet-video')));

  testWidgets('student: name shown, camera and mic off, no preview', (tester) async {
    await open(tester);
    expect(find.text('Student One'), findsOneWidget);
    expect(find.text('Mic Off'), findsOneWidget);
    expect(find.text('Camera Off'), findsOneWidget);
    expect(previewVideo(), findsNothing);
    expect(find.byKey(const Key('prejoin-flip')), findsNothing);
    await done(tester);
  });

  testWidgets('teacher: mic on, live preview, recording note', (tester) async {
    await open(tester, isTeacher: true);
    expect(find.text('Mic On'), findsOneWidget);
    expect(find.text('Camera On'), findsOneWidget);
    expect(previewVideo(), findsOneWidget);
    expect(find.byKey(const Key('prejoin-flip')), findsOneWidget);
    await done(tester);
    expect(devices.running, isEmpty, reason: 'leaving the screen stops the camera');
  });

  testWidgets('turning the camera on shows the preview; flip switches camera', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('prejoin-camera')));
    await pumpFor(tester);
    expect(previewVideo(), findsOneWidget);
    await tester.tap(find.byKey(const Key('prejoin-flip')));
    await pumpFor(tester);
    expect(devices.running.single.position, MeetCameraPosition.back);
    await done(tester);
  });

  testWidgets('permission denied → stays off and says why', (tester) async {
    devices.cameraGranted = false;
    await open(tester);
    await tester.tap(find.byKey(const Key('prejoin-camera')));
    await pumpFor(tester);
    expect(find.text('Camera Off'), findsOneWidget);
    expect(find.byKey(const Key('prejoin-error')), findsOneWidget);
    await done(tester);
  });

  testWidgets('Join: frees the camera and opens the class with the chosen settings', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('prejoin-mic')));
    await tester.tap(find.byKey(const Key('prejoin-camera')));
    await pumpFor(tester);
    await tester.tap(find.byKey(const Key('prejoin-flip')));
    await pumpFor(tester);
    await tester.tap(find.byKey(const Key('prejoin-join')));
    await pumpFor(tester);
    expect(find.text('MEET PAGE'), findsOneWidget);
    expect(joined.single.startWithMic, isTrue);
    expect(joined.single.startWithCamera, isTrue);
    expect(joined.single.cameraPosition, MeetCameraPosition.back);
    expect(devices.running, isEmpty);
    await done(tester);
  });

  testWidgets('Join is disabled while the camera is still opening', (tester) async {
    await open(tester);
    devices.cameraGate = Completer<void>();
    await tester.tap(find.byKey(const Key('prejoin-camera')));
    await pumpFor(tester);
    final join = tester.widget<ElevatedButton>(find.byKey(const Key('prejoin-join')));
    expect(join.onPressed, isNull);
    devices.cameraGate!.complete();
    await pumpFor(tester);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('prejoin-join'))).onPressed, isNotNull);
    await done(tester);
  });

  testWidgets('back button closes and stops the camera', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('prejoin-camera')));
    await pumpFor(tester);
    await tester.tap(find.byKey(const Key('prejoin-back')));
    await pumpFor(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(devices.running, isEmpty);
    await done(tester);
  });

  testWidgets('profile unavailable → fallback name, not "Loading..." forever', (tester) async {
    profile.error = Exception('offline');
    await open(tester);
    expect(find.text(PreJoinController.fallbackName), findsOneWidget);
    expect(find.text('Loading...'), findsNothing);
    await done(tester);
  });
}
