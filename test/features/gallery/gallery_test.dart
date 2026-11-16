import 'dart:io';

import 'package:calligro_app/features/gallery/domain/gallery_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('artist / artwork read from stored maps (missing fields → defaults)', () {
    final a = GalleryArtist.fromMap('a1', {'name': 'Hashim', 'bio': 'Master', 'createdAt': DateTime(2026, 1, 1)});
    expect([a.name, a.bio, a.photoUrl, a.createdAt], ['Hashim', 'Master', null, DateTime(2026, 1, 1)]);
    final w = GalleryArtwork.fromMap('w1', const {});
    expect([w.artistId, w.title, w.highResUrl, w.createdAt], ['', '', '', null]);
  });

  test('artworks newest first, undated last (as before)', () {
    final list = [
      GalleryArtwork(id: 'old', artistId: 'a', thumbnailUrl: '', highResUrl: '', title: '', createdAt: DateTime(2020)),
      GalleryArtwork(id: 'none', artistId: 'a', thumbnailUrl: '', highResUrl: '', title: ''),
      GalleryArtwork(id: 'new', artistId: 'a', thumbnailUrl: '', highResUrl: '', title: '', createdAt: DateTime(2026)),
    ]..sort(GalleryArtwork.newestFirst);
    expect(list.map((w) => w.id), ['new', 'old', 'none']);
  });

  test('guard-rails: pure domain; widgets and pages use GalleryScope / GalleryServices', () {
    expect(File('lib/features/gallery/domain/gallery_models.dart').readAsStringSync().contains('package:'), isFalse);
    for (final p in [
      'lib/features/gallery/widgets/gallery_image.dart',
      'lib/features/gallery/widgets/artwork_viewer.dart',
      'lib/features/gallery/pages/artist_gallery_page.dart',
      'lib/features/student/pages/gallery_page.dart',
    ]) {
      final c = File(p).readAsStringSync();
      expect(c.contains('FirebaseStorage') || c.contains('FirebaseFirestore') || c.contains('GalleryService()'), isFalse, reason: p);
    }
  });
}
