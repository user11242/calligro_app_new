import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gallery_artist.dart';
import '../models/gallery_artwork.dart';

class GalleryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of all gallery artists
  Stream<List<GalleryArtist>> getArtistsStream() {
    return _db
        .collection('gallery_artists')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GalleryArtist.fromFirestore(doc))
            .toList());
  }

  // Future to get artists (for search/filtering if needed)
  Future<List<GalleryArtist>> getArtists() async {
    final snapshot = await _db.collection('gallery_artists').orderBy('name').get();
    return snapshot.docs.map((doc) => GalleryArtist.fromFirestore(doc)).toList();
  }

  // Stream of artworks for a specific artist
  Stream<List<GalleryArtwork>> getArtworksStream(String artistId) {
    return _db
        .collection('gallery_artworks')
        .where('artistId', isEqualTo: artistId)
        .snapshots()
        .map((snapshot) {
      final artworks = snapshot.docs
          .map((doc) => GalleryArtwork.fromFirestore(doc))
          .toList();

      // Sort client-side to avoid needing a Firestore composite index
      artworks.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA); // Descending order
      });

      return artworks;
    });
  }

  }