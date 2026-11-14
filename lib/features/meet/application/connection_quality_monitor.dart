import 'dart:async';

import '../domain/meet_room.dart';

/// Offers audio-only mode when OUR connection stays poor for a while
/// (hysteresis: a short dip doesn't trigger it; one prompt per cooldown).
class ConnectionQualityMonitor {
  final int poorQualityTriggerSeconds;
  final int promptCooldownSeconds;

  ConnectionQualityMonitor({
    this.poorQualityTriggerSeconds = 10,
    this.promptCooldownSeconds = 60,
  });

  // ── Audio-Only Hysteresis State Machine ───────────────────────────────────

  Timer? _poorQualityTimer;
  DateTime? _lastPromptTime;
  bool _isPromptActive = false;

  /// Call this whenever a ParticipantConnectionQualityUpdatedEvent fires.
  /// [onTriggerPrompt] is a callback that displays the dialog to the user.
  void handleConnectionQualityUpdate(
    MeetConnectionQuality quality,
    void Function() onTriggerPrompt,
  ) {
    if (quality == MeetConnectionQuality.poor) {
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
