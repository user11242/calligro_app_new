import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Shows an enlarged profile image with a blur effect and Hero animation.
void showProfileImageDialog(BuildContext context, String imageUrl, String heroTag) {
  if (imageUrl.isEmpty) return;

  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      pageBuilder: (BuildContext context, _, __) {
        return Stack(
          children: [
            // 1. Blur Effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.transparent, 
              ),
            ),
            
            // 2. Dismissible Area (Tap anywhere to close)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // 3. Central Image with Hero Animation
            Center(
              child: Hero(
                tag: heroTag,
                child: Container(
                  width: 300, // Fixed size or use MediaQuery like 80% screen width
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                         color: Colors.grey[900],
                         child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.person, size: 100, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    ),
  );
}
