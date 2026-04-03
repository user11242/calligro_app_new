// lib/features/community/widgets/post_image_carousel.dart
//Done
import 'package:flutter/material.dart';
// Import CachedNetworkImage
import '../../../core/theme/colors.dart'; // Adjust path as needed
import '../pages/image_viewer_page.dart';
import '../../../core/widgets/smart_image.dart';

class PostImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;

  const PostImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 250, // Default height for consistency
  });

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no images
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, imageIndex) {
              final imageUrl = widget.imageUrls[imageIndex];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerPage(
                        imageUrls: widget.imageUrls,
                        initialIndex: imageIndex,
                      ),
                    ),
                  );
                },
                child: SmartImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: widget.height,
                  placeholder: Container(
                    height: widget.height,
                    color: AppColors.primary.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    height: widget.height,
                    color: AppColors.primary.withOpacity(0.5),
                    child: const Icon(
                      Icons.error,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: 10.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.imageUrls.length,
                (index) => _buildDot(index),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: 8.0,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Colors.white
            : AppColors.textLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(5.0),
      ),
    );
  }
}
