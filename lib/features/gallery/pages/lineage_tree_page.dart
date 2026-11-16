import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:ui';

class LineageTreePage extends StatelessWidget {
  const LineageTreePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // 1. Zoomable Image Container
          Positioned.fill(
            child: PhotoView(
              imageProvider: const AssetImage('assets/images/18973_calligro_strong_watermark.png'),
              backgroundDecoration: const BoxDecoration(color: AppColors.primary),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4.1,
              initialScale: PhotoViewComputedScale.contained,
              enableRotation: false,
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      "Failed to load the lineage tree",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Translucent "Back" button overlay
          Positioned(
            top: 60,
            left: 24,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
