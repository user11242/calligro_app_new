import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';
import '../models/gallery_artwork.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:calligro_app/core/services/security_service.dart';

class ArtworkViewer extends StatefulWidget {
  final GalleryArtwork artwork;

  const ArtworkViewer({super.key, required this.artwork});

  @override
  State<ArtworkViewer> createState() => _ArtworkViewerState();
}

class _ArtworkViewerState extends State<ArtworkViewer> {
  // Shared cache with GalleryImage
  static final Map<String, String> _resolvedCache = {};

  String? _resolvedUrl;
  bool _isLoading = true;
  bool _hasAttemptedResolution = false;

  @override
  void initState() {
    super.initState();
    SecurityService().enableScreenshotProtection();
    _initUrl();
  }

  @override
  void dispose() {
    SecurityService().disableScreenshotProtection();
    super.dispose();
  }

  void _initUrl() {
    // 1. FAST PATH: Cache check
    if (_resolvedCache.containsKey(widget.artwork.highResUrl)) {
      _resolvedUrl = _resolvedCache[widget.artwork.highResUrl];
      _isLoading = false;
      return;
    }

    // 2. FAST PATH: Direct load (Public Rules)
    _resolvedUrl = widget.artwork.highResUrl;
    _isLoading = false;

    // 3. Resolve token in background if missing
    if (!widget.artwork.highResUrl.contains('token=')) {
      _resolveUrlInBackground();
    }
  }

  Future<void> _resolveUrlInBackground() async {
    if (_hasAttemptedResolution) return;

    try {
      String cleanUrl = widget.artwork.highResUrl;
      if (cleanUrl.contains('?')) {
        cleanUrl = cleanUrl.split('?').first;
      }

      final ref = FirebaseStorage.instance.refFromURL(cleanUrl);
      final url = await ref.getDownloadURL();
      
      _resolvedCache[widget.artwork.highResUrl] = url;
      
      if (mounted) {
        setState(() {
          _resolvedUrl = url;
          _hasAttemptedResolution = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasAttemptedResolution = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
            ),
            onPressed: () {
               _showInfo(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Hero(
            tag: 'artwork_${widget.artwork.id}',
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(_resolvedUrl!),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              loadingBuilder: (context, event) => Center(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const CircularProgressIndicator(color: AppColors.accentGold),
                     const SizedBox(height: 16),
                     Text(
                       l10n.downloadingHighRes,
                       style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                     ),
                   ],
                 ),
              ),
              errorBuilder: (context, error, stackTrace) {
                if (!_hasAttemptedResolution) {
                  _resolveUrlInBackground();
                }
                return const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 64),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.artworkDetails,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (widget.artwork.title.isNotEmpty) ...[
              Text(
                widget.artwork.title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              l10n.artworkViewerDescription,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
             SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accentGold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.close, style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
