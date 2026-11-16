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


  /// Creates a [CourseChatMessage] from a document ID and raw field map.
  factory CourseChatMessage.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parsedDate;
    try {
      final dynamic raw = data['createdAt'];
      if (raw is DateTime) {
        parsedDate = raw;
      } else if (raw != null) {
        parsedDate = raw.toDate() as DateTime; // Firestore Timestamp
      }
    } catch (_) {}

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
}

/// Who may remove a chat message: its sender, the course's teacher, an admin
/// (firestore.rules agree).
class ChatPolicy {
  ChatPolicy._();

  static bool canDelete(CourseChatMessage message, String? uid, {required bool isTeacher, required bool isAdmin}) =>
      (uid != null && message.senderId == uid) || isTeacher || isAdmin;

  /// The badge a new message carries (rules refuse a false one): the course's
  /// teacher → teacher; an admin → admin; everyone else → student.
  static String senderRole({required String uid, required String profileRole, String? courseTeacherId}) {
    if (courseTeacherId != null && uid == courseTeacherId) return 'teacher';
    if (profileRole == 'admin') return 'admin';
    return 'student';
  }
}
