import { getFunctions, httpsCallable } from "firebase/functions";
import type { Participant } from "livekit-client";
import { app } from "@/lib/firebase";

/**
 * True if a data message's sender is a moderator (teacher/admin).
 *
 * `metadata.role` is written server-side into the LiveKit token and participants
 * cannot change it (canUpdateOwnMetadata: false), so it is a trustworthy role source.
 * A missing sender is NOT trusted: our server never sends data messages, and the SDK can
 * leave the sender undefined when it has not registered a just-joined participant yet.
 */
export function isFromModerator(sender: Participant | undefined): boolean {
  if (!sender) return false;
  try {
    return JSON.parse(sender.metadata || "{}").role === "moderator";
  } catch {
    return false;
  }
}

export type ModerationAction = "mute_mic" | "mute_camera" | "kick" | "mute_all" | "end_room";

/** Enforce a moderation action on the LiveKit server (cannot be ignored by a modified client). */
export async function moderateOnServer(courseId: string, action: ModerationAction, targetIdentity?: string) {
  const call = httpsCallable(getFunctions(app), "livekit-moderateParticipant");
  return call({ courseId, action, ...(targetIdentity ? { targetIdentity } : {}) });
}
