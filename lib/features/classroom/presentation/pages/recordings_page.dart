import 'package:flutter/material.dart';
import 'package:calligro_app/features/classroom/application/classroom_recordings.dart';
import 'package:calligro_app/features/classroom/domain/classroom_models.dart';
import 'package:calligro_app/features/classroom/domain/course_recordings.dart';
import 'package:calligro_app/features/classroom/presentation/classroom_scope.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'video_player_page.dart';
import 'package:calligro_app/features/meet/data/meet_backend.dart';

class RecordingsPage extends StatefulWidget {
  final String courseId;

  /// The viewer's role in THIS course (only its teacher / an admin renames).
  final CourseRole role;

  const RecordingsPage({Key? key, required this.courseId, this.role = CourseRole.student}) : super(key: key);

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  bool _isReconciling = false;
  ClassroomRecordings? _recordings;
  Stream<List<CourseRecording>>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recordings != null) return;
    _recordings = ClassroomScope.of(context).recordings;
    _stream = _recordings!.repository.watchRecordings(widget.courseId);
    _reconcileRecordings(); // once, when the list opens
  }

  bool _isOpeningRecording = false;

  /// Plays a recording through a short-lived signed URL issued by the server
  /// (only for the course's teacher, enrolled students and admins).
  /// Falls back to the legacy public URL only if the signed-URL call fails, so playback
  /// keeps working until the R2 bucket is made private.
  Future<void> _openRecording({
    required String recordingId,
    required String title,
    String? legacyUrl,
    Map<String, String>? legacyQualities,
  }) async {
    if (_isOpeningRecording) return;
    _isOpeningRecording = true;
    String? url;
    Map<String, String>? qualities;
    try {
      final playback = await MeetBackend(courseId: widget.courseId).playback(recordingId);
      url = playback.url;
      // Signed URLs per quality; only offer a choice when transcoded renditions exist.
      qualities = playback.qualities.length > 1 ? playback.qualities : null;
    } catch (e) {
      debugPrint('Signed playback URL failed, falling back to legacy URL: $e');
      url = legacyUrl;
      qualities = legacyQualities;
    } finally {
      _isOpeningRecording = false;
    }

    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.recordingError)));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(videoUrl: url!, title: title, qualities: qualities),
      ),
    );
  }

  /// Self-healing reconciliation: checks Cloudflare R2 for any completed recordings
  /// that weren't finalized due to network drops, app crash, or webhook latency.
  Future<void> _reconcileRecordings() async {
    if (_isReconciling) return;
    _isReconciling = true;

    try {
      await _recordings!.recoverMissing(widget.courseId);
    } finally {
      if (mounted) _isReconciling = false;
    }
  }

  void _showEditTitleDialog(BuildContext context, AppLocalizations l10n, String recordingId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2D35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            l10n.editTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.accentGold,
            decoration: InputDecoration(
              labelText: l10n.recordingTitle,
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accentGold),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                // Empty = back to "Lesson N".
                await _recordings!.rename(widget.courseId, widget.role, recordingId, controller.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.save, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.classRecordings, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accentGold),
            tooltip: 'تحديث واسترجاع التسجيلات',
            onPressed: () async {
              await _reconcileRecordings();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<List<CourseRecording>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(l10n.errorLoadingRecordings, style: const TextStyle(color: Colors.white)),
            );
          }
          final allDocs = snapshot.data ?? const <CourseRecording>[];
          // Not failed, and within Cloudflare R2's 14-day retention.
          final now = DateTime.now();
          final docs = allDocs.where((r) => r.isAvailableAt(now)).toList();
          if (docs.isEmpty) {
            return RefreshIndicator(
              color: AppColors.accentGold,
              backgroundColor: const Color(0xFF1E2026),
              onRefresh: _reconcileRecordings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noRecordingsAvailable,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.accentGold,
            backgroundColor: const Color(0xFF1E2026),
            onRefresh: _reconcileRecordings,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.recordingExpirationNote,
                          style: TextStyle(color: Colors.blue[100], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final videoUrl = doc.videoUrl;
                      final recordedAt = doc.recordedAt;
                      final Map<String, String>? qualities = doc.qualities;

                      final dateStr = recordedAt != null
                          ? DateFormat.yMMMd(l10n.localeName).format(recordedAt)
                          : 'Unknown Date';

                      final originalIndex = allDocs.indexOf(doc);
                      final lessonNumber = allDocs.length - originalIndex;
                      final displayTitle = doc.title ?? '${l10n.lesson} $lessonNumber';
                      final durationSeconds = doc.durationSeconds;

                      String durationStr = '';
                      if (durationSeconds > 0) {
                        final h = durationSeconds ~/ 3600;
                        final m = (durationSeconds % 3600) ~/ 60;
                        final s = durationSeconds % 60;
                        if (h > 0) {
                          durationStr = '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                        } else {
                          durationStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                        }
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2026),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            highlightColor: AppColors.accentGold.withValues(alpha: 0.1),
                            splashColor: AppColors.accentGold.withValues(alpha: 0.2),
                            onTap: () => _openRecording(
                              recordingId: doc.id,
                              title: displayTitle,
                              legacyUrl: videoUrl,
                              legacyQualities: qualities,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. "Thumbnail" Play Box
                                  Container(
                                    width: 110,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [AppColors.accentGold.withValues(alpha: 0.15), const Color(0xFF121418)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.15), width: 1),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const Icon(Icons.play_arrow_rounded, color: AppColors.accentGold, size: 32),
                                        if (durationStr.isNotEmpty)
                                          Positioned(
                                            bottom: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                durationStr,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // 2. Title, Date & Multi-Quality Badge
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 2),
                                        Text(
                                          displayTitle,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: AppColors.accentGold.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AppColors.accentGold.withValues(alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                (doc.transcodingStatus == 'processing')
                                                    ? '1080p • جاري تجهيز الجودات'
                                                    : (qualities != null && qualities.length > 1)
                                                    ? '1080p • متعدد الجودات'
                                                    : '1080p Full HD',
                                                style: const TextStyle(
                                                  color: AppColors.accentGold,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 3. Edit Button (the course's teacher / an admin only)
                                  if (widget.role.canManage)
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white.withValues(alpha: 0.5),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _showEditTitleDialog(context, l10n, doc.id, displayTitle);
                                      },
                                      padding: const EdgeInsets.only(left: 4, top: 4),
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
