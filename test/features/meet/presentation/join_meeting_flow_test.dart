import 'dart:async';

import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/presentation/livekit_meet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the REAL join flow (LiveKitMeetService.joinMeeting):
/// loading dialog → token request → pre-join screen, or an error message.
/// The loading spinner animates forever, so pumpAndSettle would never settle:
/// pump enough frames for futures to resolve and route transitions to finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  late List<Map<String, dynamic>> calls;
  late Completer<Object?> server;

  // The Completer must be created INSIDE the widget test's fake-async zone
  // (i.e. when the call happens), otherwise its result never reaches the test.
  Future<Object?> fakeCall(String name, Map<String, dynamic> data) {
    calls.add({'name': name, ...data});
    server = Completer<Object?>();
    return server.future;
  }

  Widget preJoin(MeetToken t, String courseId, bool isTeacher) => Scaffold(
        body: Text('PREJOIN token=${t.token} url=${t.serverUrl} room=${t.roomName} '
            'teacher=${t.teacherId} course=$courseId isTeacher=$isTeacher'),
      );

  Future<void> pumpJoinButton(WidgetTester tester, LiveKitMeetService service, {bool isTeacher = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => service.joinMeeting(context: context, courseId: 'c1', isTeacher: isTeacher),
            child: const Text('JOIN'),
          ),
        ),
      ),
    ));
  }

  setUp(() {
    calls = [];
    server = Completer<Object?>();
  });

  testWidgets('success: shows a loading dialog, requests a mobile token, then opens pre-join with it',
      (tester) async {
    final service = LiveKitMeetService.forTest(call: fakeCall, preJoinBuilder: preJoin);
    await pumpJoinButton(tester, service, isTeacher: true);

    await tester.tap(find.text('JOIN'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'loading dialog while waiting');
    expect(calls, [
      {'name': 'livekit-generateLiveKitToken', 'courseId': 'c1', 'source': 'mobile'}
    ]);

    server.complete({'token': 'jwt', 'serverUrl': 'wss://lk', 'roomName': 'CG_1', 'teacherId': 'T1'});
    await settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'loading dialog closed');
    expect(find.text('PREJOIN token=jwt url=wss://lk room=CG_1 teacher=T1 course=c1 isTeacher=true'), findsOneWidget);
  });

  testWidgets('server refuses (e.g. kicked / not enrolled): closes the dialog and shows an error', (tester) async {
    final service = LiveKitMeetService.forTest(call: fakeCall, preJoinBuilder: preJoin);
    await pumpJoinButton(tester, service);

    await tester.tap(find.text('JOIN'));
    await tester.pump();
    server.completeError(Exception('permission-denied: removed by the instructor'));
    await settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Failed to join secure classroom'), findsOneWidget);
    expect(find.textContaining('PREJOIN'), findsNothing);
    expect(find.text('JOIN'), findsOneWidget, reason: 'still on the original screen');
  });

  testWidgets('malformed token response is treated as an error, not a crash', (tester) async {
    final service = LiveKitMeetService.forTest(call: fakeCall, preJoinBuilder: preJoin);
    await pumpJoinButton(tester, service);

    await tester.tap(find.text('JOIN'));
    await tester.pump();
    server.complete({'token': 'jwt'}); // no serverUrl / roomName
    await settle(tester);

    expect(find.textContaining('Failed to join secure classroom'), findsOneWidget);
    expect(find.textContaining('PREJOIN'), findsNothing);
  });

  testWidgets('double-tap while a join is in progress sends only ONE token request', (tester) async {
    final service = LiveKitMeetService.forTest(call: fakeCall, preJoinBuilder: preJoin);
    await pumpJoinButton(tester, service);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(calls, hasLength(1));

    server.complete({'token': 'jwt', 'serverUrl': 'wss://lk', 'roomName': 'CG_1'});
    await settle(tester);
    expect(find.textContaining('PREJOIN'), findsOneWidget);
  });

  testWidgets('after a finished attempt, joining again is allowed', (tester) async {
    final service = LiveKitMeetService.forTest(call: fakeCall, preJoinBuilder: preJoin);
    await pumpJoinButton(tester, service);

    await tester.tap(find.text('JOIN'));
    await tester.pump();
    server.completeError(Exception('network'));
    await settle(tester);

    await tester.tap(find.text('JOIN'));
    await tester.pump();
    expect(calls, hasLength(2));
    server.complete({'token': 'jwt', 'serverUrl': 'wss://lk', 'roomName': 'CG_1'});
    await settle(tester);
    expect(find.textContaining('PREJOIN'), findsOneWidget);
  });
}
