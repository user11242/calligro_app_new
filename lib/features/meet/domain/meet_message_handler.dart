import 'meet_protocol.dart';
import 'shared_work.dart';

/// What the meet page must do in response to one incoming data message.
///
/// The handler only DECIDES; the page performs the side effects (state changes,
/// snackbars, muting, leaving). This keeps every security and protocol decision
/// testable without a LiveKit room.
sealed class MeetAction {
  const MeetAction();
}

/// Drop the message. [reason] explains why (for logs and tests).
class IgnoreMessage extends MeetAction {
  final IgnoreReason reason;
  const IgnoreMessage(this.reason);
}

enum IgnoreReason {
  malformed,
  unknownSender,
  unauthorizedSender,
  missingTarget,
  notForMe,
  notApplicableToTeacher,
  unknownCommand,
}

/// A participant raised their hand (they announced it themselves).
class HandRaised extends MeetAction {
  final String identity;
  final String name;
  const HandRaised(this.identity, this.name);
}

/// A participant lowered their own hand. [isSelf] → reset our own button.
class HandLowered extends MeetAction {
  final String identity;
  final bool isSelf;
  const HandLowered(this.identity, {required this.isSelf});
}

/// The teacher lowered [targetId]'s hand. [isSelf] → we must reset our button
/// and re-broadcast `lower_hand` so every client stays in sync.
class HandForceLowered extends MeetAction {
  final String targetId;
  final bool isSelf;
  const HandForceLowered(this.targetId, {required this.isSelf});
}

/// The teacher ended the class for everyone → leave.
class MeetingEndedByTeacher extends MeetAction {
  const MeetingEndedByTeacher();
}

/// The teacher muted all students → turn our mic off.
class MutedByMuteAll extends MeetAction {
  const MutedByMuteAll();
}

/// The teacher muted our mic.
class MicMutedByTeacher extends MeetAction {
  const MicMutedByTeacher();
}

/// The teacher turned our camera off.
class CameraDisabledByTeacher extends MeetAction {
  const CameraDisabledByTeacher();
}

/// The teacher removed us → leave (the server also disconnects us).
class KickedByTeacher extends MeetAction {
  const KickedByTeacher();
}

/// The teacher changed the shared student work (show, page, zoom, drawing, stop).
class SharedWorkUpdate extends MeetAction {
  final SharedWorkMessage message;
  const SharedWorkUpdate(this.message);
}

/// Pure decision logic for incoming Calligro Meet data messages.
class MeetMessageHandler {
  /// Our own LiveKit identity (null while the room is not connected yet).
  final String? localIdentity;
  final bool isTeacher;
  final String? teacherId;

  const MeetMessageHandler({
    required this.localIdentity,
    required this.isTeacher,
    required this.teacherId,
  });

  MeetAction handle(
    List<int> data, {
    required String? senderIdentity,
    required String? senderMetadata,
  }) {
    final msg = MeetProtocol.tryDecode(data);
    if (msg == null) return const IgnoreMessage(IgnoreReason.malformed);

    final cmd = msg['cmd'];
    final type = msg['type'];
    bool fromModerator() => MeetSenderVerifier.isTeacherOrModerator(
          identity: senderIdentity,
          metadata: senderMetadata,
          teacherId: teacherId,
        );

    // ── Hand raising (participants speak for themselves) ──────────────
    if (cmd == MeetProtocol.raiseHand || cmd == MeetProtocol.lowerHand) {
      // The hand belongs to the SENDER, so an unknown sender can't be attributed.
      if (senderIdentity == null) return const IgnoreMessage(IgnoreReason.unknownSender);
      if (cmd == MeetProtocol.raiseHand) {
        final name = msg['name'];
        return HandRaised(senderIdentity, name is String && name.isNotEmpty ? name : 'Student');
      }
      return HandLowered(senderIdentity, isSelf: senderIdentity == localIdentity);
    }

    // ── Teacher-only commands ─────────────────────────────────────────
    if (cmd == MeetProtocol.forceLowerHand) {
      if (!fromModerator()) return const IgnoreMessage(IgnoreReason.unauthorizedSender);
      final target = msg['targetId'];
      if (target is! String || target.isEmpty) return const IgnoreMessage(IgnoreReason.missingTarget);
      return HandForceLowered(target, isSelf: target == localIdentity);
    }

    // ── Shared student work: only the course teacher puts things on everyone's screen ──
    if (MeetProtocol.sharedWorkTypes.contains(type)) {
      if (!fromModerator()) return const IgnoreMessage(IgnoreReason.unauthorizedSender);
      final parsed = SharedWorkMessage.parse(msg);
      return parsed == null ? const IgnoreMessage(IgnoreReason.malformed) : SharedWorkUpdate(parsed);
    }

    if (type == MeetProtocol.endMeetingForAll) {
      if (!fromModerator()) return const IgnoreMessage(IgnoreReason.unauthorizedSender);
      return const MeetingEndedByTeacher();
    }

    if (cmd == MeetProtocol.muteAll) {
      if (!fromModerator()) return const IgnoreMessage(IgnoreReason.unauthorizedSender);
      if (isTeacher) return const IgnoreMessage(IgnoreReason.notApplicableToTeacher);
      return const MutedByMuteAll();
    }

    const targeted = {
      MeetProtocol.kickParticipant,
      MeetProtocol.forceMuteMic,
      MeetProtocol.forceMuteCamera,
    };
    if (targeted.contains(type)) {
      final target = msg['targetId'];
      if (target is! String || target.isEmpty) return const IgnoreMessage(IgnoreReason.missingTarget);
      if (localIdentity == null || target != localIdentity) return const IgnoreMessage(IgnoreReason.notForMe);
      if (!fromModerator()) return const IgnoreMessage(IgnoreReason.unauthorizedSender);
      switch (type) {
        case MeetProtocol.kickParticipant:
          return const KickedByTeacher();
        case MeetProtocol.forceMuteMic:
          return const MicMutedByTeacher();
        default:
          return const CameraDisabledByTeacher();
      }
    }

    return const IgnoreMessage(IgnoreReason.unknownCommand);
  }
}
