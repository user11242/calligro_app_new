import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../widgets/post_card.dart';
import '../pages/profile_posts_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

class ProfilePostsSection extends StatelessWidget {
  final String title;
  final String currentUserId;
  final Stream<QuerySnapshot> postsStream;
  final List<String> savedPostIds;
  final Function(String postId, bool isSaved) onToggleSave;

  const ProfilePostsSection({
    super.key,
    required this.title,
    required this.currentUserId,
    required this.postsStream,
    required this.savedPostIds,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(color: AppColors.accentGold),
          ));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                children: [
                  const Icon(Icons.grid_view, size: 40, color: Colors.white10),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.nothingToShow,
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
          );
        }

        final allPosts = snapshot.data!.docs;
        // Limit to 3 posts for the preview
        final previewPosts = allPosts.take(3).toList();

        return Column(
          children: [
            const SizedBox(height: 32),
            ...previewPosts.map((doc) {
              final postData = doc.data() as Map<String, dynamic>;
              final postId = doc.id;
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

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: PostCard(
                      postId: postId,
                      userId: postUserId,
                      currentLoggedInUserId: currentUserId,
                      isGuest: currentUserId.isEmpty,
                      userName: displayUserName,
                      userImageUrl: displayUserImage,
                      userRole: displayUserRole,
                      caption: postData['caption'] ?? '',
                      imageUrls: List<String>.from(postData['imageUrls'] ?? []),
                      timestamp: postData['timestamp'] as Timestamp?,
                      onProfileTap: (uid, role) {},
                      likesCount: postData['likesCount'] ?? 0,
                      likes: Map<String, dynamic>.from(postData['likes'] ?? {}),
                      commentsCount: postData['commentsCount'] ?? 0,
                      isSaved: savedPostIds.contains(postId),
                      isEdited: postData['isEdited'] ?? false,
                      onToggleSave: () => onToggleSave(postId, savedPostIds.contains(postId)),
                    ),
                  );
                },
              );
            }),
            
            if (allPosts.length > 3)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePostsPage(
                          title: title,
                          currentUserId: currentUserId,
                          postsStream: postsStream,
                          savedPostIds: savedPostIds,
                          onToggleSave: onToggleSave,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.seeAll,
                        style: const TextStyle(
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.accentGold),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
