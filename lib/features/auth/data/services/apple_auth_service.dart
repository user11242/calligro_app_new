// lib/features/auth/data/services/apple_auth_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:ui' as ui;
import '../models/user_model.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/numeric_utils.dart';

class AppleAuthService {
  // --- 1. Singleton Setup ---
  AppleAuthService._privateConstructor();
  static final AppleAuthService instance = AppleAuthService._privateConstructor();

  // --- 2. Class Variables ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthCredential? _pendingAppleCredential;
  String? _pendingEmail;

  AuthCredential? get pendingAppleCredential => _pendingAppleCredential;
  String? get pendingEmail => _pendingEmail;

  void log(String msg) {
    debugPrint(msg);
  }

  void clearPendingCredential() {
    _pendingAppleCredential = null;
    _pendingEmail = null;
  }

  /// ---------------------------------------------------------------
  /// 🔹 Sign In With Apple
  /// ---------------------------------------------------------------
  Future<String?> signInWithApple(AuthService authService) async {
    AuthCredential? credential;
    
    try {
      log("🚀 Apple Auth: Starting signInWithApple flow...");
      
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      credential = oauthCredential;
      final email = appleCredential.email; // Apple only returns this ONCE on first sign in

      if (email != null && email.isNotEmpty) {
        try {
          log("🚀 Apple Auth: Checking for existing sign-in methods for $email...");
          final methods = await authService.getUserSignInMethods(email);
          log("✅ Apple Auth: Existing methods found: $methods");
          
          if (methods.contains('password') && !methods.contains('apple.com')) {
            _pendingAppleCredential = credential;
            _pendingEmail = email;
            log("⚠️ Apple Auth: Account exists with password. Returning link-flow signal.");
            return "ACCOUNT_EXISTS_DIFFERENT_CREDENTIAL";
          }
        } catch (e) {
          log("⚠️ Apple Auth: Provider check error (non-fatal): $e");
        }
      }

      log("🚀 Apple Auth: Firebase sign-in...");
      final userCred = await _auth.signInWithCredential(credential);
      log("✅ Apple Auth: Firebase Success: ${userCred.user?.uid}");

      // If Apple provided a name this time, update the Firebase User Profile
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        String displayName = "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}".trim();
        if (displayName.isNotEmpty) {
           await userCred.user?.updateDisplayName(displayName);
        }
      }

      log("🚀 Apple Auth: Fetching Firestore doc...");
      final doc = await _firestore
          .collection("users")
          .doc(userCred.user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final String? role = data["role"];
        
        if (role != null && role.isNotEmpty) {
          log("✅ Apple Auth: Doc found. Role: $role");
          return role;
        }
      }

      log("ℹ️ Apple Auth: No role found (new user or skeleton doc). Returning NEEDS_ROLE.");
      return "NEEDS_ROLE";

    } on FirebaseAuthException catch (e) {
      log("❌ Apple Auth: Firebase Error: ${e.code}");
      if (e.code == 'account-exists-with-different-credential') {
        _pendingAppleCredential = credential;
        return "ACCOUNT_EXISTS_DIFFERENT_CREDENTIAL";
      }
      return "Firebase Error: ${e.message}";
    } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
           log("ℹ️ Apple Auth: User cancelled sign-in flow.");
           return null;
        }
        return "Exception: $e";
    } catch (e) {
      log("❌ Apple Auth Error: $e");
      return "Exception: $e";
    }
  }

  /// ---------------------------------------------------------------
  /// 🔹 Create User Document (Mimics Google Logic)
  /// ---------------------------------------------------------------
  Future<String?> createAppleUserWithRole({
    required String role,
    required bool acceptedTerms,
    String? phone,
    String? portfolio,
    List<String>? spokenLanguages,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return "Not signed in";

    try {
      // 1. Photo Logic
      String finalPhotoUrl = user.photoURL ?? "";
      if (role == 'teacher') {
        finalPhotoUrl = ""; // Teachers must upload professional photo later
      }

      // 2. Create Model
      UserModel newUser = UserModel(
        uid: user.uid,
        name: user.displayName ?? "User",
        email: user.email ?? "",
        role: role,
        status: role == "teacher" ? "pending" : "approved",
        acceptedTerms: acceptedTerms,
        photoUrl: finalPhotoUrl,
        phone: phone ?? "",
        portfolio: portfolio,
        spokenLanguages: spokenLanguages ?? const [],
        createdAt: DateTime.now(),
        authProvider: 'apple', // ✅ Explicitly set provider
        language: ui.PlatformDispatcher.instance.locale.languageCode,
        // Stats defaults
        totalStars: 0,
        reviewCount: 0,
        followersCount: 0,
        followingCount: 0,
        postCount: 0,
      );

      // 3. 🔹 START BATCH WRITE (The "7 Folder" Logic)
      WriteBatch batch = _firestore.batch();

      // A. Add to 'users' (Master List)
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);
      batch.set(userRef, newUser.toMap());

      // B. Add to Role Folder ('students' or 'teachers')
      if (role == 'student') {
        DocumentReference studentRef = _firestore
            .collection('students')
            .doc(user.uid);
        batch.set(studentRef, newUser.toMap());
      } else if (role == 'teacher') {
        DocumentReference teacherRef = _firestore
            .collection('teachers')
            .doc(user.uid);
        batch.set(teacherRef, newUser.toMap());
      }

      // C. Lock the Email (Security)
      if (user.email != null && user.email!.isNotEmpty) {
        DocumentReference emailLockRef = _firestore
            .collection('locked_emails')
            .doc(user.email!.trim().toLowerCase());
        batch.set(emailLockRef, {
          'uid': user.uid,
          'createdAt': Timestamp.now(),
        });
      }

      // D. Lock the Username (Security)
      if (newUser.name.isNotEmpty && newUser.name != "User") {
        DocumentReference usernameLockRef = _firestore
            .collection('locked_usernames')
            .doc(newUser.name.trim().toLowerCase());
        batch.set(usernameLockRef, {
          'uid': user.uid,
          'createdAt': Timestamp.now(),
        });
      }

      // E. Lock the Phone (Security - Only if provided)
      if (phone != null && phone.isNotEmpty) {
        final cleanPhone = NumericUtils.normalize(phone, clean: true);
        DocumentReference phoneRef = _firestore
            .collection('locked_phones')
            .doc(cleanPhone);
        batch.set(phoneRef, {
          'uid': user.uid,
          'email': user.email,
          'createdAt': Timestamp.now(),
        });
      }

      // 4. Commit everything at once
      await batch.commit();
      print("✅ Apple user document created for role: $role (uid: ${user.uid})");
      return null; // null means success
    } catch (e) {
      print("❌ Error creating Apple user document: $e");
      return e.toString();
    }
  }
}
