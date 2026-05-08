// lib/features/auth/data/services/google_auth_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:ui' as ui;
import '../models/user_model.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/numeric_utils.dart';

class GoogleAuthService {
  // --- 1. Singleton Setup ---
  GoogleAuthService._privateConstructor();
  static final GoogleAuthService instance =
      GoogleAuthService._privateConstructor();

  // --- 2. Class Variables ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ CORRECT SETUP for google_sign_in ^7.0.0
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _isInitialized = false;
  AuthCredential? _pendingGoogleCredential;
  String? _pendingEmail;

  AuthCredential? get pendingGoogleCredential => _pendingGoogleCredential;
  String? get pendingEmail => _pendingEmail;

  // ✅ PUBLIC GETTER FOR CONSISTENCY
  GoogleSignIn get googleSignIn => _googleSignIn;

  void log(String msg) => debugPrint(msg);

  void clearPendingCredential() {
    _pendingGoogleCredential = null;
    _pendingEmail = null;
  }

  /// ---------------------------------------------------------------
  /// 🔹 Initialization Method
  /// ---------------------------------------------------------------
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      log("🚀 Google Auth: System Initialization...");
      await _googleSignIn.initialize(
        serverClientId: '500166558232-t947e97f4ocmap218qu3rm3u0o080pma.apps.googleusercontent.com',
      );
      _isInitialized = true;
      log("✅ Google Auth: System Initialized.");
    } catch (e) {
      log("❌ Google Auth: Init Error: $e");
    }
  }

  /// ---------------------------------------------------------------
  /// 🔹 Sign In With Google
  /// ---------------------------------------------------------------
  Future<String?> signInWithGoogle(AuthService authService) async {
    AuthCredential? credential;
    dynamic googleUser;
    
    try {
      log("🚀 Google Auth: Starting signInWithGoogle flow...");
      
      // Ensure it's initialized
      await initialize();
      
      log("🚀 Google Auth: Requesting account picker...");
      
      // Removed signOut() here as it might be causing race conditions or hanging on some devices.
      // authenticate() in 7.0.0+ should handle its own state better.
      
      log("🚀 Google Auth: Calling authenticate() now...");
      final startTime = DateTime.now();
      googleUser = await _googleSignIn.authenticate();
      final duration = DateTime.now().difference(startTime);
      
      log("✅ Google Auth: authenticate() finished in ${duration.inMilliseconds}ms");
      log("✅ Google Auth: Result: ${googleUser?.email ?? 'NULL (Canceled or Error)'}");

      if (googleUser == null) {
        log("❌ Google Auth: No account selected (User cancelled or no accounts available).");
        return null;
      }

      log("🚀 Google Auth: Fetching tokens...");
      final googleAuth = await googleUser.authentication;
      log("✅ Google Auth: Tokens retrieved.");

      credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 🛑 INTERCEPT: Prevent Firebase from silently deleting the password provider.
      if (googleUser.email != null) {
        try {
          log("🚀 Google Auth: Checking for existing sign-in methods for ${googleUser.email}...");
          final methods = await authService.getUserSignInMethods(googleUser.email);
          log("✅ Google Auth: Existing methods found: $methods");
          
          if (methods.contains('password') && !methods.contains('google.com')) {
            _pendingGoogleCredential = credential;
            _pendingEmail = googleUser.email;
            log("⚠️ Google Auth: Account exists with password. Returning link-flow signal.");
            return "ACCOUNT_EXISTS_DIFFERENT_CREDENTIAL";
          }
        } catch (e) {
          log("⚠️ Google Auth: Provider check error (non-fatal): $e");
        }
      }

      log("🚀 Google Auth: Firebase sign-in...");
      final userCred = await _auth.signInWithCredential(credential);
      log("✅ Google Auth: Firebase Success: ${userCred.user?.uid}");

      log("🚀 Google Auth: Fetching Firestore doc...");
      final doc = await _firestore
          .collection("users")
          .doc(userCred.user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final String? role = data["role"];
        
        if (role != null && role.isNotEmpty) {
          log("✅ Google Auth: Doc found. Role: $role");
          return role;
        }
      }

      log("ℹ️ Google Auth: No role found (new user or skeleton doc). Returning NEEDS_ROLE.");
      return "NEEDS_ROLE";
    } on FirebaseAuthException catch (e) {
      log("❌ Google Auth: Firebase Error: ${e.code}");
      if (e.code == 'account-exists-with-different-credential') {
        _pendingGoogleCredential = credential;
        _pendingEmail = googleUser?.email;
        return "ACCOUNT_EXISTS_DIFFERENT_CREDENTIAL";
      }
      return e.message;
    } catch (e) {
      log("❌ Google Auth Error: $e");
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('canceled') || errorStr.contains('cancel')) {
        return null;
      }
      return e.toString();
    }
  }

  /// ---------------------------------------------------------------
  /// 🔹 Create User Document (✅ UPDATED FOR FOLDER STRUCTURE)
  /// ---------------------------------------------------------------
  Future<String?> createGoogleUserWithRole({
    // Removed 'authService' because we save directly here for safety
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
        authProvider: 'google', // ✅ Explicitly set provider
        language: ui.PlatformDispatcher.instance.locale.languageCode, // ✅ Capture language
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
      if (user.email != null) {
        DocumentReference emailLockRef = _firestore
            .collection('locked_emails')
            .doc(user.email!.trim().toLowerCase());
        batch.set(emailLockRef, {
          'uid': user.uid,
          'createdAt': Timestamp.now(),
        });
      }

      // D. ✅ ADDED: Lock the Username (Security)
      if (newUser.name.isNotEmpty) {
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
      print("✅ Google user document created for role: $role (uid: ${user.uid})");
      return null; // null means success
    } catch (e) {
      print("❌ Error creating Google user document: $e");
      return e.toString();
    }
  }

  /// ---------------------------------------------------------------
  /// 🔹 Sign Out
  /// ---------------------------------------------------------------
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Error signing out: $e");
    }
  }
}
