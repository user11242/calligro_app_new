import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:calligro_app/features/meet/pages/calligro_pre_join_page.dart';
import 'package:calligro_app/core/services/meet_debug_service.dart';

class LiveKitMeetService {
  static final LiveKitMeetService _instance = LiveKitMeetService._internal();
  factory LiveKitMeetService() => _instance;
  LiveKitMeetService._internal();

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

    try {
      MeetDebugService().log("🟢 joinMeeting started for course $courseId");
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFEBB937)),
        ),
      );

      MeetDebugService().log("⏳ Requesting LiveKit token...");
      final result = await FirebaseFunctions.instance
          .httpsCallable('livekit-generateLiveKitToken')
          .call({'courseId': courseId});

      MeetDebugService().log("✅ Token received, popping loading dialog");
      Navigator.pop(context); // Close loading

      final data = result.data as Map<dynamic, dynamic>;
      final token = data['token'] as String;
      final serverUrl = data['serverUrl'] as String;
      final roomName = data['roomName'] as String;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CalligroPreJoinPage(
            token: token,
            serverUrl: serverUrl,
            roomName: roomName,
            courseId: courseId,
            isTeacher: isTeacher,
          ),
        ),
      );
    } catch (e) {
      MeetDebugService().log("❌ Token generation failed: $e. Popping top route.");
      Navigator.pop(context); // Close loading if error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join secure classroom: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isJoining = false;
      MeetDebugService().log("🏁 joinMeeting finished");
    }
  }
}
