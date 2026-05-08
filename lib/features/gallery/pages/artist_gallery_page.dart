import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../models/gallery_artist.dart';
import '../models/gallery_artwork.dart';
import '../services/gallery_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../widgets/artwork_viewer.dart';
import '../widgets/gallery_image.dart';

class ArtistGalleryPage extends StatefulWidget {
  final GalleryArtist artist;

  const ArtistGalleryPage({super.key, required this.artist});

  @override
  State<ArtistGalleryPage> createState() => _ArtistGalleryPageState();
}

class _ArtistGalleryPageState extends State<ArtistGalleryPage> {
  final GalleryService _galleryService = GalleryService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: CustomScrollView(
        slivers: [
          // 1. Sleek AppBar
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.artist.localizedName(context),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),

          // 2. Artist Info Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.artist.bio.isNotEmpty) ...[
                    Text(
                      widget.artist.bio,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: [
                      _buildStatChip(Icons.collections, l10n.gallery),
                      const SizedBox(width: 12),
                      _buildStatChip(Icons.verified, l10n.certifiedArtist),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Grid of Artworks
          StreamBuilder<List<GalleryArtwork>>(
            stream: _galleryService.getArtworksStream(widget.artist.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "Error: ${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
                );
              }

              final artworks = snapshot.data ?? [];

              if (artworks.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      l10n.nothingToShow,
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childCount: artworks.length,
                  itemBuilder: (context, index) {
                    final artwork = artworks[index];
                    return _buildArtworkCard(artwork);
                  },
                ),
              );
            },
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentGold, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.accentGold, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkCard(GalleryArtwork artwork) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtworkViewer(
              artwork: artwork,
            ),
          ),
        );
      },
      child: GalleryImage(
        imageUrl: artwork.thumbnailUrl,
        heroTag: 'artwork_${artwork.id}',
        placeholder: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          height: 150, // Temporary height for masonry grid measure
          child: const Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2)),
        ),
      ),
    );
  }
}
