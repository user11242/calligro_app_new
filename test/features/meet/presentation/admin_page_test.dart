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

/// A platform admin on the REAL meet page: the moderation controls the teacher has.
void main() {
  Future<void> pumpFor(WidgetTester tester, [Duration d = const Duration(milliseconds: 600)]) async {
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('an admin opens the participants list and can mute, turn off the camera of and remove a student',
      (tester) async {
    final room = FakeMeetRoom()
      ..identityOnConnect = 'admin1'
      ..nameOnConnect = 'Platform Admin'
      ..metadataOnConnect = '{"role":"moderator","teacherId":"T1"}';
    final fn = FakeFunctions();
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
        teacherId: 'T1',
        roomFactory: () => room,
        backend: MeetBackend(courseId: 'c1', call: fn.call, delay: (_) async {}),
        platform: FakeMeetPlatform(),
        connectGrace: Duration.zero,
      ),
    ));
    await pumpFor(tester);
    room.addRemote(const MeetParticipant(
        identity: 's2', name: 'Student Two', metadata: '{"role":"participant","teacherId":"T1"}',
        isMicrophoneEnabled: true, isCameraEnabled: true));
    await pumpFor(tester);

    expect(find.byKey(const Key('raise-hand')), findsNothing);
    await tester.tap(find.byKey(const Key('open-participants')));
    await pumpFor(tester);
    expect(find.byKey(const Key('mute-mic-s2')), findsOneWidget);
    expect(find.byKey(const Key('mute-camera-s2')), findsOneWidget);
    expect(find.byKey(const Key('kick-s2')), findsOneWidget);
    // Not the course teacher: no recording, no "show work".
    expect(find.byKey(const Key('start-recording')), findsNothing);
    expect(find.byKey(const Key('show-work')), findsNothing);
  });
}
