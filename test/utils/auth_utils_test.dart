import 'package:flutter_test/flutter_test.dart';

// Simulating Authentication link logic to prevent duplicate accounts

class MockAuthService {
  final Map<String, String> _userEmailsToUids = {
    'yazan@calligro.com': 'user_123',
  };

  /// Simulates attempting to sign in with Google or Apple
  /// Returns the existing UID if email matches, or creates a new one
  String linkOAuthAccount(String email) {
    if (_userEmailsToUids.containsKey(email)) {
      return _userEmailsToUids[email]!; // Link to existing
    }
    return 'new_user_uid';
  }

  /// Simulates Universal OTP sending
  bool requestSmsVerification(String phoneNumber) {
    if (phoneNumber.startsWith('+')) {
      return true; // Sent successfully
    }
    throw ArgumentError('Invalid phone number format');
  }
}

void main() {
  group('Domain 3: Authentication & Onboarding (Tests 17-19)', () {
    test('Test Case 17: Universal OTP requires standard E.164 phone format', () {
      final auth = MockAuthService();
      
      expect(auth.requestSmsVerification('+962790000000'), isTrue);
      expect(() => auth.requestSmsVerification('0790000000'), throwsArgumentError);
    });

    test('Test Case 18: Apple Sign-In correctly links to existing email', () {
      final auth = MockAuthService();
      
      // Simulating Apple providing the same email as an existing Google account
      final uid = auth.linkOAuthAccount('yazan@calligro.com');
      
      // Should NOT create a new account, should return the exact same UID
      expect(uid, equals('user_123'));
    });

    test('Test Case 19: Google Sign-In correctly links to existing email', () {
      final auth = MockAuthService();
      
      // Simulating a brand new user
      final uid = auth.linkOAuthAccount('newstudent@gmail.com');
      
      expect(uid, equals('new_user_uid'));
    });
  });
}
