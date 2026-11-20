import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/classroom/presentation/pages/submission_watermark_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubmissionWatermarkHelper Tests', () {
    test('isSupportedImage correctly identifies image formats', () {
      expect(SubmissionWatermarkHelper.isSupportedImage('test.jpg'), isTrue);
      expect(SubmissionWatermarkHelper.isSupportedImage('test.JPEG'), isTrue);
      expect(SubmissionWatermarkHelper.isSupportedImage('test.png'), isTrue);
      expect(SubmissionWatermarkHelper.isSupportedImage('test.webp'), isTrue);
      expect(SubmissionWatermarkHelper.isSupportedImage('document.pdf'), isFalse);
      expect(SubmissionWatermarkHelper.isSupportedImage('archive.zip'), isFalse);
    });

    test('stampImageBytes stamps metadata onto an image and preserves dimensions', () async {
      // Create a solid red 400x300 image in memory
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 400, 300));
      canvas.drawPaint(ui.Paint()..color = const ui.Color(0xFFFF0000));
      final picture = recorder.endRecording();
      final img = await picture.toImage(400, 300);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final inputBytes = byteData!.buffer.asUint8List();

      final stampedBytes = await SubmissionWatermarkHelper.stampImageBytes(
        imageBytes: inputBytes,
        studentName: 'أحمد محمود',
        assignmentTitle: 'واجب خط الرقعة',
        isRtl: true,
      );

      expect(stampedBytes, isNotNull);
      expect(stampedBytes.length, greaterThan(0));

      // Decode stamped image to verify dimensions
      final codec = await ui.instantiateImageCodec(stampedBytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 400);
      expect(frame.image.height, 300);
    });

    test('the badge is turned 90° (reads top to bottom) and sits in the BOTTOM-LEFT corner (the top stays clean)', () async {
      // A white portrait photo, like a phone picture of a whiteboard.
      const w = 1500, h = 2000;
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 1500, 2000)).drawPaint(ui.Paint()..color = const ui.Color(0xFFFFFFFF));
      final white = await (await recorder.endRecording().toImage(w, h)).toByteData(format: ui.ImageByteFormat.png);

      final stamped = await SubmissionWatermarkHelper.stampImageBytes(
        imageBytes: white!.buffer.asUint8List(),
        studentName: 'yazan Akq',
        assignmentTitle: 'sdfs',
        isRtl: true,
      );
      final out = Platform.environment['WATERMARK_PREVIEW'];
      if (out != null) File(out).writeAsBytesSync(stamped);

      final image = (await (await ui.instantiateImageCodec(stamped)).getNextFrame()).image;
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      bool dark(int x, int y) => rgba.getUint8((y * w + x) * 4) < 80;

      // Find the badge: the dark area's bounding box.
      var minX = w, maxX = 0, minY = h, maxY = 0;
      for (var y = 0; y < h; y += 4) {
        for (var x = 0; x < w; x += 4) {
          if (dark(x, y)) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      expect(maxX, greaterThan(minX), reason: 'a badge was drawn');
      expect(maxY - minY, greaterThan(maxX - minX), reason: 'turned 90°: taller than wide');
      expect(minX, lessThan(w * 0.1), reason: 'against the left edge');
      expect(maxY, greaterThan(h * 0.9), reason: 'down at the bottom');
      expect(maxX, lessThan(w * 0.5), reason: 'stays on the left');
      expect(dark(w - 200, 150) || dark(200, 150), isFalse, reason: 'the old top position is clean');
    });
  });
}
