import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../../../core/message/app_messenger.dart';
import '../data/services/admin_service.dart';

/// -------- MODEL --------
class TeacherModel {
  final String id;
  final String name;
  final String email;
  final String status;
  final String? photoUrl;
  final String? portfolio;
  final String? phone;

  TeacherModel({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    this.photoUrl,
    this.portfolio,
    this.phone,
  });

  factory TeacherModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherModel(
      id: doc.id,
      name: data["name"] ?? "",
      email: data["email"] ?? "",
      status: data["status"] ?? "pending",
      photoUrl: data["photoUrl"],
      portfolio: data["portfolio"],
      phone: data["phone"],
    );
  }
}

/// -------- TILE WIDGET --------
class TeacherTile extends StatelessWidget {
  final TeacherModel teacher;
  final FirebaseFirestore firestore;
  final AdminService _adminService = AdminService();

  TeacherTile({
    super.key,
    required this.teacher,
    required this.firestore,
  });

  Future<void> _openPortfolio() async {
    if (teacher.portfolio == null || teacher.portfolio!.isEmpty) return;
    
    // Auto-fix missing protocol
    String url = teacher.portfolio!;
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: teacher.photoUrl != null && teacher.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: teacher.photoUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                      )
                    : _buildAvatarPlaceholder(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      teacher.email,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    ),
                    if (teacher.phone != null && teacher.phone!.isNotEmpty)
                      Text(
                        teacher.phone!,
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Portfolio Section
          if (teacher.portfolio != null && teacher.portfolio!.isNotEmpty) ...[
            Text(
              AppLocalizations.of(context)!.portfolioLinks,
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _openPortfolio,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        teacher.portfolio!,
                        style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _confirmAction(context, "reject"),
                  child: Text(AppLocalizations.of(context)!.rejectTeacher, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _confirmAction(context, "approve"),
                  child: Text(AppLocalizations.of(context)!.approveTeacher, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.amber.withOpacity(0.1),
      child: const Icon(Icons.assignment_ind, color: Colors.amber, size: 28),
    );
  }

  void _confirmAction(BuildContext context, String action) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        title: Row(
          children: [
            Icon(
              action == "approve" ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: action == "approve" ? Colors.blueAccent : Colors.redAccent,
            ),
            const SizedBox(width: 12),
            Text(
              action == "approve" ? l10n.approveTeacherConfirmTitle : l10n.rejectTeacherConfirmTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          action == "approve"
              ? l10n.approveTeacherConfirmMessage(teacher.name.isNotEmpty ? teacher.name : l10n.unknown)
              : l10n.rejectTeacherConfirmMessage(teacher.name.isNotEmpty ? teacher.name : l10n.unknown),
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: action == "approve" ? Colors.blueAccent : Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    action == "approve" ? l10n.approve : l10n.rejectTeacher,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog first

                    try {
                      if (action == "approve") {
                        await firestore.collection("users").doc(teacher.id).update({
                          "status": "approved",
                        });
                      } else {
                        // Use AdminService to perform full cleanup
                        await _adminService.rejectTeacher(teacher.id);
                      }

                      if (context.mounted) {
                        AppMessenger.showSnackBar(
                          context,
                          title: action == "approve" ? l10n.approved : l10n.rejected,
                          message: action == "approve" ? l10n.teacherApprovedMessage : l10n.teacherRejectedMessage,
                          type: action == "approve" ? MessengerType.success : MessengerType.info,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppMessenger.showSnackBar(
                          context,
                          title: l10n.error,
                          message: e.toString(),
                          type: MessengerType.error,
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// -------- PAGE --------
class AdminPendingTeachersPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdminPendingTeachersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(l10n.pendingTeachers, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("users")
            .where("role", isEqualTo: "teacher")
            .where("status", isEqualTo: "pending")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          final teachers = snapshot.data!.docs
              .map((doc) => TeacherModel.fromDoc(doc))
              .toList();

          if (teachers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg_rounded, size: 64, color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noPendingTeachersFound,
                    style: const TextStyle(color: Colors.white24),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: teachers.length,
            itemBuilder: (context, index) => TeacherTile(
              teacher: teachers[index],
              firestore: _firestore,
            ),
          );
        },
      ),
    );
  }
}
