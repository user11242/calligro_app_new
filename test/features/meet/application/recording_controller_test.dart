import 'dart:async';

import 'package:calligro_app/features/meet/application/recording_controller.dart';
import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';

void main() {
  late FakeFunctions fn;
  late RecordingController rec;

  int starts() => fn.calls.where((c) => c.$1 == MeetBackend.startRecordingFunction).length;

  setUp(() {
    fn = FakeFunctions();
    rec = RecordingController(MeetBackend(courseId: 'c1', call: fn.call, delay: (_) async {}), isTeacher: true);
  });

  test('two triggers at the same moment start exactly ONE recording', () async {
    final gate = Completer<Object?>();
    fn.answer((_, _) => gate.future);
    final a = rec.start(audioTrackSid: 'a', videoTrackSid: 'v');
    final b = rec.start(audioTrackSid: 'a', videoTrackSid: 'v'); // camera + mic published together
    expect(rec.isRecording, isTrue, reason: 'locked synchronously, before any await');
    gate.complete({'status': 'started'});
    expect(await a, RecordingStartResult.started);
    expect(await b, RecordingStartResult.skipped);
    expect(starts(), 1);
  });

  test('students never start, and missing tracks wait silently', () async {
    final student =
        RecordingController(MeetBackend(courseId: 'c1', call: fn.call, delay: (_) async {}), isTeacher: false);
    expect(await student.start(audioTrackSid: 'a', videoTrackSid: 'v'), RecordingStartResult.skipped);
    expect(await rec.start(audioTrackSid: 'a', videoTrackSid: null), RecordingStartResult.skipped);
    expect(rec.isRecording, isFalse);
    expect(starts(), 0);
  });

  test('failure releases the lock so a later trigger can retry', () async {
    fn.failWith(Exception('egress down'));
    expect(await rec.start(audioTrackSid: 'a', videoTrackSid: 'v'), RecordingStartResult.failed);
    expect(rec.isRecording, isFalse);
    expect(rec.lastError, contains('egress down'));
    fn.answerWith({'status': 'started'});
    expect(await rec.start(audioTrackSid: 'a', videoTrackSid: 'v'), RecordingStartResult.started);
  });

  test('stop: stop_recording once; failure keeps the recording flagged', () async {
    var serverDown = false;
    fn.answer((_, _) => serverDown ? throw Exception('down') : {});
    await rec.start(audioTrackSid: 'a', videoTrackSid: 'v');
    serverDown = true;
    expect(await rec.stop(), isFalse);
    expect(rec.isRecording, isTrue);
    serverDown = false;
    expect(await rec.stop(), isTrue);
    expect(rec.isRecording, isFalse);
    expect(await rec.stop(), isTrue, reason: 'nothing to stop');
    expect(fn.calls.where((c) => c.$2['action'] == 'stop_recording'), hasLength(2));
  });

  test('stopInBackground fires once and only while recording', () async {
    rec.stopInBackground();
    expect(fn.calls, isEmpty);
    await rec.start(audioTrackSid: 'a', videoTrackSid: 'v');
    rec.stopInBackground();
    rec.stopInBackground();
    await pumpEventQueue();
    expect(fn.calls.where((c) => c.$2['action'] == 'stop_recording'), hasLength(1));
  });

  test('server flags are mirrored', () {
    rec.syncFromServer(true);
    expect(rec.isRecording, isTrue);
    rec.markStoppedByServer();
    expect(rec.isRecording, isFalse);
  });
}
