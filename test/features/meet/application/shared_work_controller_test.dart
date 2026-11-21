import 'package:calligro_app/features/meet/application/meet_controller.dart';
import 'package:calligro_app/features/meet/data/meet_backend.dart';
import 'package:calligro_app/features/meet/domain/meet_participant.dart';
import 'package:calligro_app/features/meet/domain/meet_protocol.dart';
import 'package:calligro_app/features/meet/domain/shared_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_functions.dart';
import '../fakes/fake_meet_room.dart';

/// The teacher shows a student's work to the class: what the teacher's app
/// sends, and what every student's app shows. Written before the code.
void main() {
  const url = 'https://firebasestorage.googleapis.com/v0/b/x/o/s1_w.pdf?alt=media&token=t';
  late FakeMeetRoom room;
  late DateTime now;
  late int ids;

  MeetController make({required bool teacher}) {
    if (teacher) {
      room.identityOnConnect = 'T1_mobile';
      room.nameOnConnect = 'Teacher One';
      room.metadataOnConnect = '{"role":"moderator","teacherId":"T1"}';
    }
    return MeetController(
      room: room,
      backend: MeetBackend(courseId: 'c1', call: FakeFunctions().call, delay: (_) async {}),
      token: 'jwt',
      serverUrl: 'wss://lk',
      isTeacher: teacher,
      teacherId: 'T1',
      connectGrace: Duration.zero,
      endMeetingSignalDelay: Duration.zero,
      clock: () => now,
      newId: () => 'id${ids++}',
    );
  }

  Future<MeetController> joined({required bool teacher}) async {
    final c = make(teacher: teacher);
    await c.join();
    await pumpEventQueue();
    room.published.clear();
    return c;
  }

  List<Map<String, dynamic>> sent() => room.published.where((m) => MeetProtocol.sharedWorkTypes.contains(m['type'])).toList();

  setUp(() {
    room = FakeMeetRoom();
    now = DateTime(2026, 11, 18, 10);
    ids = 0;
  });

  group('the teacher', () {
    test('shows a submission: everyone gets it with the student name and assignment', () async {
      final c = await joined(teacher: true);
      c.showWork(url: url, kind: SharedWorkKind.pdf, studentName: 'Sara', assignmentTitle: 'Alif drills');
      expect(c.sharedWork!.studentName, 'Sara');
      expect(sent().single, SharedWorkProtocol.show(
          shareId: c.sharedWork!.shareId, url: url, kind: SharedWorkKind.pdf, studentName: 'Sara', assignmentTitle: 'Alif drills'));
    });

    test('draws: the line appears at once on their screen and reaches everyone in small pieces', () async {
      final c = await joined(teacher: true);
      c.showWork(url: url, kind: SharedWorkKind.image, studentName: 'Sara', assignmentTitle: 'A');
      room.published.clear();

      final id = c.startStroke(color: 0xFFE53935, width: 0.01, at: const SharedPoint(0.1, 0.1));
      now = now.add(const Duration(milliseconds: 10));
      c.extendStroke(id, const SharedPoint(0.2, 0.2)); // too soon: held back
      expect(sent(), isEmpty);
      now = now.add(const Duration(milliseconds: 100));
      c.extendStroke(id, const SharedPoint(0.3, 0.3)); // sends what is pending
      c.extendStroke(id, const SharedPoint(0.4, 0.4));
      c.endStroke(id); // sends the rest

      expect(c.sharedWork!.strokes.single.points.length, 4);
      expect(sent().map((m) => (m['from'], (m['points'] as List).length ~/ 2)), [(0, 3), (3, 1)]);

      // A student applying exactly these messages sees the same line.
      SharedWork? theirs = SharedWorkReducer.apply(null, SharedWorkMessage.parse(SharedWorkProtocol.show(
          shareId: c.sharedWork!.shareId, url: url, kind: SharedWorkKind.image, studentName: 'Sara', assignmentTitle: 'A'))!);
      for (final m in sent()) {
        theirs = SharedWorkReducer.apply(theirs, SharedWorkMessage.parse(m)!);
      }
      expect(theirs, c.sharedWork);
    });

    test('undo removes their last line on this page; clear empties the page', () async {
      final c = await joined(teacher: true);
      c.showWork(url: url, kind: SharedWorkKind.pdf, studentName: 'Sara', assignmentTitle: 'A');
      for (var i = 0; i < 2; i++) {
        c.endStroke(c.startStroke(color: 1, width: 0.01, at: const SharedPoint(0.5, 0.5)));
      }
      room.published.clear();
      c.undoStroke();
      expect(c.sharedWork!.strokes, hasLength(1));
      expect(sent().single['type'], MeetProtocol.workUndo);
      c.clearPage();
      expect(c.sharedWork!.strokes, isEmpty);
      expect(sent().last['type'], MeetProtocol.workClear);
    });

    test('turns PDF pages and zooms (the zoom is sent at most every 100 ms, and always at the end)', () async {
      final c = await joined(teacher: true);
      c.showWork(url: url, kind: SharedWorkKind.pdf, studentName: 'Sara', assignmentTitle: 'A');
      room.published.clear();
      c.setPage(2);
      expect(c.sharedWork!.page, 2);
      c.setView(const SharedView(scale: 1.5, dx: 0, dy: 0));
      now = now.add(const Duration(milliseconds: 20));
      c.setView(const SharedView(scale: 1.8, dx: 0, dy: 0)); // held back
      c.endViewChange();
      expect(sent().map((m) => m['type']), [MeetProtocol.workPage, MeetProtocol.workView, MeetProtocol.workView]);
      expect(sent().last['scale'], 1.8);
      expect(c.sharedWork!.view.scale, 1.8);
    });

    test('stops sharing: it closes for everyone', () async {
      final c = await joined(teacher: true);
      c.showWork(url: url, kind: SharedWorkKind.image, studentName: 'Sara', assignmentTitle: 'A');
      final shareId = c.sharedWork!.shareId;
      c.stopSharing();
      expect(c.sharedWork, isNull);
      expect(sent().last, SharedWorkProtocol.stop(shareId));
    });

    test('someone joins late: they get the whole picture (work, page, zoom, every line)', () async {
      final c = await joined(teacher: true);
      c.showWork(url: url, kind: SharedWorkKind.pdf, studentName: 'Sara', assignmentTitle: 'A');
      c.setPage(1);
      c.endStroke(c.startStroke(color: 1, width: 0.01, at: const SharedPoint(0.5, 0.5)));
      room.published.clear();
      room.addRemote(const MeetParticipant(identity: 's9', name: 'Late Student'));
      await pumpEventQueue();
      expect(sent(), SharedWorkProtocol.snapshot(c.sharedWork!));
    });

    test('nothing is resent when nothing is shown', () async {
      await joined(teacher: true);
      room.addRemote(const MeetParticipant(identity: 's9', name: 'Late Student'));
      await pumpEventQueue();
      expect(sent(), isEmpty);
    });
  });

  group('a student', () {
    test('sees what the teacher shows, follows it, and it closes when the teacher stops', () async {
      final c = await joined(teacher: false);
      room.receiveFromTeacher(SharedWorkProtocol.show(
          shareId: 'sh1', url: url, kind: SharedWorkKind.pdf, studentName: 'Sara', assignmentTitle: 'A'));
      room.receiveFromTeacher(SharedWorkProtocol.page('sh1', 3));
      await pumpEventQueue();
      expect(c.sharedWork!.page, 3);
      expect(c.sharedWork!.studentName, 'Sara');
      room.receiveFromTeacher(SharedWorkProtocol.stop('sh1'));
      await pumpEventQueue();
      expect(c.sharedWork, isNull);
    });

    test('another student cannot put anything on the screen', () async {
      final c = await joined(teacher: false);
      room.receive(
          SharedWorkProtocol.show(shareId: 'x', url: url, kind: SharedWorkKind.image, studentName: 'Me', assignmentTitle: 'A'),
          identity: 's2',
          metadata: '{"role":"participant","teacherId":"T1"}');
      await pumpEventQueue();
      expect(c.sharedWork, isNull);
    });

    test('cannot use the teacher controls (they do nothing and send nothing)', () async {
      final c = await joined(teacher: false);
      c.showWork(url: url, kind: SharedWorkKind.image, studentName: 'Me', assignmentTitle: 'A');
      c.endStroke(c.startStroke(color: 1, width: 0.01, at: const SharedPoint(0, 0)));
      c.stopSharing();
      expect(c.sharedWork, isNull);
      expect(sent(), isEmpty);
    });
  });
}
