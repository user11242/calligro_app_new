import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';

class JitsiMeetService {
  static final JitsiMeetService _instance = JitsiMeetService._internal();
  factory JitsiMeetService() => _instance;
  JitsiMeetService._internal();

  final JitsiMeet _jitsiMeet = JitsiMeet();
  Timer? _heartbeatTimer;

  /// Helper: Hash room name to match Web Portal (SHA-256)
  String _hashRoomName(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Launches a branded Jitsi Meet conference.
  Future<void> joinMeeting({
    required String courseId,
    required String roomName, // This is the calligroMeetLink from Firestore
    required String userName,
    required String userEmail,
    required String userId,
    String? avatarUrl,
    String? password,
    bool isModerator = false,
  }) async {
    try {
      // 🛡️ SECURITY: Hash the room name to match the Web Portal
      // Logic: SHA256("Calligro_${id}_${baseRoom}_${today}_SecureSalt2026")
      // 🛡️ CRITICAL: Must use .toUtc() to match Web Portal's new Date().toISOString()
      // JavaScript's toISOString() ALWAYS returns UTC, while Dart's toIso8601String()
      // returns LOCAL time. Without .toUtc(), the date component differs between
      // midnight and 3 AM in GMT+3 timezones, causing different room hashes.
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final rawSeed = "Calligro_${courseId}_${roomName}_${today}_SecureSalt2026";
      final hashed = _hashRoomName(rawSeed);
      final secureRoomName = "CG_${hashed.substring(0, 40)}";
      
      debugPrint("Joining Secure Jitsi Meeting: $secureRoomName on meet.element.io");

      // 🛡️ SECURITY: Unforgeable display name with short UID tag
      final myUniqueTag = userId.length >= 8 ? "[${userId.substring(0, 8)}]" : "[${userId}]";
      final jitsiDisplayName = "$userName ${isModerator ? "(Admin)" : ""} $myUniqueTag";

      final teacherButtons = [
        'microphone', 'camera', 'closedcaptions', 'desktop', 'fullscreen',
        'fodeviceselection', 'hangup', 'profile', 'chat', 'recording',
        'livestreaming', 'etherpad', 'sharedvideo', 'settings', 'raisehand',
        'videoquality', 'filmstrip', 'feedback', 'stats', 'shortcuts',
        'tileview', 'videobackgroundblur', 'download', 'help',
        'security', 'participants-pane'
      ];

      const studentButtons = [
        'microphone', 'camera', 'chat', 'raisehand', 'tileview', 'hangup', 'fullscreen', 'participants-pane'
      ];

      var options = JitsiMeetConferenceOptions(
        serverURL: "https://meet.element.io", 
        room: secureRoomName,
        configOverrides: {
          "startWithAudioMuted": true,
          "startWithVideoMuted": true,
          "subject": " ",
          "hideConferenceSubject": true,
          "prejoinPageEnabled": false,
          "lobbyModeEnabled": false,
          "disableLobby": true,
          "disableInviteFunctions": true,  // 🔒 SECURITY: no sharing room links
          "doNotStoreRoom": true,           // 🔒 SECURITY: room not saved on server
          "toolbarButtons": isModerator ? teacherButtons : studentButtons,
          "disableRemoteMute": !isModerator,

          // ═══ VIDEO QUALITY ═══
          "resolution": 720,
          "preferredCodec": "H264",
          "disableH264": false,
          "disableSimulcast": false,
          "channelLastN": 4,

          // ═══ P2P (Direct device-to-device when only 2 people) ═══
          // When teacher + 1 student: video skips the server entirely
          // → sharper image, lower latency, less bandwidth usage
          "p2p.enabled": true,
          "p2p.preferredCodec": "H264",

          // ═══ BANDWIDTH OPTIMISATION ═══
          // Pause encoding for participants not currently on screen
          "enableLayerSuspension": true,
          // Keep full 720p only for the 2 most active speakers
          "maxFullResolutionParticipants": 2,
          "startBitrate": 1500,

          // ═══ AUDIO QUALITY ═══
          "opusMaxAverageBitrate": 128000,
          "enableOpusDtx": true,
          "disableAP": false,
          "enableNoisyMicDetection": true,
          "disableNS": false,
          "disableAEC": false,
          "disableAGC": false,
          "disableHPF": false,

          // ═══ UX: Remove distracting join/leave popup notifications ═══
          "notifications": [],

          // ═══ PRIVACY: Disable call quality reporting to third parties ═══
          "callStatsID": "",
        },
        featureFlags: {
          "invite.enabled": false,
          "meeting-info.enabled": false,
          "copy-link.enabled": false,
          "help.enabled": false,
          "welcomepage.enabled": false,
          "security-options.enabled": isModerator,
          "chat.enabled": true,
          "raise-hand.enabled": true,
          "logo.enabled": false, 
          "kick-out.enabled": isModerator,
          "moderator.enabled": isModerator,
          "pip.enabled": true, // Back button minimizes to PiP instead of leaving
        },
        userInfo: JitsiMeetUserInfo(
          displayName: jitsiDisplayName,
          email: userEmail,
          avatar: avatarUrl,
        ),
      );

      // 🛡️ Start Heartbeat (Fix #3 from Audit)
      _startHeartbeat(courseId, userId, userName);

      await _jitsiMeet.join(
        options,
        JitsiMeetEventListener(
          conferenceTerminated: (url, error) {
            _stopHeartbeat(courseId, userId);
          },
          readyToClose: () {
            _stopHeartbeat(courseId, userId);
          },
        ),
      );

      // 🔐 Handle Password Injection if needed (SDK handle password differently)
      // Note: If Jitsi prompts for password, the user will enter it.
      // Automatic password injection in Mobile SDK is usually via options or a separate command.
      
    } catch (error) {
      debugPrint("Error joining Jitsi meeting: $error");
    }
  }

  void _startHeartbeat(String courseId, String userId, String userName) {
    _heartbeatTimer?.cancel();
    
    final docRef = FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .collection('meetingPresence')
        .doc(userId);

    // Initial write
    docRef.set({
      'uid': userId,
      'name': userName,
      'lastHeartbeat': FieldValue.serverTimestamp(),
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Periodic heartbeat (every 25 seconds)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      docRef.update({
        'lastHeartbeat': FieldValue.serverTimestamp(),
      }).catchError((e) => debugPrint("Heartbeat failed: $e"));
    });
  }

  void _stopHeartbeat(String courseId, String userId) {
    _heartbeatTimer?.cancel();
    FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .collection('meetingPresence')
        .doc(userId)
        .delete()
        .catchError((e) => debugPrint("Failed to remove presence: $e"));
  }
}
