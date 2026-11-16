import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/gallery_models.dart';

class GalleryService implements GalleryRepository {
  final FirebaseFirestore? _firestoreMock;

  GalleryService({FirebaseFirestore? firestore}) : _firestoreMock = firestore;

  FirebaseFirestore get _db => _firestoreMock ?? FirebaseFirestore.instance;

  static GalleryArtist artist(DocumentSnapshot<Map<String, dynamic>> d) => GalleryArtist.fromMap(d.id, d.data() ?? const {});
  static GalleryArtwork artwork(DocumentSnapshot<Map<String, dynamic>> d) => GalleryArtwork.fromMap(d.id, d.data() ?? const {});

  /// All gallery artists (cached).
  @override
  Future<List<GalleryArtist>> getArtistsList() async {
    final snapshot = await _db
        .collection('gallery_artists')
        .orderBy('name')
        .limit(100)
        .get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs.map(artist).toList();
  }

  /// Artists (for search/filtering).
  @override
  Future<List<GalleryArtist>> getArtists() async {
    final snapshot = await _db.collection('gallery_artists').orderBy('name').limit(100).get();
    return snapshot.docs.map(artist).toList();
  }

  /// An artist's works, newest first (sorted here: no composite index needed).
  @override
  Future<List<GalleryArtwork>> getArtworksList(String artistId) async {
    final snapshot = await _db
        .collection('gallery_artworks')
        .where('artistId', isEqualTo: artistId)
        .limit(100)
        .get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs.map(artwork).toList()..sort(GalleryArtwork.newestFirst);
  }
}

/// Firebase Storage links: one shared cache for every gallery image.
class StorageUrlResolver implements ImageUrlResolver {
  StorageUrlResolver({FirebaseStorage? storage}) : _injected = storage;
  final FirebaseStorage? _injected;
  static final Map<String, String> _cache = {};

  @override
  Future<String> resolve(String url) async {
    final cached = _cache[url];
    if (cached != null) return cached;
    final clean = url.contains('?') ? url.split('?').first : url;
    final resolved = await (_injected ?? FirebaseStorage.instance).refFromURL(clean).getDownloadURL();
    return _cache[url] = resolved;
  }
}
