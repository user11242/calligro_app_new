import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/gallery/services/gallery_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Layer 2: GalleryService Tests (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late GalleryService galleryService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      galleryService = GalleryService(firestore: fakeFirestore);
    });

    test('getArtistsList() returns artists', () async {
      await fakeFirestore.collection('gallery_artists').add({
        'name': 'Artist 1',
        'bio': 'bio',
        'avatarUrl': 'url',
      });
      await fakeFirestore.collection('gallery_artists').add({
        'name': 'Artist 2',
        'bio': 'bio2',
        'avatarUrl': 'url2',
      });

      final artists = await galleryService.getArtistsList();
      expect(artists.length, 2);
    });

    test('getArtists() returns artists', () async {
      await fakeFirestore.collection('gallery_artists').add({
        'name': 'Artist 1',
        'bio': 'bio',
        'avatarUrl': 'url',
      });

      final artists = await galleryService.getArtists();
      expect(artists.length, 1);
    });

    test('getArtworksList() returns artworks sorted by date', () async {
      await fakeFirestore.collection('gallery_artworks').add({
        'artistId': 'a1',
        'title': 'Older',
        'imageUrl': 'url',
        'createdAt': Timestamp.fromDate(DateTime(2023)),
      });
      await fakeFirestore.collection('gallery_artworks').add({
        'artistId': 'a1',
        'title': 'Newer',
        'imageUrl': 'url2',
        'createdAt': Timestamp.fromDate(DateTime(2024)),
      });
      await fakeFirestore.collection('gallery_artworks').add({
        'artistId': 'a2', // Different artist
        'title': 'Other',
        'imageUrl': 'url3',
        'createdAt': Timestamp.fromDate(DateTime(2024)),
      });

      final artworks = await galleryService.getArtworksList('a1');
      expect(artworks.length, 2);
      expect(artworks.first.title, 'Newer'); // Sorted descending
      expect(artworks.last.title, 'Older');
    });
  });
}
