import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/auth/data/services/google_auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/mockito.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {
  @override
  Future<void> initialize({
    String? scopes,
    String? clientId,
    String? serverClientId,
    String? forceCodeForRefreshToken,
    String? hostedDomain,
    String? nonce, // Added nonce parameter
  }) async {
    return;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    return null;
  }
  
  @override
  Future<GoogleSignInAccount?> disconnect() async {
    return null;
  }
}

void main() {
  group('Layer 2: GoogleAuthService Tests (Coverage)', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late MockGoogleSignIn mockGoogleSignIn;
    late GoogleAuthService googleAuthService;

    setUp(() {
      mockAuth = MockFirebaseAuth(signedIn: false);
      fakeFirestore = FakeFirebaseFirestore();
      mockGoogleSignIn = MockGoogleSignIn();
      
      googleAuthService = GoogleAuthService.forTest(
        auth: mockAuth,
        firestore: fakeFirestore,
        googleSignIn: mockGoogleSignIn,
      );
    });

    test('initialize() does not crash', () async {
      await googleAuthService.initialize();
      expect(true, isTrue);
    });

    test('clearPendingCredential() clears pending data', () {
      googleAuthService.clearPendingCredential();
      expect(googleAuthService.pendingGoogleCredential, isNull);
      expect(googleAuthService.pendingEmail, isNull);
    });
    
    test('signOut() does not crash', () async {
      await googleAuthService.signOut();
      expect(true, isTrue);
    });
  });
}
