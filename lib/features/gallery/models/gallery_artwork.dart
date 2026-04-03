import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory GalleryArtwork.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GalleryArtwork(
      id: doc.id,
      artistId: data['artistId'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      highResUrl: data['highResUrl'] ?? '',
      title: data['title'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artistId': artistId,
      'thumbnailUrl': thumbnailUrl,
      'highResUrl': highResUrl,
      'title': title,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
