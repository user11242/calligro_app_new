import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

import '../domain/shared_work.dart';

/// Turns a shared submission into page images: one for a photo, one per page for a PDF.
typedef SharedWorkPageLoader = Future<List<ui.Image>> Function(String url, SharedWorkKind kind);

/// Longest side of a decoded photo (keeps memory sane for 12-megapixel phone photos).
const _maxImageSide = 2200;

/// PDF pages rendered at this resolution (sharp enough to zoom 3x on a phone).
const _pdfDpi = 120.0;

/// Big PDFs: only the first pages are shown in class.
const maxSharedPdfPages = 40;

/// The real loader: downloads the file and decodes it on this device.
Future<List<ui.Image>> loadSharedWorkPages(String url, SharedWorkKind kind, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final res = await c.get(Uri.parse(url));
    if (res.statusCode != 200) throw SharedWorkLoadException('HTTP ${res.statusCode}');
    final bytes = res.bodyBytes;
    return kind == SharedWorkKind.pdf ? await _pdfPages(bytes) : [await _image(bytes)];
  } finally {
    if (client == null) c.close();
  }
}

Future<ui.Image> _image(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final scale = math.min(1.0, _maxImageSide / math.max(descriptor.width, descriptor.height));
  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * scale).round(),
    targetHeight: (descriptor.height * scale).round(),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}

Future<List<ui.Image>> _pdfPages(Uint8List bytes) async {
  final pages = <ui.Image>[];
  await for (final raster in Printing.raster(bytes, dpi: _pdfDpi)) {
    pages.add(await raster.toImage());
    if (pages.length >= maxSharedPdfPages) break;
  }
  if (pages.isEmpty) throw const SharedWorkLoadException('empty PDF');
  return pages;
}

class SharedWorkLoadException implements Exception {
  final String message;
  const SharedWorkLoadException(this.message);
  @override
  String toString() => 'SharedWorkLoadException: $message';
}
