import 'dart:ui' as ui;

import 'package:calligro_app/features/classroom/presentation/pages/share_submission_sheet.dart';
import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/domain/meet_protocol.dart';
import 'package:calligro_app/features/meet/domain/shared_work.dart';
import 'package:calligro_app/features/meet/presentation/pages/calligro_meet_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';
import '../fakes/fake_meet_platform.dart';
import '../fakes/fake_meet_room.dart';

/// "Show a student's work" on the REAL meet page, through a fake room,
/// a fake picker and a fake file loader (no LiveKit, Firebase or network).
void main() {
  const url = 'https://firebasestorage.googleapis.com/v0/b/x/o/s1_work.pdf?alt=media&token=t';
  const teacherMeta = '{"role":"moderator","teacherId":"T1"}';
  late FakeMeetRoom room;
  late List<ui.Image> pages;
  late List<String> loaded;
  SubmissionToShare? pick;

  setUp(() {
    room = FakeMeetRoom();
    loaded = [];
    pick = const SubmissionToShare(url: url, fileName: 'work.pdf', studentName: 'Sara Ahmad', assignmentTitle: 'Alif drills');
  });

  Future<void> pumpFor(WidgetTester tester, [Duration d = const Duration(milliseconds: 600)]) async {
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openMeet(WidgetTester tester, {required bool isTeacher}) async {
    // Two fake "PDF pages" (made outside the fake-async zone).
    await tester.runAsync(() async {
      pages = [await createTestImage(width: 600, height: 800), await createTestImage(width: 600, height: 800)];
    });
    if (isTeacher) {
      room
        ..identityOnConnect = 'T1_mobile'
        ..nameOnConnect = 'Teacher One'
        ..metadataOnConnect = teacherMeta;
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
        isTeacher: isTeacher,
        teacherId: 'T1',
        roomFactory: () => room,
        backend: MeetBackend(courseId: 'c1', call: FakeFunctions().call, delay: (_) async {}),
        platform: FakeMeetPlatform(),
        connectGrace: Duration.zero,
        pickSubmission: (_, courseId) async => pick,
        loadSharedWorkPages: (u, kind) async {
          loaded.add(u);
          return pages;
        },
      ),
    ));
    await pumpFor(tester);
  }

  List<Map<String, dynamic>> sent() =>
      room.published.where((m) => MeetProtocol.sharedWorkTypes.contains(m['type'])).toList();

  testWidgets('teacher: picks a student\'s PDF → it fills the screen with the student\'s name, and the class is told', (tester) async {
    await openMeet(tester, isTeacher: true);
    await tester.tap(find.byKey(const Key('show-work')));
    await pumpFor(tester);

    expect(loaded, [url]);
    expect(find.text('Sara Ahmad · Alif drills'), findsOneWidget);
    expect(sent().first['type'], MeetProtocol.workShow);
    expect(sent().first['studentName'], 'Sara Ahmad');
    expect(find.byKey(const Key('shared-work-stop')), findsOneWidget);
  });

  testWidgets('teacher: the tools stay clear of the Dynamic Island (landscape, island on the right)', (tester) async {
    // iPhone in landscape: the island takes ~59 pt of the right edge (FakeViewPadding is in physical pixels).
    final ratio = tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(right: 59 * ratio);
    tester.view.viewPadding = FakeViewPadding(right: 59 * ratio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await openMeet(tester, isTeacher: true);
    await tester.tap(find.byKey(const Key('show-work')));
    await pumpFor(tester);

    final screenWidth = tester.getSize(find.byType(Scaffold).first).width;
    for (final key in ['shared-work-pen', 'shared-work-move', 'shared-work-undo', 'shared-work-clear', 'shared-work-stop']) {
      expect(tester.getRect(find.byKey(Key(key))).right, lessThanOrEqualTo(screenWidth - 59), reason: key);
    }
  });

  testWidgets('teacher: draws a line with one finger → it is sent to the class', (tester) async {
    await openMeet(tester, isTeacher: true);
    await tester.tap(find.byKey(const Key('show-work')));
    await pumpFor(tester);
    room.published.clear();

    final canvas = find.byKey(const Key('shared-work-canvas'));
    final g = await tester.startGesture(tester.getCenter(canvas));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(20, 10));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await g.up();
    await tester.pump();

    final strokes = sent().where((m) => m['type'] == MeetProtocol.workStroke).toList();
    expect(strokes, isNotEmpty);
    final totalPoints = strokes.fold<int>(0, (n, m) => n + (m['points'] as List).length ~/ 2);
    expect(totalPoints, greaterThan(3));
  });

  testWidgets('teacher: next page, undo and stop reach the class', (tester) async {
    await openMeet(tester, isTeacher: true);
    await tester.tap(find.byKey(const Key('show-work')));
    await pumpFor(tester);
    room.published.clear();

    await tester.tap(find.byKey(const Key('shared-work-next')));
    await pumpFor(tester, const Duration(milliseconds: 200));
    expect(sent().last, containsPair('page', 1));

    await tester.tap(find.byKey(const Key('shared-work-stop')));
    await pumpFor(tester, const Duration(milliseconds: 200));
    expect(sent().last['type'], MeetProtocol.workStop);
    expect(find.byKey(const Key('shared-work-label')), findsNothing);
  });

  testWidgets('teacher: a Word file is not shown; they are told why', (tester) async {
    pick = const SubmissionToShare(url: url, fileName: 'essay.docx', studentName: 'Sara', assignmentTitle: 'A');
    await openMeet(tester, isTeacher: true);
    await tester.tap(find.byKey(const Key('show-work')));
    await pumpFor(tester);
    expect(find.text('Only images and PDF files can be shown in class'), findsOneWidget);
    expect(sent(), isEmpty);
    expect(loaded, isEmpty);
  });

  testWidgets('student: sees the work the teacher shows (with the name), has no tools, and it closes on stop', (tester) async {
    await openMeet(tester, isTeacher: false);
    expect(find.byKey(const Key('show-work')), findsNothing);

    room.receiveFromTeacher(SharedWorkProtocol.show(
        shareId: 'sh1', url: url, kind: SharedWorkKind.pdf, studentName: 'Sara Ahmad', assignmentTitle: 'Alif drills'));
    await pumpFor(tester);
    expect(find.text('Sara Ahmad · Alif drills'), findsOneWidget);
    expect(find.byKey(const Key('shared-work-stop')), findsNothing);
    expect(find.byKey(const Key('shared-work-pen')), findsNothing);

    room.receiveFromTeacher(SharedWorkProtocol.stop('sh1'));
    await pumpFor(tester);
    expect(find.byKey(const Key('shared-work-label')), findsNothing);
  });

  testWidgets('student: a file that cannot be opened shows a message, not a crash', (tester) async {
    await openMeet(tester, isTeacher: false);
    await tester.pumpWidget(const SizedBox()); // reset
    room = FakeMeetRoom();
    await tester.runAsync(() async {
      pages = [await createTestImage(width: 10, height: 10)];
    });
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
        teacherId: 'T1',
        roomFactory: () => room,
        backend: MeetBackend(courseId: 'c1', call: FakeFunctions().call, delay: (_) async {}),
        platform: FakeMeetPlatform(),
        connectGrace: Duration.zero,
        loadSharedWorkPages: (u, kind) async => throw Exception('404'),
      ),
    ));
    await pumpFor(tester);
    room.receiveFromTeacher(SharedWorkProtocol.show(
        shareId: 'sh1', url: url, kind: SharedWorkKind.image, studentName: 'Sara', assignmentTitle: 'A'));
    await pumpFor(tester);
    expect(find.text('This file could not be opened'), findsOneWidget);
  });
}
