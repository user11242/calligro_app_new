import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/gallery/models/gallery_artwork.dart';

void main() {
  group('Layer 1: GalleryArtwork Tests (Coverage)', () {
    final now = DateTime(2026, 1, 1);
    final timestamp = Timestamp.fromDate(now);

    test('fromFirestore() converts Firebase DocumentSnapshot correctly', () async {
      final instance = FakeFirebaseFirestore();
      final docRef = instance.collection('artworks').doc('art_123');
      
      await docRef.set({
        'artistId': 'artist_456',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'highResUrl': 'https://example.com/high.jpg',
        'title': 'The Blue Quran',
        'createdAt': timestamp,
      });

      final snapshot = await docRef.get();
      final artwork = GalleryArtwork.fromFirestore(snapshot);

      expect(artwork.id, 'art_123');
      expect(artwork.artistId, 'artist_456');
      expect(artwork.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(artwork.highResUrl, 'https://example.com/high.jpg');
      expect(artwork.title, 'The Blue Quran');
      expect(artwork.createdAt, now);
    });

    test('fromFirestore() handles null values safely with defaults', () async {
      final instance = FakeFirebaseFirestore();
      final docRef = instance.collection('artworks').doc('art_empty');
      
      await docRef.set({}); // Empty
      final snapshot = await docRef.get();
      final artwork = GalleryArtwork.fromFirestore(snapshot);

      expect(artwork.id, 'art_empty');
      expect(artwork.artistId, '');
      expect(artwork.thumbnailUrl, '');
      expect(artwork.highResUrl, '');
      expect(artwork.title, '');
      expect(artwork.createdAt, isNull);
    });

    test('toMap() converts GalleryArtwork back to Firebase map', () {
      final artwork = GalleryArtwork(
        id: 'art_789',
        artistId: 'artist_999',
        thumbnailUrl: 'thumb.jpg',
        highResUrl: 'high.jpg',
        title: 'Masterpiece',
        createdAt: now,
      );

      final map = artwork.toMap();

      expect(map['id'], 'art_789');
      expect(map['artistId'], 'artist_999');
      expect(map['thumbnailUrl'], 'thumb.jpg');
      expect(map['highResUrl'], 'high.jpg');
      expect(map['title'], 'Masterpiece');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });
  });
}
