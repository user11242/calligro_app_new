import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // clear session

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return "Google sign-in cancelled";

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final doc = await _firestore.collection("users").doc(userCred.user!.uid).get();

      if (doc.exists) {
        final role = doc["role"];
        final status = doc["status"];

        if (role == "teacher" && status != "approved") {
          await _auth.signOut();
          return "Teacher account pending approval";
        }

        return role; // "student", "teacher", or "admin"
      } else {
        return "NEEDS_ROLE";
      }
    } catch (e) {
      return "Google sign-in failed";
    }
  }

  Future<String?> createGoogleUserWithRole({required String role}) async {
    final user = _auth.currentUser;
    if (user == null) return "Not signed in";

    await _firestore.collection("users").doc(user.uid).set({
      "uid": user.uid,
      "name": user.displayName ?? "",
      "email": user.email,
      "phone": user.phoneNumber ?? "",
      "portfolio": "",
      "role": role,
      "status": role == "teacher" ? "pending" : "approved",
      "createdAt": FieldValue.serverTimestamp(),
    });

    return role; // return role after creation
  }
}

