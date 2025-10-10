import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/colors.dart';
import 'package:calligro_app/features/community/community_post_card.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    if (userId == null) {
      // Handle unauthenticated state (e.g., show a login prompt)
      return const Center(
        child: Text("Please log in to view the community.", style: TextStyle(color: Colors.white)),
      );
    }

    return Scaffold(
      // Set the main background color to AppColors.primary
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text(
          "Calligro Community",
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textColor),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      
      body: StreamBuilder<QuerySnapshot>(
        // Fetches posts ordered by timestamp, latest first
        stream: FirebaseFirestore.instance
            .collection('community_posts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.textColor),
            );
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "Be the first to share a masterpiece!",
                style: TextStyle(color: AppColors.secondary.withOpacity(0.6), fontSize: 16),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            itemBuilder: (context, index) {
              final postData = posts[index].data() as Map<String, dynamic>;
              final postId = posts[index].id;
              
              // Renders each post using the CommunityPostCard widget
              return CommunityPostCard(
                postId: postId,
                postData: postData,
                currentUserId: userId,
              );
            },
          );
        },
      ),

      // Floating Action Button for creating new posts
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to a Post Creation screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Post creation screen coming soon!")),
          );
        },
        backgroundColor: AppColors.textColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppColors.primary),
      ),
    );
  }
}