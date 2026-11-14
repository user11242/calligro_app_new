/// Immutable representation of a comment under a community post.
class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String authorRole;
  final String text;
  final DateTime createdAt;
  final int replyCount;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl = '',
    this.authorRole = 'student',
    required this.text,
    required this.createdAt,
    this.replyCount = 0,
  });

  CommunityComment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? authorRole,
    String? text,
    DateTime? createdAt,
    int? replyCount,
  }) {
    return CommunityComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      authorRole: authorRole ?? this.authorRole,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      replyCount: replyCount ?? this.replyCount,
    );
  }

  factory CommunityComment.fromMap({
    required String id,
    required String postId,
    required Map<String, dynamic> map,
  }) {
    DateTime parsedDate;
    final rawTimestamp = map['timestamp'] ?? map['createdAt'];
    if (rawTimestamp is DateTime) {
      parsedDate = rawTimestamp;
    } else if (rawTimestamp != null && rawTimestamp.toString().contains('Timestamp')) {
      // Handles Firestore Timestamp dynamically without importing Cloud Firestore in domain
      try {
        final seconds = (rawTimestamp as dynamic).seconds as int;
        parsedDate = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else if (rawTimestamp is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else {
      parsedDate = DateTime.now();
    }

    return CommunityComment(
      id: id,
      postId: postId,
      authorId: map['userId'] ?? map['authorId'] ?? '',
      authorName: map['userName'] ?? map['authorName'] ?? 'Anonymous',
      authorPhotoUrl: map['userImageUrl'] ?? map['authorPhotoUrl'] ?? '',
      authorRole: map['userRole'] ?? map['authorRole'] ?? 'student',
      text: map['comment'] ?? map['text'] ?? '',
      createdAt: parsedDate,
      replyCount: map['replyCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': authorId,
      'userName': authorName,
      'userImageUrl': authorPhotoUrl,
      'userRole': authorRole,
      'comment': text,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'replyCount': replyCount,
    };
  }
}
