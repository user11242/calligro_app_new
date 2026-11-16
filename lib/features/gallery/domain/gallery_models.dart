/// The calligraphy gallery (pure Dart).
library;

DateTime? _date(Object? v) {
  try {
    final dynamic t = v;
    if (v is DateTime) return v;
    if (v != null) return t.toDate() as DateTime; // Firestore Timestamp
  } catch (_) {}
  return null;
}

String? _opt(Object? v) => v is String ? v : null;

class GalleryArtist {
  final String id;
  final String name;
  final String bio;
  final String? photoUrl;
  final String? birthDate;
  final String? deathDate;
  final String? lifeDetails;
  final DateTime? createdAt;

  GalleryArtist({
    required this.id,
    required this.name,
    required this.bio,
    this.photoUrl,
    this.birthDate,
    this.deathDate,
    this.lifeDetails,
    this.createdAt,
  });

  factory GalleryArtist.fromMap(String id, Map<String, dynamic> data) => GalleryArtist(
        id: id,
        name: _opt(data['name']) ?? '',
        bio: _opt(data['bio']) ?? '',
        photoUrl: _opt(data['photoUrl']),
        birthDate: _opt(data['birthDate']),
        deathDate: _opt(data['deathDate']),
        lifeDetails: _opt(data['lifeDetails']),
        createdAt: _date(data['createdAt']),
      );
}

class GalleryArtwork {
  final String id;
  final String artistId;
  final String thumbnailUrl;
  final String highResUrl;
  final String title;
  final DateTime? createdAt;

  GalleryArtwork({
    required this.id,
    required this.artistId,
    required this.thumbnailUrl,
    required this.highResUrl,
    required this.title,
    this.createdAt,
  });

  factory GalleryArtwork.fromMap(String id, Map<String, dynamic> data) => GalleryArtwork(
        id: id,
        artistId: _opt(data['artistId']) ?? '',
        thumbnailUrl: _opt(data['thumbnailUrl']) ?? '',
        highResUrl: _opt(data['highResUrl']) ?? '',
        title: _opt(data['title']) ?? '',
        createdAt: _date(data['createdAt']),
      );

  /// Newest first; undated last (as the service sorted before).
  static int newestFirst(GalleryArtwork a, GalleryArtwork b) =>
      (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
}

/// The gallery's data (artists and their works).
abstract interface class GalleryRepository {
  Future<List<GalleryArtist>> getArtistsList();
  Future<List<GalleryArtist>> getArtists();
  Future<List<GalleryArtwork>> getArtworksList(String artistId);
}

/// Turns a stored Storage link into a working download link (adds the token
/// when it is missing); falls back to the original link.
abstract interface class ImageUrlResolver {
  Future<String> resolve(String url);
}
