import 'package:flutter/material.dart';

import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

import '../../domain/classroom_models.dart';
import '../classroom_scope.dart';

const _gold = Color(0xFFEBB937);

/// The student work the teacher picked to show in the live class.
class SubmissionToShare {
  final String url;
  final String? fileName;
  final String studentName;
  final String assignmentTitle;
  const SubmissionToShare({required this.url, this.fileName, required this.studentName, required this.assignmentTitle});
}

/// Teacher, during a live class: pick an assignment, then one student's uploaded file.
/// Returns null when closed without choosing.
Future<SubmissionToShare?> showShareSubmissionSheet(BuildContext context, {required String courseId}) {
  return showModalBottomSheet<SubmissionToShare>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF16181D),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => FractionallySizedBox(heightFactor: 0.75, child: _ShareSubmissionSheet(courseId: courseId)),
  );
}

class _ShareSubmissionSheet extends StatefulWidget {
  final String courseId;
  const _ShareSubmissionSheet({required this.courseId});

  @override
  State<_ShareSubmissionSheet> createState() => _ShareSubmissionSheetState();
}

class _ShareSubmissionSheetState extends State<_ShareSubmissionSheet> {
  Assignment? _assignment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final repo = ClassroomScope.of(context).assignments.repository;
    final assignment = _assignment;

    return SafeArea(
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 6),
          child: Row(children: [
            if (assignment != null)
              IconButton(
                key: const Key('share-sheet-back'),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _assignment = null),
              )
            else
              const SizedBox(width: 16),
            Expanded(
              child: Text(
                assignment == null ? l10n.meetShowWorkChooseAssignment : l10n.meetShowWorkChooseStudent,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: assignment == null
              ? StreamBuilder<List<Assignment>>(
                  stream: repo.watchAssignments(widget.courseId),
                  builder: (context, snap) {
                    final items = snap.data;
                    if (items == null) return const Center(child: CircularProgressIndicator(color: _gold));
                    if (items.isEmpty) return _empty(l10n.meetShowWorkNoAssignments);
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, i) => ListTile(
                        key: Key('share-assignment-${items[i].id}'),
                        leading: const Icon(Icons.assignment_outlined, color: _gold),
                        title: Text(items[i].title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                        onTap: () => setState(() => _assignment = items[i]),
                      ),
                    );
                  },
                )
              : StreamBuilder<List<Submission>>(
                  stream: repo.watchSubmissions(widget.courseId, assignment.id),
                  builder: (context, snap) {
                    final all = snap.data;
                    if (all == null) return const Center(child: CircularProgressIndicator(color: _gold));
                    final withFiles = all.where((s) => (s.fileUrl ?? '').isNotEmpty).toList();
                    if (withFiles.isEmpty) return _empty(l10n.meetShowWorkNoFiles);
                    return ListView.separated(
                      itemCount: withFiles.length,
                      separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, i) {
                        final s = withFiles[i];
                        final name = s.studentName.isNotEmpty ? s.studentName : 'Student';
                        return ListTile(
                          key: Key('share-submission-${s.studentId}'),
                          leading: ProfileAvatar(imageUrl: s.studentImage, radius: 20),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text(s.fileName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: const Icon(Icons.co_present, color: _gold),
                          onTap: () => Navigator.of(context).pop(SubmissionToShare(
                            url: s.fileUrl!,
                            fileName: s.fileName,
                            studentName: name,
                            assignmentTitle: assignment.title,
                          )),
                        );
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
        ),
      );
}
