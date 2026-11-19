import { describe, it, expect } from "vitest";
import { DisconnectReason } from "livekit-client";
import { shouldRetryWithRelay } from "../../../src/features/meet/domain/disconnect";

const name = (r: DisconnectReason) => DisconnectReason[r];

describe("after a disconnect, the website reconnects only for network problems", () => {
  it.each([
    ["the teacher ended the class", DisconnectReason.ROOM_DELETED],
    ["the room was closed", DisconnectReason.ROOM_CLOSED],
    ["the student was removed", DisconnectReason.PARTICIPANT_REMOVED],
    ["the user left", DisconnectReason.CLIENT_INITIATED],
    ["the user was rejected", DisconnectReason.USER_REJECTED],
  ])("%s → never reconnects with the old pass", (_, reason) => {
    expect(shouldRetryWithRelay(name(reason), "all")).toBe(false);
  });

  it.each([
    ["signal lost", DisconnectReason.SIGNAL_CLOSE],
    ["connection timeout", DisconnectReason.CONNECTION_TIMEOUT],
    ["join failure (strict network)", DisconnectReason.JOIN_FAILURE],
    ["media failure", DisconnectReason.MEDIA_FAILURE],
    ["server restart", DisconnectReason.SERVER_SHUTDOWN],
    ["unknown", DisconnectReason.UNKNOWN_REASON],
  ])("%s → one retry through the relay (as before)", (_, reason) => {
    expect(shouldRetryWithRelay(name(reason), "all")).toBe(true);
  });

  it("no reason given → treated as a network problem", () => {
    expect(shouldRetryWithRelay(undefined, "all")).toBe(true);
  });

  it("already on the relay → no second retry (no loop)", () => {
    expect(shouldRetryWithRelay(name(DisconnectReason.SIGNAL_CLOSE), "relay")).toBe(false);
  });
});
