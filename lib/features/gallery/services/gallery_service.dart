import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gallery_artist.dart';
import '../models/gallery_artwork.dart';

class GalleryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Future of all gallery artists (cached)
  Future<List<GalleryArtist>> getArtistsList() async {
    final snapshot = await _db
        .collection('gallery_artists')
        .orderBy('name')
        .limit(100)
        .get(const GetOptions(source: Source.serverAndCache));
        
    return snapshot.docs
        .map((doc) => GalleryArtist.fromFirestore(doc))
        .toList();
  }

  // Future to get artists (for search/filtering if needed)
  Future<List<GalleryArtist>> getArtists() async {
    final snapshot = await _db.collection('gallery_artists').orderBy('name').limit(100).get();
    return snapshot.docs.map((doc) => GalleryArtist.fromFirestore(doc)).toList();
  }

  // Future of artworks for a specific artist (cached)
  Future<List<GalleryArtwork>> getArtworksList(String artistId) async {
    final snapshot = await _db
        .collection('gallery_artworks')
        .where('artistId', isEqualTo: artistId)
        .limit(100)
        .get(const GetOptions(source: Source.serverAndCache));

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
  }

  }