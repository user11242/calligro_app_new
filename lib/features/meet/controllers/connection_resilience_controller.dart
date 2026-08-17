import 'dart:async';
import 'package:livekit_client/livekit_client.dart';

class ConnectionResilienceController {
  // Configurable thresholds for testing
  final int poorQualityTriggerSeconds;
  final int promptCooldownSeconds;

  ConnectionResilienceController({
    this.poorQualityTriggerSeconds = 10,
    this.promptCooldownSeconds = 60,
  });

  // ── Error Classification ──────────────────────────────────────────────────

  /// Determines if a connection failure warrants a retry using ICE relay.
  /// True if it's a network/timeout issue. False if it's an auth/config issue.
  bool shouldRetryWithRelay(Object error) {
    if (error is ConnectException) {
      if (error.reason == ConnectionErrorReason.NotAllowed) {
        return false; // Bad token or permissions
      }
      return true; // Likely a timeout or internal server error
    }

    if (error is TimeoutException || error is NegotiationError) {
      return true; // Pure network timeout or ICE failure
    }

    if (error is LiveKitE2EEException) {
      return false; // Key issue, relay won't help
    }

    // Default to true for unknown errors (could be a generic socket exception)
    return true; 
  }

  // ── Audio-Only Hysteresis State Machine ───────────────────────────────────

  Timer? _poorQualityTimer;
  DateTime? _lastPromptTime;
  bool _isPromptActive = false;

  /// Call this whenever a ParticipantConnectionQualityUpdatedEvent fires.
  /// [onTriggerPrompt] is a callback that displays the dialog to the user.
  void handleConnectionQualityUpdate(
    ConnectionQuality quality,
    void Function() onTriggerPrompt,
  ) {
    if (quality == ConnectionQuality.poor) {
      // Start or continue the timer
      if (_poorQualityTimer == null || !_poorQualityTimer!.isActive) {
        _poorQualityTimer = Timer(
          Duration(seconds: poorQualityTriggerSeconds),
          () => _evaluatePrompt(onTriggerPrompt),
        );
      }
    } else {
      // If quality recovers to good/excellent, cancel the timer
      _poorQualityTimer?.cancel();
    }
  }

  void _evaluatePrompt(void Function() onTriggerPrompt) {
    if (_isPromptActive) return;

    final now = DateTime.now();
    if (_lastPromptTime != null) {
      final secondsSinceLast = now.difference(_lastPromptTime!).inSeconds;
      if (secondsSinceLast < promptCooldownSeconds) {
        return; // Still in cooldown
      }
    }

    _isPromptActive = true;
    _lastPromptTime = now;
    onTriggerPrompt();
  }

  /// Call this when the user dismisses or accepts the prompt
  void onPromptClosed() {
    _isPromptActive = false;
  }

  void dispose() {
    _poorQualityTimer?.cancel();
  }
}
