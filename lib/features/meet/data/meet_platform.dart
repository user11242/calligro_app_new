import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:calligro_app/core/services/security_service.dart';

import '../domain/meet_room.dart' show MeetSound;

/// Device services the meet screen needs (screen on, landscape, background audio,
/// screenshot protection, sounds). Behind an interface so widget tests can run
/// without native plugins.
abstract interface class MeetPlatform {
  /// Entering the class screen: keep screen on, landscape, block screenshots.
  Future<void> enterMeeting();

  /// Connected: keep class audio alive in the background.
  Future<void> startBackgroundAudio();

  /// Leaving the class screen: undo everything above.
  Future<void> exitMeeting();

  Future<void> playSound(MeetSound sound);
}

// Top-level callback required by flutter_foreground_task (the service only needs to stay alive).
@pragma('vm:entry-point')
void meetForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isServiceState) async {}
}

class DeviceMeetPlatform implements MeetPlatform {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> enterMeeting() async {
    WakelockPlus.enable();
    // Calligro Meet is landscape-only.
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
    SecurityService().enableScreenshotProtection();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'calligro_live_class',
        channelName: 'Live Class Audio',
        channelDescription: 'Keeps the class audio alive in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: true, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  Future<void> startBackgroundAudio() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'Live Class Active',
      notificationText: 'Audio is running in the background.',
      callback: meetForegroundTaskCallback,
    );
  }

  @override
  Future<void> exitMeeting() async {
    SecurityService().disableScreenshotProtection();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    FlutterForegroundTask.stopService();
    await _player.dispose();
  }

  @override
  Future<void> playSound(MeetSound sound) async {
    try {
      await _player.play(AssetSource(sound == MeetSound.join ? 'sounds/join.wav' : 'sounds/leave.wav'));
    } catch (_) {
      // Sounds are best-effort.
    }
  }
}
