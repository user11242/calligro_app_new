import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Fixes EXIF orientation by re-encoding the image with the rotation baked in.
/// This ensures Android displays the image the same way iOS does.
Future<File> fixExifRotation(File imageFile) async {
  final tempDir = await getTemporaryDirectory();
  final targetPath =
      '${tempDir.path}/exif_fixed_${DateTime.now().millisecondsSinceEpoch}.jpg';

  final XFile? result = await FlutterImageCompress.compressAndGetFile(
    imageFile.path,
    targetPath,
    quality: 90,
    autoCorrectionAngle: true, // ← Bakes the EXIF rotation into the pixels
    keepExif: false,            // ← Strips the EXIF tag so Android can't mis-read it
  );

  return result != null ? File(result.path) : imageFile;
}
