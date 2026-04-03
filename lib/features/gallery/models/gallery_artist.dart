import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory GalleryArtist.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GalleryArtist(
      id: doc.id,
      name: data['name'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'],
      birthDate: data['birthDate'],
      deathDate: data['deathDate'],
      lifeDetails: data['lifeDetails'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bio': bio,
      'photoUrl': photoUrl,
      'birthDate': birthDate,
      'deathDate': deathDate,
      'lifeDetails': lifeDetails,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
