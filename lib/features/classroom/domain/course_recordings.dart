/// Class recordings (created by Cloud Functions; pure Dart).
library;

class CourseRecording {
  final String id;

  /// The teacher's own title; null = "Lesson N".
  final String? title;
  final DateTime? recordedAt;
  final String status;

  /// Legacy public link (playback normally uses a signed link from the server).
  final String? videoUrl;
  final Map<String, String>? qualities;
  final int durationSeconds;

  /// 'processing' while the extra qualities are being made.
  final String transcodingStatus;

  const CourseRecording({
    required this.id,
    this.title,
    this.recordedAt,
    this.status = '',
    this.videoUrl,
    this.qualities,
    this.durationSeconds = 0,
    this.transcodingStatus = '',
  });

  /// Cloudflare R2 keeps recordings for 14 days.
  static const retention = Duration(days: 14);

  factory CourseRecording.fromMap(String id, Map<String, dynamic> d) {
    DateTime? at;
    try {
      final dynamic t = d['recordedAt'];
      if (t is DateTime) {
        at = t;
      } else if (t != null) {
        at = t.toDate() as DateTime;
      }
    } catch (_) {}
    final rawQ = d['qualities'];
    return CourseRecording(
      id: id,
      title: d['title'] is String && (d['title'] as String).isNotEmpty ? d['title'] as String : null,
      recordedAt: at,
      status: d['status'] is String ? d['status'] as String : '',
      videoUrl: d['videoUrl'] is String ? d['videoUrl'] as String : null,
      qualities: rawQ is Map ? {for (final e in rawQ.entries) '${e.key}': '${e.value}'} : null,
      durationSeconds: _seconds(d['duration']),
      transcodingStatus: d['transcodingStatus'] is String ? d['transcodingStatus'] as String : '',
    );
  }

  /// LiveKit reports nanoseconds; older documents hold seconds (number or text).
  static int _seconds(Object? raw) {
    final v = raw is num ? raw.toDouble() : (raw is String ? double.tryParse(raw) ?? 0 : 0.0);
    return v > 100000000 ? (v / 1000000000).round() : v.round();
  }

  /// Shown in the list: not failed, and still within the retention window
  /// (undated recordings are kept).
  bool isAvailableAt(DateTime now) =>
      status != 'failed' && (recordedAt == null || recordedAt!.isAfter(now.subtract(retention)));
}
