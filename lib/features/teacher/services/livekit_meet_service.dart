import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:calligro_app/features/meet/pages/calligro_meet_page.dart';

class LiveKitMeetService {
  static final LiveKitMeetService _instance = LiveKitMeetService._internal();
  factory LiveKitMeetService() => _instance;
  LiveKitMeetService._internal();

  Future<void> joinMeeting({
    required BuildContext context,
    required String courseId,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFEBB937)),
        ),
      );

      final result = await FirebaseFunctions.instance
          .httpsCallable('livekit-generateLiveKitToken')
          .call({'courseId': courseId});

      Navigator.pop(context); // Close loading

      final data = result.data as Map<dynamic, dynamic>;
      final token = data['token'] as String;
      final serverUrl = data['serverUrl'] as String;
      final roomName = data['roomName'] as String;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CalligroMeetPage(
            token: token,
            serverUrl: serverUrl,
            roomName: roomName,
            courseId: courseId,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading if error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join secure classroom: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
