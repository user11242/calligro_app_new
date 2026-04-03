import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../gallery/models/gallery_artist.dart';
import '../../gallery/services/gallery_service.dart';
import '../../gallery/pages/artist_bio_page.dart';
import '../../gallery/pages/artist_gallery_page.dart';
import 'lineage_tree_page.dart';
import 'dart:ui';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final GalleryService _galleryService = GalleryService();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: CustomScrollView(
        slivers: [
          // 1. App Bar with Gold Accent
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.masterclassGallery,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, AppColors.primary],
                  ),
                ),
              ),
            ),
          ),

          // 2. Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          icon: const Icon(Icons.search, color: AppColors.accentGold, size: 24),
                          hintText: l10n.searchMasters,
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Lineage Tree Promo Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: _buildLineagePromoBanner(context),
            ),
          ),

          // 4. Artist List
          StreamBuilder<List<GalleryArtist>>(
            stream: _galleryService.getArtistsStream(),
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

              final artists = snapshot.data ?? [];
              final filteredArtists = artists.where((artist) {
                return artist.name.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList();

              if (filteredArtists.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.brush_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text(
                          "No results found",
                          style: TextStyle(color: Colors.white.withOpacity(0.3)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final artist = filteredArtists[index];
                      return _buildArtistCard(artist, index);
                    },
                    childCount: filteredArtists.length,
                  ),
                ),
              );
            },
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildLineagePromoBanner(BuildContext context) {
    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LineageTreePage()),
        );
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentGold.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full-Bleed Background Image (The Tree)
              Image.asset(
                'assets/images/18973_calligro_strong_watermark.png',
                fit: BoxFit.cover,
                width: double.infinity,
                alignment: Alignment.topCenter,
                errorBuilder: (c, o, s) => Container(color: Colors.black26),
              ),
              
              // 2. Artistic Gradient Overlay (Darker at the start for typography)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.95),
                      AppColors.primary.withOpacity(0.6),
                      Colors.transparent,
                    ],
                    begin: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    end: isArabic ? Alignment.centerLeft : Alignment.centerRight,
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              
              // 3. Optional Glass Shimmer on the left/right
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),

              // 4. Content Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isArabic ? "شجرة الخطاطين" : "Lineage Tree",
                            style: GoogleFonts.amiri(
                              color: AppColors.accentGold,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isArabic 
                                ? "استكشف أسانيد وأشجار الخطاطين" 
                                : "Explore the lineage of master calligraphers",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // High-end circular icon
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGold.withOpacity(0.1),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.hub_rounded, color: AppColors.accentGold, size: 30),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistCard(GalleryArtist artist, int index) {
    // Generate a beautiful placeholder using index for variety if needed
    final bool hasImage = artist.photoUrl != null && artist.photoUrl!.isNotEmpty;
    final bool isSpecialPlaceholder = artist.id == "artist_ali_ghalib" || artist.id == "artist_abbas_albaghdadi";
    
    String? localAssetPath;
    if (artist.name.contains("حسن") && artist.name.contains("رضا") || 
        artist.name.contains("Hasan") && artist.name.contains("Riza") ||
        artist.name.contains("Rizâ")) {
      localAssetPath = "assets/images/artists/hasan_rida.jpg";
    } else if (artist.name.contains("كامل") && artist.name.contains("أحمد") || 
               artist.name.contains("Ahmad") && artist.name.contains("Kamel") ||
               artist.name.contains("Akdik")) {
      localAssetPath = "assets/images/artists/ahmad_kamel.png";
    } else if (artist.name.contains("مصطفى") && artist.name.contains("عزت") || 
               artist.name.contains("مصطفى") && artist.name.contains("عزّت") ||
               artist.name.contains("Mustafa") && artist.name.contains("Izzat") ||
               artist.name.contains("İzzet")) {
      localAssetPath = "assets/images/artists/mustafazzat.webp";
    }
    
    final bool useLocalAsset = !hasImage && localAssetPath != null;

    final String name = artist.name;
    final bool isOttoman = name.contains("خرائط") || name.contains("وثائق") || name.contains("عثمانيه") || name.contains("Ottoman");
    final bool isRiqaa = name.contains("الرقاع") || name.contains("رقاع") || name.contains("Riqaa");
    final bool isDiwani = name.contains("ديواني") || name.contains("Diwani");
    final bool isMisc = name.contains("منوعات") || name.contains("Varieties");

    final bool shouldBypass = isOttoman || isRiqaa || isDiwani || isMisc;

    return GestureDetector(
      onTap: () {
        if (shouldBypass) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistGalleryPage(artist: artist),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistBioPage(artist: artist),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            constraints: const BoxConstraints(minHeight: 145),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withOpacity(0.03),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
        child: Stack(
          children: [
            // 1. Background Image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: hasImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          // Blurred background fill
                          CachedNetworkImage(
                            imageUrl: artist.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.cardBackground),
                            errorWidget: (context, url, error) => Container(color: AppColors.cardBackground),
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(color: Colors.black.withOpacity(0.15)),
                          ),
                          // Focused full-face image
                          CachedNetworkImage(
                            imageUrl: artist.photoUrl!,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            placeholder: (context, url) => const SizedBox.shrink(),
                            errorWidget: (context, url, error) => const SizedBox.shrink(),
                          ),
                        ],
                      )
                    : (useLocalAsset
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              // Blurred background fill
                              Image.asset(localAssetPath, fit: BoxFit.cover),
                              BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(color: Colors.black.withOpacity(0.15)),
                              ),
                              // Focused full-face image
                              Image.asset(
                                localAssetPath,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                              ),
                            ],
                          )
                        : (isSpecialPlaceholder
                            ? Image.asset(
                                'assets/images/gallery_placeholder_${artist.id.contains("ali") ? "1" : "2"}.jpg',
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: AppColors.accentGold.withOpacity(0.05),
                                child: Center(
                                  child: Icon(Icons.brush, color: AppColors.accentGold.withOpacity(0.2), size: 40),
                                ),
                              ))),
              ),
            ),

            // 2. Gradient Overlay for Text Readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (artist.bio.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            artist.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.viewWorks,
                              style: const TextStyle(
                                color: AppColors.accentGold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, color: AppColors.accentGold, size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // Spacing for the image side
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}
