/**
 * The Calligro Meet contract with the APP (../test/fixtures/meet_messages.json):
 * the app's tests run the same cases, so web ↔ app classes keep working.
 */
import { describe, it, expect } from "vitest";
import fs from "fs";
import path from "path";
import { decideMeetAction, MeetMessages } from "../../../src/features/meet/domain/meetMessages";

const contract = JSON.parse(fs.readFileSync(path.join(__dirname, "../../../../test/fixtures/meet_messages.json"), "utf8"));
const isModeratorMeta = (m: string | null) => {
  try {
    return JSON.parse(m || "{}").role === "moderator";
  } catch {
    return false;
  }
};

describe("every message the app and the website exchange means the same here", () => {
  for (const c of contract.cases) {
    const sender = contract.senders[c.from];
    for (const [receiverName, expected] of Object.entries(c.expect as Record<string, string>)) {
      it(`${c.name} → ${receiverName}: ${expected}`, () => {
        const r = contract.receivers[receiverName];
        const action = decideMeetAction(c.message, {
          senderIdentity: sender.identity ?? undefined,
          senderIsModerator: sender.identity != null && isModeratorMeta(sender.metadata),
          localIdentity: r.identity,
          isTeacher: r.isTeacher,
          isModerator: r.isModerator,
        });
        expect(action.kind).toBe(expected);
      });
    }
  }
});

describe("what the website SENDS is exactly what the app expects", () => {
  it("builders", () => {
    const sent = contract.sent.web;
    expect(MeetMessages.raiseHand("Sara")).toEqual(sent.raiseHand);
    expect(MeetMessages.lowerHand("Sara")).toEqual(sent.lowerHand);
    expect(MeetMessages.forceLowerHand("s1")).toEqual(sent.forceLowerHand);
    expect(MeetMessages.muteAll()).toEqual(sent.muteAll);
    expect(MeetMessages.moderate("mute_mic", "s1")).toEqual(sent.muteMic);
    expect(MeetMessages.moderate("mute_camera", "s1")).toEqual(sent.muteCamera);
    expect(MeetMessages.moderate("kick", "s1")).toEqual(sent.kick);
  });
});

describe("website-only messages (the whiteboard)", () => {
  const teacher = { senderIdentity: "T1", senderIsModerator: true, localIdentity: "s1", isTeacher: false, isModerator: false };
  const student = { ...teacher, senderIdentity: "s2", senderIsModerator: false };
  it("the teacher's whiteboard, its mode and the protractor reach students", () => {
    expect(decideMeetAction({ cmd: "toggle_whiteboard", state: true, mode: "calligraphy" }, teacher)).toEqual({ kind: "whiteboard", active: true, mode: "calligraphy" });
    expect(decideMeetAction({ cmd: "set_whiteboard_mode", mode: "standard" }, teacher)).toEqual({ kind: "whiteboardMode", mode: "standard" });
    expect(decideMeetAction({ type: "PROTRACTOR_STATE", active: true, angle: 30 }, teacher)).toEqual({ kind: "protractor", active: true, angle: 30 });
  });
  it("a student cannot control them", () => {
    expect(decideMeetAction({ cmd: "toggle_whiteboard", state: true }, student).kind).toBe("ignored");
    expect(decideMeetAction({ type: "PROTRACTOR_STATE", active: true }, student).kind).toBe("ignored");
  });
  it("the app's 'show student work' messages are ignored safely on the website", () => {
    expect(decideMeetAction({ type: "work_show", shareId: "x" }, teacher).kind).toBe("ignored");
  });
});
