import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class CommunityPostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String currentUserId;

  const CommunityPostCard({
    super.key,
    required this.postId,
    required this.postData,
    required this.currentUserId,
  });

  // --- MOCK DATA FOR DEMONSTRATION ---
  // These variables will be replaced with real data fetching/logic later.
  final bool isTeacher = true; 
  final bool isFollowing = false;
  final bool isLiked = false; 
  final int likeCount = 120; 
  final String caption = "Reflecting on the balance of chaos and order. What feelings does this piece evoke in you?";
  final String username = "Master_Inkwell";
  final String profilePicUrl = "https://placehold.co/100x100/362B0D/F0E68C?text=P"; // Placeholder
  // ------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Post Header (Profile, Username, Role, Follow Button)
          _buildPostHeader(),
          
          // 2. Post Image (Placeholder for now)
          _buildPostImage(context),

          // 3. Action Bar (Like, Comment, Save)
          _buildActionBar(context),

          // 4. Likes Count
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 4.0),
            child: Text(
              '$likeCount likes',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          
          // 5. Caption
          _buildCaption(),

          // 6. View Comments and Timestamp
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
              'View all 32 comments', // Mock data
              style: TextStyle(color: AppColors.secondary.withOpacity(0.6), fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12.0, bottom: 12.0),
            child: Text(
              '1 hour ago', // Mock data
              style: TextStyle(color: AppColors.secondary.withOpacity(0.4), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Row(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.textColor.withOpacity(0.3),
            backgroundImage: NetworkImage(profilePicUrl),
          ),
          const SizedBox(width: 10),
          
          // Username and Role Indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (isTeacher)
                const Text(
                  'Teacher',
                  style: TextStyle(
                    color: AppColors.textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const Spacer(),
          
          // Follow Button (Conditional)
          if (!isFollowing)
            Container(
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.textColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () {
                  // TODO: Implement follow logic
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          
          // More Options Button
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.secondary),
            onPressed: () {
              // TODO: Implement options menu
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostImage(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.45,
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: AppColors.primary,
        border: Border(
          top: BorderSide(color: AppColors.textColor.withOpacity(0.2), width: 0.5),
          bottom: BorderSide(color: AppColors.textColor.withOpacity(0.2), width: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          // Use the post title from Firestore data if available, otherwise use placeholder
          postData['title'] ?? 'Generated Calligraphy Art',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textColor,
            fontSize: 24,
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
          ),
        ),
        // Future: Replace the Text widget with Image.network(postData['imageUrl'])
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          // Like Button
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red.shade400 : AppColors.primary,
              size: 28,
            ),
            onPressed: () {
              // TODO: Implement like/unlike logic
            },
          ),

          // Comment Button
          IconButton(
            icon: const Icon(
              Icons.comment_outlined,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () {
              // TODO: Implement navigation to the comment page
            },
          ),
          
          const Spacer(),

          // Save Button
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () {
              // TODO: Implement save logic
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.primary),
          children: [
            TextSpan(
              text: username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: caption,
            ),
          ],
        ),
      ),
    );
  }
}
