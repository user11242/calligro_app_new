import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareUtils {
  /// Captures a [RepaintBoundary] as an image and shares it.
  static Future<void> shareWidgetAsImage({
    required GlobalKey boundaryKey,
    required String text,
    required String subject,
  }) async {
    try {
      // 1. Capture the boundary
      final RenderRepaintBoundary? boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) return;

      // Ensure the image is captured with high quality (pixelRatio)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // 2. Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/course_share_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(bytes);

      // 3. Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        subject: subject,
      );
    } catch (e) {
      debugPrint('Error sharing widget: $e');
    }
  }
}
