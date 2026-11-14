import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/teacher/pages/course_details/submission_watermark_helper.dart';

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
        teacherName: 'مسعود بن حافظ',
        submissionDate: DateTime(2026, 11, 14, 15, 30),
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
  });
}

