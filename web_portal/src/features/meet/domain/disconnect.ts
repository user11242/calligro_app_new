/**
 * What the website does when it is disconnected from a class. Same rule as the app
 * (lib/features/meet/domain/meet_policies.dart DisconnectPolicy): only a NETWORK
 * problem is worth reconnecting (once, through the relay); a class that ended, a
 * removal by the teacher or our own "Leave" is final.
 *
 * Takes LiveKit's DisconnectReason NAME (e.g. "ROOM_DELETED") so this stays free of
 * the LiveKit library.
 */
const FINAL_REASONS = new Set([
  "CLIENT_INITIATED", // we left
  "ROOM_DELETED", // the teacher ended the class
  "ROOM_CLOSED",
  "PARTICIPANT_REMOVED", // removed by the teacher / an admin
  "USER_REJECTED",
]);

/** True if this disconnect may be a network problem worth one relay retry. */
export function shouldRetryWithRelay(reasonName: string | undefined, currentPolicy: "all" | "relay"): boolean {
  if (currentPolicy !== "all") return false; // already on the relay: no loop
  return !FINAL_REASONS.has(reasonName ?? "UNKNOWN_REASON");
}
