import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class StudentSubmissionsPage extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String assignmentTitle;

  const StudentSubmissionsPage({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<StudentSubmissionsPage> createState() => _StudentSubmissionsPageState();
}

class _StudentSubmissionsPageState extends State<StudentSubmissionsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)!.submissions, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Text(widget.assignmentTitle, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('submissions')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 60, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.noSubmissionsYet, style: const TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _SubmissionCard(data: data)
                  .animate().fadeIn(duration: 400.ms, delay: (index * 100).ms).slideY(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }
}


class _SubmissionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _SubmissionCard({required this.data});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final timeStr = submittedAt != null
        ? DateFormat('MMM d, h:mm a', Localizations.localeOf(context).toString()).format(submittedAt)
        : '';
    final String? photoUrl = data['studentImage'] as String?;
    final String studentName = data['studentName'] ?? 'Unknown Student';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
            leading: _buildAvatar(photoUrl, studentName),
            title: Text(studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            subtitle: Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.accentGold,
                  size: 20,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    if (data['note'] != null && data['note'].toString().isNotEmpty) ...[
                      Text(AppLocalizations.of(context)!.studentNote,
                          style: const TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(data['note'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 16),
                    ],
                    if (data['fileUrl'] != null)
                      _buildFileAction(data['fileUrl'], data['fileName'] ?? 'submission_file'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.accentGold.withOpacity(0.15),
      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold, fontSize: 18))
          : null,
    );
  }

  Widget _buildFileAction(String url, String name) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined, color: AppColors.accentGold, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}
