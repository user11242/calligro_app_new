/// Immutable domain representation of a community participant/author.
class CommunityUser {
  final String id;
  final String name;
  final String photoUrl;
  final String role;
  final String? bio;
  final bool isFollowing;

  const CommunityUser({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.role = 'student',
    this.bio,
    this.isFollowing = false,
  });

  bool get isTeacher => role.toLowerCase() == 'teacher';
  bool get isAdmin => role.toLowerCase() == 'admin';

  CommunityUser copyWith({
    String? id,
    String? name,
    String? photoUrl,
    String? role,
    String? bio,
    bool? isFollowing,
  }) {
    return CommunityUser(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  factory CommunityUser.fromMap(String id, Map<String, dynamic> map, {bool isFollowing = false}) {
    return CommunityUser(
      id: id,
      name: map['name'] ?? map['userName'] ?? 'Anonymous',
      photoUrl: map['photoUrl'] ?? map['userImageUrl'] ?? '',
      role: map['role'] ?? map['userRole'] ?? 'student',
      bio: map['bio'],
      isFollowing: isFollowing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'role': role,
      if (bio != null) 'bio': bio,
    };
  }
}

