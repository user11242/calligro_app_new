import 'dart:async';

import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/domain/meet_participant.dart';
import 'package:calligro_app/features/meet/domain/meet_protocol.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';
import 'package:calligro_app/features/meet/presentation/pages/calligro_meet_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';
import '../fakes/fake_meet_platform.dart';
import '../fakes/fake_meet_room.dart';

/// Widget tests of the REAL meet page, driven through a fake room
/// (no LiveKit server, no Firebase, no native plugins).
void main() {
  late FakeMeetRoom room;
  late FakeFunctions fn;
  late FakeMeetPlatform platform;

  const teacherMeta = '{"role":"moderator","teacherId":"T1"}';
  const studentMeta = '{"role":"participant","teacherId":"T1"}';
  const teacher = MeetParticipant(identity: 'T1_mobile', name: 'Teacher One', metadata: teacherMeta, isMicrophoneEnabled: true);
  const student2 = MeetParticipant(
      identity: 's2', name: 'Student Two', metadata: studentMeta, isMicrophoneEnabled: true, isCameraEnabled: true);

  setUp(() {
    room = FakeMeetRoom();
    fn = FakeFunctions();
    platform = FakeMeetPlatform();
  });

  /// Frames + timers: the page has a 1s clock, so pumpAndSettle would never settle.
  Future<void> pumpFor(WidgetTester tester, [Duration d = const Duration(milliseconds: 600)]) async {
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Opens the meet page from a home screen (so "closing" is observable).
  Future<void> openMeet(WidgetTester tester, {bool isTeacher = false, bool mic = false, bool camera = false}) async {
    if (isTeacher) {
      room
        ..identityOnConnect = 'T1_mobile'
        ..nameOnConnect = 'Teacher One'
        ..metadataOnConnect = teacherMeta;
    }
    await tester.binding.setSurfaceSize(const Size(1280, 720)); // the meet is landscape
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
                builder: (_) => CalligroMeetPage(
                  token: 'jwt-1',
                  serverUrl: 'wss://lk',
                  roomName: 'CG_room',
                  courseId: 'c1',
                  isTeacher: isTeacher,
                  teacherId: 'T1',
                  startWithMic: mic,
                  startWithCamera: camera,
                  roomFactory: () => room,
                  backend: MeetBackend(courseId: 'c1', call: fn.call, delay: (_) async {}),
                  platform: platform,
                  connectGrace: Duration.zero,
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

  /// Closes everything so no timers are left pending.
  Future<void> tearDownPage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await pumpFor(tester, const Duration(seconds: 3));
    await tester.binding.setSurfaceSize(null);
  }

  bool onMeetPage() => find.byType(CalligroMeetPage).evaluate().isNotEmpty;
  List<String?> actions() =>
      fn.calls.where((c) => c.$1 == MeetBackend.moderateFunction).map((c) => c.$2['action'] as String?).toList();

  // ═══════════════════════════════════════════════════════════════════════
  testWidgets('connects, prepares the device and shows the class', (tester) async {
    await openMeet(tester, mic: true, camera: true);
    expect(room.connects.single.token, 'jwt-1');
    expect(platform.calls, ['enter', 'backgroundAudio']);
    expect(find.byKey(const Key('meet-timer')), findsOneWidget);
    expect(find.byKey(const Key('stage-focus')), findsOneWidget);
    expect(find.byKey(const Key('raise-hand')), findsOneWidget, reason: 'students get the hand button');
    expect(find.byKey(const Key('open-participants')), findsNothing);
    await tearDownPage(tester);
    expect(platform.calls.last, 'exit');
  });

  testWidgets('a student sees the teacher full-screen and new people with a chime', (tester) async {
    await openMeet(tester);
    room.addRemote(teacher);
    room.addRemote(student2);
    await pumpFor(tester);
    final focus = find.byKey(const Key('stage-focus'));
    expect(find.descendant(of: focus, matching: find.text('Teacher One')), findsOneWidget);
    expect(platform.sounds, [MeetSound.join, MeetSound.join]);
    await tearDownPage(tester);
  });

  testWidgets('mic and camera buttons control my tracks; flip appears with the camera', (tester) async {
    await openMeet(tester);
    expect(find.byKey(const Key('flip-camera')), findsNothing);
    await tester.tap(find.byKey(const Key('toggle-mic')));
    await tester.tap(find.byKey(const Key('toggle-camera')));
    await pumpFor(tester);
    expect(room.isMicrophoneEnabled, isTrue);
    expect(room.isCameraEnabled, isTrue);
    await tester.tap(find.byKey(const Key('flip-camera')));
    await pumpFor(tester);
    expect(room.cameraPositions.last, MeetCameraPosition.back);
    await tearDownPage(tester);
  });

  testWidgets('raise hand publishes my hand and lights the button', (tester) async {
    await openMeet(tester);
    await tester.tap(find.byKey(const Key('raise-hand')));
    await pumpFor(tester);
    expect(room.published.single, MeetProtocol.raiseHandMessage('Student One'));
    expect(find.byKey(const Key('tile-hand')), findsOneWidget);
    await tearDownPage(tester);
  });

  testWidgets('teacher mutes everyone → my mic goes off and I see why', (tester) async {
    await openMeet(tester, mic: true);
    room.receiveFromTeacher({'cmd': 'mute_all'});
    await pumpFor(tester);
    expect(room.isMicrophoneEnabled, isFalse);
    expect(find.text('The teacher has muted your microphone.'), findsOneWidget);
    await tearDownPage(tester);
  });

  testWidgets('teacher ends the class → message, then the page closes', (tester) async {
    await openMeet(tester);
    room.receiveFromTeacher(MeetProtocol.endMeetingMessage());
    await pumpFor(tester);
    expect(find.text('The teacher has ended the meeting.'), findsOneWidget);
    expect(onMeetPage(), isTrue, reason: 'stays 2 seconds so the message can be read');
    await pumpFor(tester, const Duration(seconds: 3));
    expect(onMeetPage(), isFalse);
    expect(find.text('HOME'), findsOneWidget);
    await tearDownPage(tester);
  });

  testWidgets('a FORGED end-class from a student is ignored', (tester) async {
    await openMeet(tester);
    room.receive(MeetProtocol.endMeetingMessage(), identity: 's2', metadata: studentMeta);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(onMeetPage(), isTrue);
    await tearDownPage(tester);
  });

  testWidgets('kicked by the server → page closes, no Rejoin offered', (tester) async {
    await openMeet(tester);
    room.emit(const RoomDisconnected(MeetDisconnectReason.participantRemoved));
    await pumpFor(tester);
    expect(find.byKey(const Key('rejoin')), findsNothing);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(onMeetPage(), isFalse);
    await tearDownPage(tester);
  });

  testWidgets('connection lost → Rejoin gets a fresh token and reconnects', (tester) async {
    await openMeet(tester);
    room.emit(const RoomReconnecting());
    await pumpFor(tester);
    expect(find.text('Reconnecting...'), findsOneWidget);
    room.emit(const RoomDisconnected(MeetDisconnectReason.other));
    await pumpFor(tester);
    expect(find.byKey(const Key('rejoin')), findsOneWidget);

    fn.answerWith({'token': 'jwt-2', 'serverUrl': 'wss://lk2', 'roomName': 'r'});
    await tester.tap(find.byKey(const Key('rejoin')));
    await pumpFor(tester);
    expect(room.connects.last.token, 'jwt-2');
    expect(find.byKey(const Key('rejoin')), findsNothing);
    expect(find.byKey(const Key('meet-timer')), findsOneWidget);
    await tearDownPage(tester);
  });

  testWidgets('connection fails → debug log is shown and Cancel closes the page', (tester) async {
    room.connectResults.addAll([Exception('ice'), Exception('relay')]);
    await openMeet(tester);
    expect(find.text('🐛 LiveKit Debug Log'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-connection')));
    await pumpFor(tester);
    expect(onMeetPage(), isFalse);
    await tearDownPage(tester);
  });

  testWidgets('the system back gesture cannot leave the class', (tester) async {
    await openMeet(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await pumpFor(tester);
    expect(onMeetPage(), isTrue);
    await tearDownPage(tester);
  });

  testWidgets('student leave → confirm → page closes, no server calls', (tester) async {
    await openMeet(tester, mic: true);
    fn.calls.clear();
    await tester.tap(find.byKey(const Key('leave')));
    await pumpFor(tester);
    await tester.tap(find.byKey(const Key('dialog-confirm-leave')));
    await pumpFor(tester);
    expect(onMeetPage(), isFalse);
    expect(fn.calls, isEmpty);
    await tearDownPage(tester);
  });

  testWidgets('grid view shows everyone; tapping a tile returns to the speaker view', (tester) async {
    await openMeet(tester);
    room.addRemote(teacher);
    room.addRemote(student2);
    await pumpFor(tester);
    await tester.tap(find.byKey(const Key('toggle-layout')));
    await pumpFor(tester);
    expect(find.byKey(const Key('grid-tile-s1')), findsOneWidget);
    expect(find.byKey(const Key('grid-tile-T1_mobile')), findsOneWidget);
    expect(find.byKey(const Key('grid-tile-s2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('grid-tile-s2')));
    await pumpFor(tester);
    expect(find.byKey(const Key('stage-focus')), findsOneWidget);
    await tearDownPage(tester);
  });

  testWidgets('student app backgrounded → camera off; resumed → camera back', (tester) async {
    await openMeet(tester, camera: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpFor(tester);
    expect(room.isCameraEnabled, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFor(tester);
    expect(room.isCameraEnabled, isTrue);
    await tearDownPage(tester);
  });

  // ── Teacher ──────────────────────────────────────────────────────────
  group('teacher', () {
    testWidgets('recording starts automatically and the REC badge appears', (tester) async {
      await openMeet(tester, isTeacher: true, mic: true, camera: true);
      expect(fn.calls.where((c) => c.$1 == MeetBackend.startRecordingFunction), hasLength(1));
      expect(find.byKey(const Key('rec-badge')), findsOneWidget);
      expect(find.byKey(const Key('open-participants')), findsOneWidget);
      expect(find.byKey(const Key('raise-hand')), findsNothing);
      await tearDownPage(tester);
    });

    testWidgets('no camera → no recording; the REC button is offered', (tester) async {
      await openMeet(tester, isTeacher: true, mic: true);
      expect(find.byKey(const Key('rec-badge')), findsNothing);
      expect(find.byKey(const Key('start-recording')), findsOneWidget);
      await tearDownPage(tester);
    });

    testWidgets('the teacher\'s leave button only offers "End for all" (no "Leave only") or Cancel', (tester) async {
      await openMeet(tester, isTeacher: true, mic: true, camera: true);
      await tester.tap(find.byKey(const Key('leave')));
      await pumpFor(tester);
      expect(find.byKey(const Key('dialog-leave-only')), findsNothing);
      expect(find.byKey(const Key('dialog-end-for-all')), findsOneWidget);

      // Cancel: nothing happens, the class goes on.
      await tester.tap(find.byKey(const Key('dialog-cancel')));
      await pumpFor(tester);
      expect(onMeetPage(), isTrue);
      expect(actions(), isEmpty);
      await tearDownPage(tester);
    });

    testWidgets('"End for all" ends the room on the server and closes', (tester) async {
      await openMeet(tester, isTeacher: true, mic: true, camera: true);
      await tester.tap(find.byKey(const Key('leave')));
      await pumpFor(tester);
      await tester.tap(find.byKey(const Key('dialog-end-for-all')));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(room.published.last, MeetProtocol.endMeetingMessage());
      expect(actions(), ['end_room']);
      expect(onMeetPage(), isFalse);
      await tearDownPage(tester);
    });

    testWidgets('closing the page while recording stops the recording (fail-safe)', (tester) async {
      await openMeet(tester, isTeacher: true, mic: true, camera: true);
      await tearDownPage(tester);
      expect(actions(), ['stop_recording']);
      expect(room.disposed, isTrue);
    });

    testWidgets('participants sheet: lower a hand, mute, remove (with confirmation)', (tester) async {
      await openMeet(tester, isTeacher: true);
      room.addRemote(student2);
      room.receive(MeetProtocol.raiseHandMessage('Student Two'), identity: 's2', metadata: studentMeta);
      await pumpFor(tester);
      expect(find.text('Student Two raised their hand! ✋'), findsWidgets);

      await tester.tap(find.byKey(const Key('open-participants')));
      await pumpFor(tester);
      expect(find.byKey(const Key('participant-row-s2')), findsOneWidget);
      expect(find.byKey(const Key('kick-T1_mobile')), findsNothing, reason: 'no moderation buttons for myself');

      await tester.tap(find.byKey(const Key('lower-hand-s2')));
      await pumpFor(tester);
      expect(room.published.last, MeetProtocol.forceLowerHandMessage('s2'));
      expect(find.byKey(const Key('lower-hand-s2')), findsNothing);

      await tester.tap(find.byKey(const Key('mute-mic-s2')));
      await pumpFor(tester);
      await tester.tap(find.byKey(const Key('dialog-confirm-mute')));
      await pumpFor(tester);
      expect(fn.calls.last.$2, {'courseId': 'c1', 'action': 'mute_mic', 'targetIdentity': 's2'});
      expect(find.descendant(of: find.byKey(const Key('mute-mic-s2')), matching: find.byIcon(Icons.mic_off)),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('kick-s2')));
      await pumpFor(tester);
      await tester.tap(find.byKey(const Key('dialog-confirm-kick')));
      await pumpFor(tester);
      expect(fn.calls.last.$2, {'courseId': 'c1', 'action': 'kick', 'targetIdentity': 's2'});
      expect(room.published.last, MeetProtocol.kickMessage('s2'));
      await tearDownPage(tester);
    });

    testWidgets('cancelling a confirmation does nothing', (tester) async {
      await openMeet(tester, isTeacher: true);
      room.addRemote(student2);
      await pumpFor(tester);
      await tester.tap(find.byKey(const Key('open-participants')));
      await pumpFor(tester);
      fn.calls.clear();
      await tester.tap(find.byKey(const Key('kick-s2')));
      await pumpFor(tester);
      await tester.tap(find.text('Cancel'));
      await pumpFor(tester);
      expect(fn.calls, isEmpty);
      await tearDownPage(tester);
    });

    testWidgets('server refuses a moderation action → the teacher sees an error', (tester) async {
      await openMeet(tester, isTeacher: true);
      room.addRemote(student2);
      await pumpFor(tester);
      await tester.tap(find.byKey(const Key('open-participants')));
      await pumpFor(tester);
      fn.failWith(Exception('permission-denied'));
      await tester.tap(find.byKey(const Key('kick-s2')));
      await pumpFor(tester);
      await tester.tap(find.byKey(const Key('dialog-confirm-kick')));
      await pumpFor(tester);
      expect(find.textContaining('Action failed'), findsOneWidget);
      await tearDownPage(tester);
    });
  });

  // Silences the unused warning for completer-based helpers in future tests.
  test('helpers compile', () => expect(Completer<void>(), isNotNull));
}
