class StudentUserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final bool isGuest;
  final int followingCount;

  StudentUserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isGuest,
    this.followingCount = 0,
  });

  // Factory to create a Student from Firestore Data
  factory StudentUserModel.fromMap(Map<String, dynamic> data, String uid) {
    return StudentUserModel(
      uid: uid,
      name: data['fullName'] ?? data['name'] ?? "Student",
      email: data['email'] ?? "",
      photoUrl: data['photoUrl'] ?? "",
      isGuest: false,
      followingCount: data['followingCount'] ?? 0,
    );
  }

  // Factory for Guest User
  factory StudentUserModel.guest() {
    return StudentUserModel(
      uid: "guest",
      name: "Guest",
      email: "",
      photoUrl: "",
      isGuest: true,
      followingCount: 0,
    );
  }
}