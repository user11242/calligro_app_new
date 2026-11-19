/**
 * The ONE "buy" step in the browser (the course page and the checkout page each
 * had their own copy): ask the server for a Whop checkout and say what happened.
 */
import { describe, it, expect, vi } from "vitest";
import { requestWhopCheckout } from "../../../src/features/payments/application/whopCheckout";
import { isEnrolled } from "../../../src/features/payments/domain/enrolment";

const reply = (status: number, body: unknown) =>
  vi.fn(async () => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } }));

describe("requestWhopCheckout", () => {
  it("sends the course and the buyer to OUR server, and returns Whop's page to go to", async () => {
    const fetchImpl = reply(200, { success: true, id: "ch_1", purchaseUrl: "https://whop.com/checkout/ch_1" });
    const r = await requestWhopCheckout({ courseId: "c1", userId: "s1" }, fetchImpl);
    expect(r).toEqual({ kind: "redirect", url: "https://whop.com/checkout/ch_1" });
    const [url, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe("/api/whop/create-checkout");
    expect(init.method).toBe("POST");
    expect(JSON.parse(String(init.body))).toEqual({ courseId: "c1", userId: "s1" });
  });

  it("refused before paying (full, already in, not open yet): the message key to show", async () => {
    for (const [code, key] of [
      ["course_full", "checkout.blocked_full"],
      ["already_enrolled", "checkout.blocked_enrolled"],
      ["commission_not_set", "checkout.blocked_unavailable"],
    ]) {
      const r = await requestWhopCheckout({ courseId: "c1", userId: "s1" }, reply(409, { error: code, code }));
      expect(r).toEqual({ kind: "blocked", messageKey: key });
    }
  });

  it("server errors keep their message (string or object), as before", async () => {
    expect(await requestWhopCheckout({ courseId: "c1", userId: "s1" }, reply(500, { error: "WHOP_API_KEY is not configured" })))
      .toEqual({ kind: "error", message: "WHOP_API_KEY is not configured" });
    expect(await requestWhopCheckout({ courseId: "c1", userId: "s1" }, reply(500, { error: { message: "Whop down" } })))
      .toEqual({ kind: "error", message: "Whop down" });
    expect(await requestWhopCheckout({ courseId: "c1", userId: "s1" }, reply(200, { success: true })))
      .toEqual({ kind: "error", message: "Failed to initialize checkout" });
  });

  it("no network: an error, never a crash", async () => {
    const fetchImpl = vi.fn(async () => { throw new Error("offline"); });
    expect(await requestWhopCheckout({ courseId: "c1", userId: "s1" }, fetchImpl)).toEqual({ kind: "error", message: "offline" });
  });
});

describe("isEnrolled", () => {
  it("only when the student's id is in the course's list", () => {
    expect(isEnrolled({ enrolledStudents: ["s1", "s2"] }, "s1")).toBe(true);
    expect(isEnrolled({ enrolledStudents: ["s2"] }, "s1")).toBe(false);
    expect(isEnrolled({}, "s1")).toBe(false);
    expect(isEnrolled(null, "s1")).toBe(false);
    expect(isEnrolled({ enrolledStudents: ["s1"] }, undefined)).toBe(false);
  });
});
