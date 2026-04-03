// lib/features/auth/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // --- IDENTIFIERS ---
  final String uid;
  final String email;
  final String phone; // ✅ Added back to main fields
  final String authProvider; // 'email' | 'google'

  // --- PUBLIC PROFILE ---
  final String name;
  final String role; // student | teacher | admin
  final String bio;
  final String photoUrl;
  final String? portfolio; // Nullable (only for teachers)
  final String status; // pending | approved
  final String language; // ✅ Added for localization

  // --- LEGAL ---
  final bool acceptedTerms;
  
  // --- STATS ---
  final int followersCount;
  final int followingCount;
  final int postCount;
  final int totalStars;
  final int reviewCount;

  // --- METADATA ---
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.authProvider = 'email', // Default to email for backward compatibility
    this.phone = '', // Default empty if not provided
    this.bio = '',
    this.photoUrl = '',
    this.status = 'pending',
    this.acceptedTerms = false,
    this.portfolio,
    this.language = 'en', // Default to English
    this.followersCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.totalStars = 0,
    this.reviewCount = 0,
    required this.createdAt,
  });

  // ==========================================================
  // 1. READ (From Firebase)
  // ==========================================================
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      authProvider: map['authProvider'] ?? 'email',
      phone: map['phone'] ?? '',

      name: map['name'] ?? '',
      role: map['role'] ?? 'student',
      status: map['status'] ?? 'pending',
      acceptedTerms: map['acceptedTerms'] ?? false,

      bio: map['bio'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      portfolio: map['portfolio'],
      language: map['language'] ?? 'en',

      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      postCount: map['postCount'] ?? 0,
      totalStars: map['totalStars'] ?? 0,
      reviewCount: map['reviewCount'] ?? 0,

      // Handle Timestamp conversion safely
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ==========================================================
  // 2. WRITE (To Firebase - users/students/teachers)
  // ==========================================================
  Map<String, dynamic> toMap() {
    return {
      // Identity
      "uid": uid,
      "email": email, // ✅ Vital for Admin
      "authProvider": authProvider,
      "phone": phone, // ✅ Vital for Admin
      // Search Helpers
      "name": name,
      "name_lower": name.toLowerCase(), // ✅ Kept your search optimization
      // Profile
      "role": role,
      "status": status,
      "bio": bio,
      "photoUrl": photoUrl,
      "portfolio": portfolio,
      "language": language, // ✅ Persist language

      // State
      "acceptedTerms": acceptedTerms,
      "createdAt": Timestamp.fromDate(createdAt),

      // Stats (Initialize as 0)
      "followersCount": followersCount,
      "followingCount": followingCount,
      "postCount": postCount,
      "totalStars": totalStars,
      "reviewCount": reviewCount,
    };
  }
}
