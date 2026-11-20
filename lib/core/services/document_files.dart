import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Documents (PDFs and other files) that people share in the app: assignment
/// submissions and course-chat files.
class DocumentFiles {
  DocumentFiles._();

  /// The file name from a Storage download link (".../o/course_chats%2Fc1%2Ft1_123.pdf?alt=media").
  static String _nameInUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    return Uri.decodeComponent(path).split('/').last;
  }

  static bool isPdf(String name, String url) =>
      name.toLowerCase().endsWith('.pdf') || _nameInUrl(url).toLowerCase().endsWith('.pdf');

  /// A name to save the file under, always with its extension (PDFs end in ".pdf").
  static String downloadName(String name, String url) {
    var clean = name.trim();
    if (clean.isEmpty || clean == 'submission_file') {
      final inUrl = _nameInUrl(url);
      clean = inUrl.isNotEmpty ? inUrl : 'document';
    }
    if (isPdf(name, url) && !clean.toLowerCase().endsWith('.pdf')) clean = '$clean.pdf';
    return clean;
  }

  /// Downloads the file in the app, then opens the phone's own "save / open with" sheet
  /// (iOS "Save to Files", Android "Downloads" or a PDF app). Handing the link to another
  /// app instead did nothing on Android when no app took it. Throws if the download fails.
  static Future<void> save(String url, String name) async {
    final file = await DefaultCacheManager().getSingleFile(url);
    final fileName = downloadName(name, url);
    if (isPdf(name, url)) {
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: fileName);
    } else {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, name: fileName)]));
    }
  }
}
