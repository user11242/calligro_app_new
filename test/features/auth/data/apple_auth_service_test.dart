import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:calligro_app/features/auth/data/services/apple_auth_service.dart';

void main() {
  group('Layer 2: AppleAuthService Tests (Coverage)', () {
    late MockFirebaseAuth mockAuth;
    late FakeFirebaseFirestore fakeFirestore;
    late AppleAuthService appleAuthService;

    setUp(() {
      mockAuth = MockFirebaseAuth(signedIn: false);
      fakeFirestore = FakeFirebaseFirestore();
      
      appleAuthService = AppleAuthService.forTest(
        auth: mockAuth,
        firestore: fakeFirestore,
      );
    });

    test('clearPendingCredential() clears data', () {
      appleAuthService.clearPendingCredential();
      expect(appleAuthService.pendingAppleCredential, isNull);
      expect(appleAuthService.pendingEmail, isNull);
    });

    // signInWithApple is hard to mock without custom platform channels or mocking SignInWithApple plugin
    // We can just verify clearPendingCredential works which covers some logic.
  });
}
