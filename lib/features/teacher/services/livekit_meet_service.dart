import 'package:flutter/material.dart';
import 'package:calligro_app/features/meet/logic/meet_backend.dart';
import 'package:calligro_app/features/meet/pages/calligro_pre_join_page.dart';
import 'package:calligro_app/core/services/meet_debug_service.dart';

/// Builds the screen shown after a token is received (overridable in tests,
/// because the real pre-join page needs Firebase Auth and the camera).
typedef PreJoinPageBuilder = Widget Function(MeetToken token, String courseId, bool isTeacher);

class LiveKitMeetService {
  static final LiveKitMeetService _instance = LiveKitMeetService._internal();
  factory LiveKitMeetService() => _instance;
  LiveKitMeetService._internal() : _call = null, _preJoinBuilder = null;

  final MeetCallable? _call;
  final PreJoinPageBuilder? _preJoinBuilder;

  @visibleForTesting
  LiveKitMeetService.forTest({MeetCallable? call, PreJoinPageBuilder? preJoinBuilder})
      : _call = call,
        _preJoinBuilder = preJoinBuilder;

  bool _isJoining = false;

  Future<void> joinMeeting({
    required BuildContext context,
    required String courseId,
    bool isTeacher = false,
  }) async {
    if (_isJoining) {
      MeetDebugService().log("⚠️ joinMeeting called but _isJoining is already true (ignored double-tap)");
      return;
    }
    _isJoining = true;

    bool dialogShowing = false;
    try {
      MeetDebugService().log("🟢 joinMeeting started for course $courseId");
      dialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFEBB937)),
        ),
      );

      MeetDebugService().log("⏳ Requesting LiveKit token...");
      final meetToken = await MeetBackend(courseId: courseId, call: _call).fetchToken();

      if (dialogShowing && context.mounted) {
        dialogShowing = false;
        MeetDebugService().log("✅ Token received, popping loading dialog");
        Navigator.pop(context); // Close loading
      }

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _preJoinBuilder?.call(meetToken, courseId, isTeacher) ??
              CalligroPreJoinPage(
                token: meetToken.token,
                serverUrl: meetToken.serverUrl,
                roomName: meetToken.roomName,
                courseId: courseId,
                isTeacher: isTeacher,
                teacherId: meetToken.teacherId,
              ),
        ),
      );
    } catch (e) {
      MeetDebugService().log("❌ Token generation failed: $e. Popping top route.");
      if (dialogShowing && context.mounted) {
        dialogShowing = false;
        Navigator.pop(context); // Close loading if error
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join secure classroom: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isJoining = false;
      MeetDebugService().log("🏁 joinMeeting finished");
    }
  }
}
