import 'package:flutter/material.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/core/utils/date_utils.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class AdminCommunityMgmt extends StatefulWidget {
  const AdminCommunityMgmt({super.key});

  @override
  State<AdminCommunityMgmt> createState() => _AdminCommunityMgmtState();
}

class _AdminCommunityMgmtState extends State<AdminCommunityMgmt> {
  final AdminService _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l10n.communityModeration, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService.getAllPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text(l10n.noPostsFound, style: TextStyle(color: Colors.white.withOpacity(0.4))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildPostItem(post);
            },
          );
        },
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    final DateTime date = CalligroDateUtils.toDateTime(post['createdAt']) ?? DateTime.now();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.amber.withOpacity(0.1),
                backgroundImage: post['userProfilePic'] != null ? CachedNetworkImageProvider(post['userProfilePic']) : null,
                child: post['userProfilePic'] == null ? const Icon(Icons.person, size: 18, color: Colors.amber) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['userName'] ?? "User",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(date),
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _confirmDelete(post['id']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post['content'] ?? "",
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          if (post['postImage'] != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: post['postImage'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.white.withOpacity(0.05)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(String postId) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.deletePostConfirmTitle, style: const TextStyle(color: Colors.white)),
        content: Text(l10n.deletePostConfirmMessage, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(l10n.delete, style: const TextStyle(color: Colors.redAccent)),
            onPressed: () async {
              await _adminService.deletePost(postId);
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
