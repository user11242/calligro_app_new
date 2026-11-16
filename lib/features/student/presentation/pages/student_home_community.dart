part of 'student_home_page.dart';

/// Split out of student_home_page.dart (unchanged code).
extension _CommunitySections on _StudentHomePageState {
  Widget _buildGallerySection() {
    return SizedBox(
      height: 220,
      child: FutureBuilder<List<GalleryArtist>>(
        future: _galleryFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading gallery",
                style: TextStyle(
                  color: Colors.redAccent.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }

          final artists = snapshot.data ?? [];
          final artistsWithPhoto = artists
              .where(
                (a) =>
                    (a.photoUrl != null && a.photoUrl!.isNotEmpty) ||
                    a.id == "artist_ali_ghalib" ||
                    a.id == "artist_abbas_albaghdadi",
              )
              .toList();

          if (artistsWithPhoto.isEmpty) {
            return Center(
              child: Text(
                "Coming Soon",
                style: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: artistsWithPhoto.length > 5
                ? 5
                : artistsWithPhoto.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final artist = artistsWithPhoto[index];
              return GestureDetector(
                onTap: () {
                  if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
                    final String name = artist.name;
                    final bool isOttoman =
                        name.contains("خرائط") ||
                        name.contains("وثائق") ||
                        name.contains("عثمانيه") ||
                        name.contains("Ottoman");
                    final bool isRiqaa =
                        name.contains("الرقاع") ||
                        name.contains("رقاع") ||
                        name.contains("Riqaa");
                    final bool isDiwani =
                        name.contains("ديواني") || name.contains("Diwani");
                    final bool isMisc =
                        name.contains("منوعات") || name.contains("Varieties");

                    if (isOttoman || isRiqaa || isDiwani || isMisc) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ArtistGalleryPage(artist: artist),
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
                  }
                },
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (artist.photoUrl != null &&
                          artist.photoUrl!.isNotEmpty)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Blurred background fill
                                CachedNetworkImage(
                                  imageUrl: artist.photoUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.accentGold,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                ),
                                Container(
                                  color: Colors.black.withOpacity(0.6),
                                ),
                                // Focused full-face image
                                CachedNetworkImage(
                                  imageUrl: artist.photoUrl!,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  placeholder: (context, url) =>
                                      const SizedBox.shrink(),
                                  errorWidget: (context, url, error) =>
                                      const SizedBox.shrink(),
                                ),
                                // Dark wash over everything to ensure text pops and looks sleek
                                Container(
                                  color: Colors.black.withOpacity(0.25),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (artist.id == "artist_ali_ghalib" ||
                          artist.id == "artist_abbas_albaghdadi")
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/gallery_placeholder_${artist.id.contains("ali") ? "1" : "2"}.jpg',
                              fit: BoxFit.cover,
                              color: Colors.black.withOpacity(0.3),
                              colorBlendMode: BlendMode.darken,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artist.localizedName(context),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTeachersSection() {
    return SizedBox(
      height: 240,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _teachersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                "No teachers found",
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            );
          }
          final teachers = snapshot.data!;
          final teachersWithPhoto = teachers
              .where(
                (t) =>
                    t['photoUrl'] != null &&
                    t['photoUrl'].toString().trim().isNotEmpty,
              )
              .toList();

          if (teachersWithPhoto.isEmpty) {
            return Center(
              child: Text(
                "No teachers found",
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: teachersWithPhoto.length > 3
                ? 3
                : teachersWithPhoto.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) =>
                _buildTeacherCard(teachersWithPhoto[index]),
          );
        },
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    return GestureDetector(
      onTap: () {
        if (GuestGuard.check(context, isGuest: widget.isGuestMode)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PublicProfilePage(userId: teacher['id'] ?? ''),
            ),
          );
        }
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProfileAvatar(
              radius: 35,
              imageUrl: teacher['photoUrl']?.toString() ?? '',
            ),
            const SizedBox(height: 12),
            Text(
              (teacher['name']?.toString() ?? 'Artist').localizedName(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            RatingDisplay(
              averageRating: RatingUtils.calculateAverageRating(
                teacher['totalStars'] ?? 0,
                teacher['reviewCount'] ?? 0,
              ),
              reviewCount: teacher['reviewCount'] ?? 0,
              isCompact: true,
              starSize: 12,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                AppLocalizations.of(context)!.teacher.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
