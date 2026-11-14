import 'package:calligro_app/features/meet/application/connection_quality_monitor.dart';
import 'package:calligro_app/features/meet/domain/meet_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionQualityMonitor (audio-only prompt)', () {
    late ConnectionQualityMonitor controller;
    bool promptTriggered = false;

    setUp(() {
      // Use very small thresholds for testing
      controller = ConnectionQualityMonitor(
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
        MeetConnectionQuality.poor,
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
        MeetConnectionQuality.poor,
        () => promptTriggered = true,
      );

      // Recover after 500ms
      await Future.delayed(const Duration(milliseconds: 500));
      controller.handleConnectionQualityUpdate(
        MeetConnectionQuality.good,
        () => promptTriggered = true,
      );

      // Wait out the rest of the original timer
      await Future.delayed(const Duration(milliseconds: 700));
      expect(promptTriggered, isFalse); // Should be cancelled
    });

    test('should respect cooldown before prompting again', () async {
      // 1. Initial trigger
      controller.handleConnectionQualityUpdate(
        MeetConnectionQuality.poor,
        () => promptTriggered = true,
      );
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(promptTriggered, isTrue);
      
      // Reset test state and close prompt
      promptTriggered = false;
      controller.onPromptClosed();

      // 2. Immediate re-trigger should fail due to cooldown (2s)
      controller.handleConnectionQualityUpdate(
        MeetConnectionQuality.poor,
        () => promptTriggered = true,
      );
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(promptTriggered, isFalse); // Still in cooldown

      // 3. Wait for cooldown to expire
      await Future.delayed(const Duration(milliseconds: 1000)); // Total 2.1s elapsed
      
      // 4. Trigger should now succeed
      controller.handleConnectionQualityUpdate(
        MeetConnectionQuality.poor,
        () => promptTriggered = true,
      );
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(promptTriggered, isTrue);
    });
  });
}
