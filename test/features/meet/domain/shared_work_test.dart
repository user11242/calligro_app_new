import 'package:calligro_app/features/meet/domain/meet_protocol.dart';
import 'package:calligro_app/features/meet/domain/shared_work.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Show a student's work to the class": what each wire message means, what is
/// refused, and how every screen ends up showing the same thing. Written first.
void main() {
  const url = 'https://firebasestorage.googleapis.com/v0/b/calligro/o/course_submissions%2Fc1%2Fa1%2Fs1_w.jpg?alt=media&token=t';
  SharedWorkMessage? parse(Map<String, dynamic> m) => SharedWorkMessage.parse(m);
  Map<String, dynamic> show({String shareId = 'sh1', String u = url, String kind = 'image'}) =>
      SharedWorkProtocol.show(shareId: shareId, url: u, kind: SharedWorkKind.values.byName(kind), studentName: 'Sara', assignmentTitle: 'Alif drills');
  SharedWork? run(List<Map<String, dynamic>> messages, [SharedWork? start]) {
    var s = start;
    for (final m in messages) {
      s = SharedWorkReducer.apply(s, parse(m)!);
    }
    return s;
  }

  SharedStroke stroke(String id, {int page = 0, List<SharedPoint>? points}) => SharedStroke(
        id: id,
        page: page,
        color: 0xFFE53935,
        width: 0.01,
        points: points ?? const [SharedPoint(0.1, 0.2), SharedPoint(0.3, 0.4)],
      );

  group('which files can be shown', () {
    test('images and PDFs, by file name or link', () {
      expect(SharedWorkKind.fromFile(fileName: 'work.JPG', url: url), SharedWorkKind.image);
      expect(SharedWorkKind.fromFile(fileName: 'sheet.pdf', url: url), SharedWorkKind.pdf);
      expect(SharedWorkKind.fromFile(fileName: null, url: '$url&x=.png'), SharedWorkKind.image);
      expect(SharedWorkKind.fromFile(fileName: 'scan.heic', url: url), SharedWorkKind.image);
      expect(SharedWorkKind.fromFile(fileName: 'notes.docx', url: url), isNull);
      expect(SharedWorkKind.fromFile(fileName: 'clip.mp4', url: url), isNull);
    });
  });

  group('parsing what arrives on the wire', () {
    test('show: the student name and assignment come along', () {
      final m = parse(show())!;
      expect(m, isA<ShowWork>());
      expect((m as ShowWork).studentName, 'Sara');
      expect(m.assignmentTitle, 'Alif drills');
      expect(m.kind, SharedWorkKind.image);
    });
    test('only Firebase Storage https links are opened (never an arbitrary site)', () {
      expect(parse(show(u: 'https://evil.example.com/x.jpg')), isNull);
      expect(parse(show(u: 'http://firebasestorage.googleapis.com/x.jpg')), isNull);
      expect(parse(show(u: 'javascript:alert(1)')), isNull);
      expect(parse(show(u: 'https://storage.googleapis.com/calligro/x.jpg')), isNotNull);
    });
    test('unknown kinds, missing ids and junk are refused', () {
      expect(parse({...show(), 'kind': 'video'}), isNull);
      expect(parse({...show(), 'shareId': ''}), isNull);
      expect(parse({'type': MeetProtocol.workShow}), isNull);
      expect(parse({'type': 'raise_hand'}), isNull);
    });
    test('long names are cut, not trusted to fit', () {
      final m = parse({...show(), 'studentName': 'x' * 500}) as ShowWork;
      expect(m.studentName.length, lessThanOrEqualTo(80));
    });
    test('points are kept inside the page and numbers are bounded', () {
      final m = parse(SharedWorkProtocol.stroke('sh1', stroke('k1', points: const [SharedPoint(-3, 9), SharedPoint(0.5, 0.5)]))) as DrawStroke;
      expect(m.stroke.points.first, const SharedPoint(0, 1));
      final v = parse(SharedWorkProtocol.view('sh1', const SharedView(scale: 99, dx: -50, dy: 50))) as SetView;
      expect(v.view.scale, SharedView.maxScale);
      expect(v.view.dx, -SharedView.maxShift);
      expect(v.view.dy, SharedView.maxShift);
      expect(parse(SharedWorkProtocol.page('sh1', -1)), isNull);
    });
    test('a stroke message round-trips (rounded to 4 decimals)', () {
      final s = stroke('k1', points: const [SharedPoint(0.123456, 0.654321)]);
      final m = parse(SharedWorkProtocol.stroke('sh1', s)) as DrawStroke;
      expect(m.stroke.points.single, const SharedPoint(0.1235, 0.6543));
      expect(m.stroke.color, s.color);
      expect(m.from, 0);
    });
  });

  group('every screen shows the same thing', () {
    test('show opens it on page 1, unzoomed, with no drawings', () {
      final s = run([show()])!;
      expect(s.shareId, 'sh1');
      expect(s.page, 0);
      expect(s.view, SharedView.identity);
      expect(s.strokes, isEmpty);
      expect(s.studentName, 'Sara');
    });
    test('a stroke drawn live arrives in pieces and is joined in order', () {
      final s = run([
        show(),
        SharedWorkProtocol.stroke('sh1', stroke('k1', points: const [SharedPoint(0, 0), SharedPoint(0.1, 0.1)])),
        SharedWorkProtocol.stroke('sh1', stroke('k1', points: const [SharedPoint(0.2, 0.2)]), from: 2),
      ])!;
      expect(s.strokes.single.points, const [SharedPoint(0, 0), SharedPoint(0.1, 0.1), SharedPoint(0.2, 0.2)]);
    });
    test('receiving the same piece twice changes nothing (resends are safe)', () {
      final piece = SharedWorkProtocol.stroke('sh1', stroke('k1', points: const [SharedPoint(0.2, 0.2)]), from: 1);
      final s = run([show(), SharedWorkProtocol.stroke('sh1', stroke('k1', points: const [SharedPoint(0, 0)])), piece, piece])!;
      expect(s.strokes.single.points, const [SharedPoint(0, 0), SharedPoint(0.2, 0.2)]);
    });
    test('showing the same work again (late-joiner resend) keeps the drawings', () {
      final s = run([show(), SharedWorkProtocol.stroke('sh1', stroke('k1')), show()])!;
      expect(s.strokes, hasLength(1));
    });
    test('showing a different work starts clean', () {
      final s = run([show(), SharedWorkProtocol.stroke('sh1', stroke('k1')), show(shareId: 'sh2')])!;
      expect(s.shareId, 'sh2');
      expect(s.strokes, isEmpty);
    });
    test('PDF pages: drawings belong to their page; turning the page resets the zoom', () {
      final s = run([
        show(kind: 'pdf'),
        SharedWorkProtocol.view('sh1', const SharedView(scale: 2, dx: 0.1, dy: 0)),
        SharedWorkProtocol.stroke('sh1', stroke('k1', page: 0)),
        SharedWorkProtocol.page('sh1', 1),
        SharedWorkProtocol.stroke('sh1', stroke('k2', page: 1)),
      ])!;
      expect(s.page, 1);
      expect(s.view, SharedView.identity);
      expect(s.strokesOnPage.map((x) => x.id), ['k2']);
      expect(s.strokes, hasLength(2));
    });
    test('undo removes one stroke; clear empties only the current page', () {
      final s = run([
        show(kind: 'pdf'),
        SharedWorkProtocol.stroke('sh1', stroke('k1', page: 0)),
        SharedWorkProtocol.stroke('sh1', stroke('k2', page: 0)),
        SharedWorkProtocol.stroke('sh1', stroke('k3', page: 1)),
        SharedWorkProtocol.undo('sh1', 'k2'),
      ])!;
      expect(s.strokes.map((x) => x.id), ['k1', 'k3']);
      final cleared = run([SharedWorkProtocol.clear('sh1', 0)], s)!;
      expect(cleared.strokes.map((x) => x.id), ['k3']);
    });
    test('stop closes it for everyone', () {
      expect(run([show(), SharedWorkProtocol.stop('sh1')]), isNull);
    });
    test('messages about another (old) share are ignored', () {
      final s = run([show(shareId: 'sh2'), SharedWorkProtocol.stroke('sh1', stroke('k1')), SharedWorkProtocol.stop('sh1')])!;
      expect(s.shareId, 'sh2');
      expect(s.strokes, isEmpty);
    });
    test('messages before anything is shown are ignored', () {
      expect(run([SharedWorkProtocol.stroke('sh1', stroke('k1'))]), isNull);
    });
  });

  group('resending everything to someone who joins late', () {
    test('show, page, zoom and every stroke, in that order, rebuild the same picture', () {
      final s = run([
        show(kind: 'pdf'),
        SharedWorkProtocol.page('sh1', 2),
        SharedWorkProtocol.view('sh1', const SharedView(scale: 1.5, dx: 0.2, dy: -0.1)),
        SharedWorkProtocol.stroke('sh1', stroke('k1', page: 2)),
      ])!;
      final rebuilt = run(SharedWorkProtocol.snapshot(s));
      expect(rebuilt, s);
    });
    test('a very long stroke is split into pieces that each fit in one message', () {
      final long = stroke('k1', points: [for (var i = 0; i < 2500; i++) SharedPoint(i / 2500, 0.5)]);
      final s = SharedWork(
          shareId: 'sh1', url: url, kind: SharedWorkKind.image, studentName: 'Sara', assignmentTitle: 'A', strokes: [long]);
      final messages = SharedWorkProtocol.snapshot(s);
      final pieces = messages.where((m) => m['type'] == MeetProtocol.workStroke).toList();
      expect(pieces.length, greaterThan(1));
      for (final m in messages) {
        expect(MeetProtocol.encode(m).length, lessThan(14000));
      }
      expect(run(messages), s);
    });
  });
}
