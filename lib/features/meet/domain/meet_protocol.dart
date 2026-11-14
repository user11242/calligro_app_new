import 'dart:convert';
import 'dart:typed_data';

/// Calligro Meet data-channel wire protocol.
///
/// These exact strings are shared with the web portal
/// (web_portal/src/components/meet/*). Changing one here without changing it
/// there breaks cross-client classes — the protocol tests pin every value.
class MeetProtocol {
  MeetProtocol._();

  // `cmd` messages
  static const raiseHand = 'raise_hand';
  static const lowerHand = 'lower_hand';
  static const forceLowerHand = 'force_lower_hand';
  static const muteAll = 'mute_all';

  // `type` messages
  static const endMeetingForAll = 'end_meeting_for_all';
  static const kickParticipant = 'kick_participant';
  static const forceMuteMic = 'force_mute_mic';
  static const forceMuteCamera = 'force_mute_camera';

  // ── Outgoing message builders ─────────────────────────────────────────
  static Map<String, dynamic> raiseHandMessage(String name) => {'cmd': raiseHand, 'name': name};
  static Map<String, dynamic> lowerHandMessage(String name) => {'cmd': lowerHand, 'name': name};
  static Map<String, dynamic> forceLowerHandMessage(String targetId) =>
      {'cmd': forceLowerHand, 'targetId': targetId};
  static Map<String, dynamic> endMeetingMessage() => {'type': endMeetingForAll};
  static Map<String, dynamic> kickMessage(String targetId) => {'type': kickParticipant, 'targetId': targetId};
  static Map<String, dynamic> muteMessage(String targetId, {required bool mic}) =>
      {'type': mic ? forceMuteMic : forceMuteCamera, 'targetId': targetId};

  static Uint8List encode(Map<String, dynamic> message) => Uint8List.fromList(utf8.encode(jsonEncode(message)));

  /// Decodes a data packet. Returns null for anything that is not a JSON object
  /// (binary noise, invalid UTF-8, arrays, plain strings…).
  static Map<String, dynamic>? tryDecode(List<int> data) {
    try {
      final decoded = jsonDecode(utf8.decode(data));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Display name used when this participant announces a hand change.
  static String displayName(String name, String identity) =>
      name.isNotEmpty ? name : (identity.isNotEmpty ? identity : 'Student');
}

/// Decides whether a data-message sender may issue teacher-only commands.
///
/// Trust comes from two server-controlled sources only:
///  * the participant identity (`<teacherId>` or `<teacherId>_mobile`), and
///  * the token metadata `role == "moderator"`, which students cannot change
///    because the server issues tokens with `canUpdateOwnMetadata: false`.
///
/// An unknown sender (null identity) is never trusted.
class MeetSenderVerifier {
  MeetSenderVerifier._();

  static bool isTeacherOrModerator({
    required String? identity,
    required String? metadata,
    required String? teacherId,
  }) {
    if (identity == null) return false;
    final tid = teacherId;
    if (tid != null && tid.isNotEmpty) {
      if (identity == tid || identity == '${tid}_mobile') return true;
    }
    final meta = parseMetadata(metadata);
    if (meta != null && meta['role'] == 'moderator') {
      // A moderator token for a DIFFERENT course's teacher is not trusted here.
      if (tid != null && tid.isNotEmpty && meta['teacherId'] != null) {
        return meta['teacherId'] == tid;
      }
      return true;
    }
    return false;
  }

  /// True when participant metadata marks a moderator (teacher/admin).
  static bool isModeratorMetadata(String? metadata) => parseMetadata(metadata)?['role'] == 'moderator';

  static Map<String, dynamic>? parseMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return null;
    try {
      final decoded = jsonDecode(metadata);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Avatar URL from metadata, or null when missing/empty/"null".
  static String? avatarFromMetadata(String? metadata) {
    final avatar = parseMetadata(metadata)?['avatar'];
    if (avatar is! String || avatar.isEmpty || avatar == 'null') return null;
    return avatar;
  }
}
