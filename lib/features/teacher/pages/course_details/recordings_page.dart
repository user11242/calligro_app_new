import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'video_player_page.dart';

class RecordingsPage extends StatelessWidget {
  final String courseId;

  const RecordingsPage({Key? key, required this.courseId}) : super(key: key);

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
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('courses')
                      .doc(courseId)
                      .collection('recordings')
                      .doc(recordingId)
                      .update({'title': newTitle});
                } else {
                  await FirebaseFirestore.instance
                      .collection('courses')
                      .doc(courseId)
                      .collection('recordings')
                      .doc(recordingId)
                      .update({'title': FieldValue.delete()});
                }
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
        title: Text(
          l10n.classRecordings,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .collection('recordings')
            .orderBy('recordedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                l10n.errorLoadingRecordings,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          // Filter out recordings older than 14 days to match Cloudflare R2 retention
          final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));
          final docs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final recordedAt = data['recordedAt'] as Timestamp?;
            if (recordedAt == null) return true; // Keep if no date (fallback)
            return recordedAt.toDate().isAfter(fourteenDaysAgo);
          }).toList();
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noRecordingsAvailable,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
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
                        style: TextStyle(
                          color: Colors.blue[100],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final videoUrl = data['videoUrl'] as String?;
              final recordedAt = data['recordedAt'] as Timestamp?;
              
              final dateStr = recordedAt != null
                  ? DateFormat.yMMMd(l10n.localeName).format(recordedAt.toDate())
                  : 'Unknown Date';

              final lessonNumber = docs.length - index;
              final customTitle = data['title'] as String?;
              final displayTitle = customTitle ?? '${l10n.lesson} $lessonNumber';

              final dynamic durationRaw = data['duration'];
              int durationSeconds = 0;
              if (durationRaw != null) {
                if (durationRaw is num) {
                  durationSeconds = durationRaw > 100000000 ? (durationRaw / 1000000000).round() : durationRaw.round();
                } else if (durationRaw is String) {
                  final parsed = double.tryParse(durationRaw) ?? 0;
                  durationSeconds = parsed > 100000000 ? (parsed / 1000000000).round() : parsed.round();
                }
              }
              
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    highlightColor: AppColors.accentGold.withValues(alpha: 0.1),
                    splashColor: AppColors.accentGold.withValues(alpha: 0.2),
                    onTap: () {
                      if (videoUrl != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerPage(videoUrl: videoUrl, title: displayTitle),
                          ),
                        );
                      }
                    },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. "Thumbnail" Play Box (Right side in RTL)
                            Container(
                              width: 110,
                              height: 70,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.accentGold.withValues(alpha: 0.15),
                                    const Color(0xFF121418), // Deep dark, giving it a sleek studio feel
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.accentGold.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.accentGold,
                                    size: 32,
                                  ),
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
                            
                            // 2. Title and Date (Middle)
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
                                      Text(
                                        '•',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                      ),
                                      Text(
                                        '1080p',
                                        style: TextStyle(
                                          color: AppColors.accentGold.withValues(alpha: 0.8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // 3. Edit Button (Left side in RTL)
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: Colors.white.withValues(alpha: 0.5), size: 20),
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
          );
        },
      ),
    );
  }
}
