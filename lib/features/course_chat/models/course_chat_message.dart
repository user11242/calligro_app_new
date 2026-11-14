import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable domain model representing a single message in a course group chat.
class CourseChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String senderRole;
  final String text;
  final String? imageUrl;
  final DateTime? createdAt;

  const CourseChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.senderRole,
    required this.text,
    this.imageUrl,
    this.createdAt,
  });

  /// True when the sender is the course's assigned teacher.
  bool get isTeacher => senderRole == 'teacher';

  /// True when the sender is an academy admin.
  bool get isAdmin => senderRole == 'admin';

  /// True when this message includes an attached image URL.
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Creates a [CourseChatMessage] from a Firestore [DocumentSnapshot].
  factory CourseChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return CourseChatMessage.fromMap(doc.id, data);
  }

  /// Creates a [CourseChatMessage] from a document ID and raw field map.
  factory CourseChatMessage.fromMap(String id, Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'];
    final DateTime? parsedDate =
        rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null;

    final rawName = data['senderName']?.toString().trim();
    final rawPhoto = data['senderPhotoUrl']?.toString().trim();
    final rawImage = data['imageUrl']?.toString().trim();

    return CourseChatMessage(
      id: id,
      senderId: data['senderId']?.toString() ?? '',
      senderName: (rawName != null && rawName.isNotEmpty) ? rawName : 'Member',
      senderPhotoUrl:
          (rawPhoto != null && rawPhoto.isNotEmpty) ? rawPhoto : null,
      senderRole: data['senderRole']?.toString() ?? 'student',
      text: data['text']?.toString() ?? '',
      imageUrl: (rawImage != null && rawImage.isNotEmpty) ? rawImage : null,
      createdAt: parsedDate,
    );
  }

  /// Serializes this message into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'senderRole': senderRole,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}

