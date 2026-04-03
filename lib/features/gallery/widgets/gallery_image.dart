import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';

class GalleryImage extends StatefulWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? placeholder;
  final String heroTag;

  const GalleryImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.placeholder,
    required this.heroTag,
  });

  @override
  State<GalleryImage> createState() => _GalleryImageState();
}

class _GalleryImageState extends State<GalleryImage> {
  // Session-wide cache to avoid redundant network calls
  static final Map<String, String> _resolvedCache = {};
  
  String? _resolvedUrl;
  bool _hasAttemptedResolution = false;

  @override
  void initState() {
    super.initState();
    _initUrl();
  }

  void _initUrl() {
    // 1. FAST PATH: If already in cache, use it instantly
    if (_resolvedCache.containsKey(widget.imageUrl)) {
      _resolvedUrl = _resolvedCache[widget.imageUrl];
      return;
    }

    // 2. FAST PATH: Since rules are now public, the raw URL should work.
    // We set it immediately so the image starts downloading without waiting for SDK resolution.
    _resolvedUrl = widget.imageUrl;
    
    // 3. Optional: Background resolution if it doesn't have a token
    if (!widget.imageUrl.contains('token=')) {
      _resolveUrlInBackground();
    }
  }

  @override
  void didUpdateWidget(GalleryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _initUrl();
    }
  }

  Future<void> _resolveUrlInBackground() async {
    if (_hasAttemptedResolution) return;

    try {
      // Clean URL for refFromURL
      String cleanUrl = widget.imageUrl;
      if (cleanUrl.contains('?')) {
        cleanUrl = cleanUrl.split('?').first;
      }

      final ref = FirebaseStorage.instance.refFromURL(cleanUrl);
      final url = await ref.getDownloadURL();
      
      _resolvedCache[widget.imageUrl] = url;
      
      if (mounted) {
        setState(() {
          _resolvedUrl = url;
          _hasAttemptedResolution = true;
        });
      }
    } catch (e) {
      // If resolution fails, we keep the original URL (it might still work if public)
      if (mounted) {
        setState(() => _hasAttemptedResolution = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: We always have a _resolvedUrl now due to _initUrl()
    return Hero(
      tag: widget.heroTag,
      child: SmartImage(
        imageUrl: _resolvedUrl!,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        placeholder: widget.placeholder ?? _defaultPlaceholder(),
        errorWidget: _defaultErrorWidget(),
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: AppColors.cardBackground,
      height: widget.height ?? 200,
      width: widget.width,
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white24,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(
      color: AppColors.cardBackground,
      height: widget.height ?? 200,
      width: widget.width,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white24),
      ),
    );
  }
}
