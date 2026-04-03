import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../widgets/post_card.dart';
import '../services/community_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class ProfilePostsPage extends StatefulWidget {
  final String title;
  final String currentUserId;
  final Stream<QuerySnapshot> postsStream;
  final List<String> savedPostIds;
  final Function(String postId, bool isSaved) onToggleSave;

  const ProfilePostsPage({
    super.key,
    required this.title,
    required this.currentUserId,
    required this.postsStream,
    required this.savedPostIds,
    required this.onToggleSave,
  });

  @override
  State<ProfilePostsPage> createState() => _ProfilePostsPageState();
}

class _ProfilePostsPageState extends State<ProfilePostsPage> {
  final CommunityService _communityService = CommunityService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
          }
          if (snapshot.hasError) {
            return Center(child: Text(AppLocalizations.of(context)!.errorLoadingPosts, style: const TextStyle(color: Colors.white54)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_view, size: 60, color: Colors.white10),
                  const SizedBox(height: 10),
                  Text(AppLocalizations.of(context)!.nothingToShow, style: const TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postData = posts[index].data() as Map<String, dynamic>;
              final postId = posts[index].id;
              final postUserId = postData['userId'] ?? '';

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(postUserId).snapshots(),
                builder: (context, userSnapshot) {
                   String displayUserName = postData['userName'] ?? 'Anonymous';
                   String displayUserImage = postData['userImageUrl'] ?? '';
                   String displayUserRole = postData['userRole'] ?? 'student';

                   if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                     final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                     displayUserName = userData['name'] ?? displayUserName;
                     displayUserImage = userData['photoUrl'] ?? displayUserImage;
                     displayUserRole = userData['role'] ?? displayUserRole;
                   }

                   return PostCard(
                    postId: postId,
                    userId: postUserId,
                    currentLoggedInUserId: widget.currentUserId,
                    isGuest: widget.currentUserId.isEmpty,
                    userName: displayUserName,
                    userImageUrl: displayUserImage,
                    userRole: displayUserRole,
                    caption: postData['caption'] ?? '',
                    imageUrls: List<String>.from(postData['imageUrls'] ?? []),
                    timestamp: postData['timestamp'] as Timestamp?,
                    onProfileTap: (uid, role) {
                        // In this full page view, we might navigate to other public profiles
                    },
                    likesCount: postData['likesCount'] ?? 0,
                    likes: Map<String, dynamic>.from(postData['likes'] ?? {}),
                    commentsCount: postData['commentsCount'] ?? 0,
                    isSaved: widget.savedPostIds.contains(postId),
                    isEdited: postData['isEdited'] ?? false,
                    onToggleSave: () => widget.onToggleSave(postId, widget.savedPostIds.contains(postId)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
