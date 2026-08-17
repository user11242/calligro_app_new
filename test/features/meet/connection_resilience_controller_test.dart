import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:calligro_app/features/meet/controllers/connection_resilience_controller.dart';

void main() {
  group('ConnectionResilienceController Error Classification', () {
    late ConnectionResilienceController controller;

    setUp(() {
      controller = ConnectionResilienceController();
    });

    test('should retry on ConnectException with InternalError', () {
      final error = ConnectException('err', reason: ConnectionErrorReason.InternalError);
      expect(controller.shouldRetryWithRelay(error), isTrue);
    });

    test('should retry on ConnectException with Timeout', () {
      final error = ConnectException('err', reason: ConnectionErrorReason.Timeout);
      expect(controller.shouldRetryWithRelay(error), isTrue);
    });

    test('should NOT retry on ConnectException with NotAllowed', () {
      final error = ConnectException('err', reason: ConnectionErrorReason.NotAllowed);
      expect(controller.shouldRetryWithRelay(error), isFalse);
    });

    test('should retry on pure TimeoutException', () {
      final error = TimeoutException('err');
      expect(controller.shouldRetryWithRelay(error), isTrue);
    });

    test('should retry on NegotiationError', () {
      final error = NegotiationError('err');
      expect(controller.shouldRetryWithRelay(error), isTrue);
    });

    test('should NOT retry on LiveKitE2EEException', () {
      final error = LiveKitE2EEException('err');
      expect(controller.shouldRetryWithRelay(error), isFalse);
    });
  });

  group('ConnectionResilienceController Hysteresis State Machine', () {
    late ConnectionResilienceController controller;
    bool promptTriggered = false;

    setUp(() {
      // Use very small thresholds for testing
      controller = ConnectionResilienceController(
        poorQualityTriggerSeconds: 1,
        promptCooldownSeconds: 2,
      );
      promptTriggered = false;
    });

    tearDown(() {
      controller.dispose();
    });

    test('should trigger prompt after poor quality duration', () async {
      controller.handleConnectionQualityUpdate(
        ConnectionQuality.poor,
        () => promptTriggered = true,
      );

      // Should not trigger immediately
      expect(promptTriggered, isFalse);

      // Wait for trigger duration
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(promptTriggered, isTrue);
    });

    test('should NOT trigger prompt if quality recovers before timer', () async {
      controller.handleConnectionQualityUpdate(
        ConnectionQuality.poor,
        () => promptTriggered = true,
      );

      // Recover after 500ms
      await Future.delayed(const Duration(milliseconds: 500));
      controller.handleConnectionQualityUpdate(
        ConnectionQuality.good,
        () => promptTriggered = true,
      );

      // Wait out the rest of the original timer
      await Future.delayed(const Duration(milliseconds: 700));
      expect(promptTriggered, isFalse); // Should be cancelled
    });

    test('should respect cooldown before prompting again', () async {
      // 1. Initial trigger
      controller.handleConnectionQualityUpdate(
        ConnectionQuality.poor,
        () => promptTriggered = true,
      );
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(promptTriggered, isTrue);
      
      // Reset test state and close prompt
      promptTriggered = false;
      controller.onPromptClosed();

      // 2. Immediate re-trigger should fail due to cooldown (2s)
      controller.handleConnectionQualityUpdate(
        ConnectionQuality.poor,
        () => promptTriggered = true,
      );
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(promptTriggered, isFalse); // Still in cooldown

      // 3. Wait for cooldown to expire
      await Future.delayed(const Duration(milliseconds: 1000)); // Total 2.1s elapsed
      
      // 4. Trigger should now succeed
      controller.handleConnectionQualityUpdate(
        ConnectionQuality.poor,
        () => promptTriggered = true,
      );
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(promptTriggered, isTrue);
    });
  });
}
