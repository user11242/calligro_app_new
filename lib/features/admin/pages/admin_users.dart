import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:calligro_app/core/utils/date_utils.dart';
import '../data/services/admin_service.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? photoUrl;
  final DateTime? createdAt;
  final String? phone;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    this.createdAt,
    this.phone,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data["name"] ?? "No Name",
      email: data["email"] ?? "No Email",
      role: data["role"] ?? "student",
      photoUrl: data["photoUrl"],
      createdAt: CalligroDateUtils.toDateTime(data["createdAt"]),
      phone: data["phone"],
    );
  }
}

class UserTile extends StatelessWidget {
  final UserModel user;
  final AdminService adminService;
  const UserTile({super.key, required this.user, required this.adminService});

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    // Remove non-numeric characters for WhatsApp link
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse("https://wa.me/$cleanPhone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showNotificationDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.sendToUser(user.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.notificationTitle,
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.notificationBody,
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              if (titleController.text.isNotEmpty && bodyController.text.isNotEmpty) {
                await adminService.sendUserNotification(user.id, titleController.text, bodyController.text);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.notificationSent)));
                }
              }
            },
            child: Text(l10n.send, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUserActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                if (user.phone != null && user.phone!.isNotEmpty) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.phone_outlined, color: Colors.blue, size: 20),
                    ),
                    title: Text(l10n.callUser, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      _makeCall(user.phone!);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.chat_bubble_outline, color: Colors.green, size: 20),
                    ),
                    title: Text(l10n.whatsappMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      _openWhatsApp(user.phone!);
                    },
                  ),
                ],
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.notifications_none_rounded, color: Colors.amber, size: 20),
                  ),
                  title: Text(l10n.sendDirectNotification, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _showNotificationDialog(context);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(color: Colors.white10),
                ),
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Colors.blue),
                  title: Text(l10n.makeAdmin, style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    await adminService.changeUserRole(user.id, 'admin');
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_ind, color: Colors.green),
                  title: Text(l10n.makeTeacher, style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    await adminService.changeUserRole(user.id, 'teacher');
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.grey),
                  title: Text(l10n.makeStudent, style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    await adminService.changeUserRole(user.id, 'student');
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(color: Colors.white10),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text(l10n.deleteUser, style: const TextStyle(color: Colors.redAccent)),
                  onTap: () => _confirmDelete(context),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Navigator.pop(context); // Close bottom sheet
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.deleteUserConfirmTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(l10n.deleteUserConfirmMessage(user.name), 
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(l10n.delete, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await adminService.deleteUser(user.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Hero(
                  tag: 'user-${user.id}',
                  child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: user.photoUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.white.withOpacity(0.05),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.blueAccent.withOpacity(0.1),
                            child: const Icon(Icons.person, color: Colors.blueAccent),
                          ),
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          color: Colors.blueAccent.withOpacity(0.1),
                          child: const Icon(Icons.person, color: Colors.blueAccent),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (user.role == 'admin' ? Colors.blue : (user.role == 'teacher' ? Colors.green : Colors.grey)).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (user.role == 'admin' ? Colors.blue : (user.role == 'teacher' ? Colors.green : Colors.grey)).withOpacity(0.2)),
                ),
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    String roleLabel = l10n.studentRole;
                    if (user.role == 'admin') roleLabel = l10n.adminRole;
                    if (user.role == 'teacher') roleLabel = l10n.teacherRole;
                    
                    return Text(
                      roleLabel.toUpperCase(),
                      style: TextStyle(
                        color: user.role == 'admin' ? Colors.blue : (user.role == 'teacher' ? Colors.green : Colors.white60),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    );
                  }
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
                onPressed: () => _showUserActions(context),
              ),
            ],
          ),
          if (user.createdAt != null || user.phone != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (user.createdAt != null)
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: Colors.amber.withOpacity(0.5)),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.joinedDate(DateFormat.yMMM(Localizations.localeOf(context).toString()).format(user.createdAt!)),
                        style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
                      ),
                    ],
                  ),
                if (user.phone != null && user.phone!.isNotEmpty)
                  GestureDetector(
                    onTap: () => _makeCall(user.phone!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_enabled_rounded, size: 10, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            user.phone!,
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(l10n.userManagement, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: l10n.searchHintUsers,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.amber, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection("users").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }

                final users = snapshot.data!.docs
                    .map((doc) => UserModel.fromDoc(doc))
                    .where((u) {
                      final nameMatch = u.name.toLowerCase().contains(_searchQuery);
                      final emailMatch = u.email.toLowerCase().contains(_searchQuery);
                      final roleMatch = u.role.toLowerCase().contains(_searchQuery);
                      return nameMatch || emailMatch || roleMatch;
                    })
                    .toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, size: 64, color: Colors.white.withOpacity(0.05)),
                        const SizedBox(height: 16),
                        Text(l10n.noUsersFound, style: TextStyle(color: Colors.white.withOpacity(0.2))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) => UserTile(
                    user: users[index],
                    adminService: _adminService,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
