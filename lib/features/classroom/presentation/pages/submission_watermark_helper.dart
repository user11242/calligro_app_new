import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';

class SubmissionWatermarkHelper {
  static const _supportedImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
  ];

  static bool isSupportedImage(String filePath) {
    final lower = filePath.toLowerCase();
    return _supportedImageExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Stamps a professional metadata badge directly on the image bytes
  /// matching the style of Calligro's dark and gold branding.
  static Future<Uint8List> stampImageBytes({
    required Uint8List imageBytes,
    required String studentName,
    required String assignmentTitle,
    required String teacherName,
    DateTime? submissionDate,
    bool isRtl = true,
  }) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final ui.Image baseImage = frame.image;

    final imgW = baseImage.width.toDouble();
    final imgH = baseImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgW, imgH));

    // 1. Draw base image
    canvas.drawImage(baseImage, Offset.zero, Paint());

    // 2. Responsive badge sizing relative to image width
    // Prominent, crisp, and comfortable to read on both mobile displays and high-res camera photos
    final scale = (imgW / 700.0).clamp(1.15, 6.0);
    final badgePaddingH = 32.0 * scale;
    final badgePaddingV = 22.0 * scale;
    final titleFontSize = (24.0 * scale).clamp(22.0, 96.0);
    final fontSize = (19.0 * scale).clamp(17.0, 78.0);
    final labelFontSize = (16.0 * scale).clamp(15.0, 65.0);

    final date = submissionDate ?? DateTime.now();
    final formattedDate = intl.DateFormat('yyyy-MM-dd • hh:mm a').format(date);

    // 3. Build text layout (Dark theme with Gold accents to match Calligro brand)
    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;
    final textPainter = TextPainter(
      textDirection: textDirection,
      textAlign: isRtl ? TextAlign.right : TextAlign.left,
    );

    final textSpan = TextSpan(
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: fontSize,
        color: Colors.white,
        height: 1.45,
      ),
      children: [
        TextSpan(
          text: '$assignmentTitle\n',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFEEE593), // AppColors.textColor (Warm Gold)
          ),
        ),
        TextSpan(
          text: isRtl ? 'الطالب: ' : 'Student: ',
          style: TextStyle(
            fontSize: labelFontSize,
            color: const Color(0xFFD4AF37), // AppColors.accentGold
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: '$studentName   |   ',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        TextSpan(
          text: isRtl ? 'المعلم: ' : 'Teacher: ',
          style: TextStyle(
            fontSize: labelFontSize,
            color: const Color(0xFFD4AF37), // AppColors.accentGold
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: '$teacherName\n',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        TextSpan(
          text: isRtl ? 'تاريخ التسليم: ' : 'Submitted: ',
          style: TextStyle(
            fontSize: labelFontSize,
            color: Colors.white60,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: formattedDate,
          style: TextStyle(
            fontSize: labelFontSize,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final maxBadgeTextWidth = (imgW - (80.0 * scale)).clamp(300.0, imgW * 0.92);
    textPainter.text = textSpan;
    textPainter.layout(maxWidth: maxBadgeTextWidth);

    final badgeW = textPainter.width + (badgePaddingH * 2);
    final badgeH = textPainter.height + (badgePaddingV * 2);

    // 4. Badge Position (Top Left / Right with margin)
    final margin = 28.0 * scale;
    final badgeLeft = isRtl ? (imgW - badgeW - margin) : margin;
    final badgeTop = margin;

    final badgeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeLeft, badgeTop, badgeW, badgeH),
      Radius.circular(18.0 * scale),
    );

    // Soft drop shadow for clean contrast against any paper tone
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16.0 * scale);
    canvas.drawRRect(
      badgeRRect.shift(Offset(0, 6.0 * scale)),
      shadowPaint,
    );

    // Deep Dark Theme Background (Solid, non-white: 0xF817171A)
    final bgPaint = Paint()..color = const Color(0xF817171A);
    canvas.drawRRect(badgeRRect, bgPaint);

    // Rich gold border
    final borderPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale;
    canvas.drawRRect(badgeRRect, borderPaint);

    // Accent gold vertical strip on leading edge
    final accentStripW = 6.0 * scale;
    final stripRRect = isRtl
        ? RRect.fromRectAndCorners(
            Rect.fromLTWH(badgeLeft + badgeW - accentStripW, badgeTop, accentStripW, badgeH),
            topRight: Radius.circular(18.0 * scale),
            bottomRight: Radius.circular(18.0 * scale),
          )
        : RRect.fromRectAndCorners(
            Rect.fromLTWH(badgeLeft, badgeTop, accentStripW, badgeH),
            topLeft: Radius.circular(18.0 * scale),
            bottomLeft: Radius.circular(18.0 * scale),
          );
    canvas.drawRRect(stripRRect, Paint()..color = const Color(0xFFD4AF37));

    // Paint text inside badge
    textPainter.paint(
      canvas,
      Offset(badgeLeft + badgePaddingH, badgeTop + badgePaddingV),
    );

    // 5. Finalize stamped image
    final picture = recorder.endRecording();
    final stampedImage = await picture.toImage(baseImage.width, baseImage.height);
    final byteData = await stampedImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Takes an input file path, stamps it if it's an image, and writes to a new temporary file.
  /// If it is not an image (e.g. PDF), returns the original file unmodified.
  static Future<File> watermarkSubmissionFile({
    required File inputFile,
    required String studentName,
    required String assignmentTitle,
    required String teacherName,
    bool isRtl = true,
  }) async {
    if (!isSupportedImage(inputFile.path)) {
      return inputFile;
    }

    try {
      final bytes = await inputFile.readAsBytes();
      final stampedBytes = await stampImageBytes(
        imageBytes: bytes,
        studentName: studentName,
        assignmentTitle: assignmentTitle,
        teacherName: teacherName,
        isRtl: isRtl,
      );

      final tempDir = await getTemporaryDirectory();
      final ext = inputFile.path.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
      final fileName = 'stamped_${DateTime.now().millisecondsSinceEpoch}$ext';
      final outputFile = File('${tempDir.path}/$fileName');
      await outputFile.writeAsBytes(stampedBytes);
      return outputFile;
    } catch (e) {
      debugPrint('SubmissionWatermarkHelper error: $e');
      return inputFile; // Safe fallback to original
    }
  }
}
