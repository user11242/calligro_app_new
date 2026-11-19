/**
 * Calligro Meet messages between the website and the app (LiveKit data messages, JSON,
 * default channel). Pure rules only: the UI decodes a message, asks `decideMeetAction`
 * what it means for THIS user, then does it.
 *
 * The same contract (../../../../../test/fixtures/meet_messages.json) is checked by the
 * app's tests (lib/features/meet/domain/meet_message_handler.dart) and by
 * tests/features/meet/meet_contract.test.ts, so the two sides cannot drift apart.
 */

export type MeetMessage = Record<string, unknown>;

export interface MeetReceiver {
  /** Who sent it (LiveKit identity); undefined if the SDK does not know them yet. */
  senderIdentity?: string;
  /** The sender's token role is "moderator" (teacher or admin). Set by the server, not forgeable. */
  senderIsModerator: boolean;
  /** Me. */
  localIdentity: string;
  isTeacher: boolean;
  /** I am a moderator (teacher or admin). */
  isModerator: boolean;
}

export type MeetAction =
  | { kind: "handRaised"; name: string; identity?: string }
  | { kind: "handLowered"; identity?: string }
  | { kind: "handForceLowered"; targetId: string }
  | { kind: "mutedAll" }
  | { kind: "micMuted" }
  | { kind: "cameraDisabled" }
  | { kind: "kicked" }
  | { kind: "meetingEnded" }
  | { kind: "whiteboard"; active: boolean; mode?: "standard" | "calligraphy" }
  | { kind: "whiteboardMode"; mode: "standard" | "calligraphy" }
  | { kind: "protractor"; active: boolean; angle?: number }
  | { kind: "ignored"; reason: "notFromModerator" | "notForMe" | "unknown" };

const isMuteMic = (d: MeetMessage) => d.cmd === "mute_student" || d.type === "force_mute_mic";
const isMuteCamera = (d: MeetMessage) => d.cmd === "disable_camera" || d.type === "force_mute_camera";
const isKick = (d: MeetMessage) => d.cmd === "kick_student" || d.type === "kick_participant";

/** Commands only a teacher or admin may send. */
function isModeratorOnly(d: MeetMessage): boolean {
  return (
    d.cmd === "force_lower_hand" ||
    d.cmd === "mute_all" ||
    isMuteMic(d) ||
    isMuteCamera(d) ||
    isKick(d) ||
    d.type === "end_meeting_for_all" ||
    d.cmd === "toggle_whiteboard" ||
    d.cmd === "set_whiteboard_mode" ||
    d.type === "PROTRACTOR_STATE"
  );
}

/** What a received message means for this user. */
export function decideMeetAction(data: MeetMessage, me: MeetReceiver): MeetAction {
  if (isModeratorOnly(data) && !me.senderIsModerator) return { kind: "ignored", reason: "notFromModerator" };

  const forMe = data.identity === me.localIdentity || data.targetId === me.localIdentity;

  if (data.type === "RAISE_HAND" || data.cmd === "raise_hand") {
    return { kind: "handRaised", name: String(data.name ?? ""), identity: me.senderIdentity };
  }
  if (data.cmd === "lower_hand") return { kind: "handLowered", identity: me.senderIdentity };
  if (data.cmd === "force_lower_hand") {
    return data.targetId ? { kind: "handForceLowered", targetId: String(data.targetId) } : { kind: "ignored", reason: "unknown" };
  }
  // "Mute all" is for students: the server never mutes teachers or admins either.
  if (data.cmd === "mute_all") return me.isModerator || me.isTeacher ? { kind: "ignored", reason: "notForMe" } : { kind: "mutedAll" };
  if (isMuteMic(data)) return forMe ? { kind: "micMuted" } : { kind: "ignored", reason: "notForMe" };
  if (isMuteCamera(data)) return forMe ? { kind: "cameraDisabled" } : { kind: "ignored", reason: "notForMe" };
  if (isKick(data)) return forMe ? { kind: "kicked" } : { kind: "ignored", reason: "notForMe" };
  if (data.type === "end_meeting_for_all") return { kind: "meetingEnded" };
  if (data.cmd === "toggle_whiteboard") {
    return { kind: "whiteboard", active: Boolean(data.state), mode: data.mode as "standard" | "calligraphy" | undefined };
  }
  if (data.cmd === "set_whiteboard_mode") return { kind: "whiteboardMode", mode: data.mode as "standard" | "calligraphy" };
  if (data.type === "PROTRACTOR_STATE") {
    return { kind: "protractor", active: Boolean(data.active), angle: data.angle as number | undefined };
  }
  return { kind: "ignored", reason: "unknown" };
}

export type ModerationMessageAction = "mute_mic" | "mute_camera" | "kick";

/** What the website sends. `cmd` aliases are kept so older website clients still understand. */
export const MeetMessages = {
  raiseHand: (name: string) => ({ cmd: "raise_hand", name }),
  lowerHand: (name: string) => ({ cmd: "lower_hand", name }),
  forceLowerHand: (targetId: string) => ({ cmd: "force_lower_hand", targetId }),
  muteAll: () => ({ cmd: "mute_all" }),
  moderate: (action: ModerationMessageAction, targetId: string) => {
    if (action === "mute_mic") return { targetId, type: "force_mute_mic", cmd: "mute_student" };
    if (action === "mute_camera") return { targetId, type: "force_mute_camera", cmd: "disable_camera" };
    return { targetId, type: "kick_participant", cmd: "kick_student" };
  },
  whiteboard: (state: boolean, mode: "standard" | "calligraphy") => ({ cmd: "toggle_whiteboard", state, mode }),
  whiteboardMode: (mode: "standard" | "calligraphy") => ({ cmd: "set_whiteboard_mode", mode }),
  protractor: (active: boolean, angle: number) => ({ type: "PROTRACTOR_STATE", active, angle }),
};

/** Encode a message for LiveKit's `send`. */
export const encodeMeetMessage = (m: object) => new TextEncoder().encode(JSON.stringify(m));
