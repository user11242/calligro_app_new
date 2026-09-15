import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/gallery/models/gallery_artist.dart';

void main() {
  group('Layer 1: GalleryArtist Tests (Coverage)', () {
    final now = DateTime(2026, 1, 1);
    final timestamp = Timestamp.fromDate(now);

    test('fromFirestore() converts Firebase DocumentSnapshot correctly', () async {
      // 1. Setup Fake Firestore Database
      final instance = FakeFirebaseFirestore();
      final docRef = instance.collection('artists').doc('artist_123');
      
      await docRef.set({
        'name': 'Ali Ghalib',
        'bio': 'Master Calligrapher from Iraq',
        'photoUrl': 'https://example.com/ali.jpg',
        'birthDate': '1900',
        'deathDate': '1980',
        'lifeDetails': 'Wrote the Quran in Riqaa',
        'createdAt': timestamp,
      });

      // 2. Fetch the DocumentSnapshot
      final snapshot = await docRef.get();

      // 3. Test the conversion
      final artist = GalleryArtist.fromFirestore(snapshot);

      expect(artist.id, 'artist_123');
      expect(artist.name, 'Ali Ghalib');
      expect(artist.bio, 'Master Calligrapher from Iraq');
      expect(artist.photoUrl, 'https://example.com/ali.jpg');
      expect(artist.birthDate, '1900');
      expect(artist.deathDate, '1980');
      expect(artist.lifeDetails, 'Wrote the Quran in Riqaa');
      expect(artist.createdAt, now);
    });

    test('fromFirestore() handles null values safely with defaults', () async {
      final instance = FakeFirebaseFirestore();
      final docRef = instance.collection('artists').doc('artist_456');
      
      // Empty document
      await docRef.set({});
      final snapshot = await docRef.get();
      final artist = GalleryArtist.fromFirestore(snapshot);

      expect(artist.id, 'artist_456');
      expect(artist.name, ''); // Default fallback
      expect(artist.bio, '');  // Default fallback
      expect(artist.photoUrl, isNull);
      expect(artist.birthDate, isNull);
      expect(artist.deathDate, isNull);
      expect(artist.lifeDetails, isNull);
      expect(artist.createdAt, isNull);
    });

    test('toMap() converts GalleryArtist back to Firebase map', () {
      final artist = GalleryArtist(
        id: 'artist_789',
        name: 'Abbas Al-Baghdadi',
        bio: 'Legendary Calligrapher',
        createdAt: now,
      );

      final map = artist.toMap();

      expect(map['id'], 'artist_789');
      expect(map['name'], 'Abbas Al-Baghdadi');
      expect(map['bio'], 'Legendary Calligrapher');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });
  });
}
