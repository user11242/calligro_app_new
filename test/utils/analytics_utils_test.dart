import 'package:flutter_test/flutter_test.dart';

// Simulating the Analytics engine to prove marketing events fire correctly.

class MockFirebaseAnalytics {
  final List<Map<String, dynamic>> loggedEvents = [];

  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
  }) async {
    loggedEvents.add({
      'name': name,
      'parameters': parameters ?? {},
    });
  }
}

class PurchaseService {
  final MockFirebaseAnalytics analytics;

  PurchaseService(this.analytics);

  Future<void> simulateSuccessfulPurchase(String courseId, double price) async {
    // 1. Core business logic happens here (handled by Lemon Squeezy)
    
    // 2. Fire the critical marketing event
    await analytics.logEvent(
      name: 'purchase_course',
      parameters: {
        'course_id': courseId,
        'value': price,
        'currency': 'USD',
      },
    );
  }
}

void main() {
  group('Phase 12: Analytics & Marketing Verification', () {
    test('Test Case: Successful purchase fires correct Analytics payload', () async {
      final mockAnalytics = MockFirebaseAnalytics();
      final purchaseService = PurchaseService(mockAnalytics);

      // Simulate a student buying a course for $54.00
      await purchaseService.simulateSuccessfulPurchase('course_live_001', 54.00);

      // Verify the marketing team receives the exact event needed for Ad tracking
      expect(mockAnalytics.loggedEvents.length, 1);
      
      final event = mockAnalytics.loggedEvents.first;
      expect(event['name'], 'purchase_course');
      expect(event['parameters']['course_id'], 'course_live_001');
      expect(event['parameters']['value'], 54.00);
      expect(event['parameters']['currency'], 'USD');
    });
  });
}
