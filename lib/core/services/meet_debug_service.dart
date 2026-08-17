import 'package:flutter/foundation.dart';

/// A global singleton that persists LiveKit debug logs across navigation.
/// Logs survive when the meeting page is popped, so you can read them
/// from the course details page after a disconnect.
class MeetDebugService extends ChangeNotifier {
  static final MeetDebugService _instance = MeetDebugService._internal();
  factory MeetDebugService() => _instance;
  MeetDebugService._internal();

  final List<MeetLogEntry> _logs = [];
  List<MeetLogEntry> get logs => List.unmodifiable(_logs);

  bool hasLogs = false;

  void log(String message) {
    final entry = MeetLogEntry(
      timestamp: DateTime.now(),
      message: message,
    );
    _logs.add(entry);
    if (_logs.length > 500) _logs.removeAt(0);
    hasLogs = true;
    debugPrint('LK_DEBUG [${entry.formattedTime}] $message');
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    hasLogs = false;
    notifyListeners();
  }
}

class MeetLogEntry {
  final DateTime timestamp;
  final String message;

  MeetLogEntry({required this.timestamp, required this.message});

  String get formattedTime =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}.'
      '${timestamp.millisecond.toString().padLeft(3, '0')}';

  LogLevel get level {
    if (message.contains('🔴') || message.contains('❌')) return LogLevel.error;
    if (message.contains('✅') || message.contains('🟢')) return LogLevel.success;
    if (message.contains('🟡')) return LogLevel.warning;
    if (message.contains('📹') || message.contains('📤') || message.contains('👤')) return LogLevel.info;
    return LogLevel.verbose;
  }
}

enum LogLevel { error, success, warning, info, verbose }
