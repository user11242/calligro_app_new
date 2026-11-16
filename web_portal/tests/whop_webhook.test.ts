import { describe, it, expect } from "vitest";
import crypto from "crypto";
import { verifyWhopSignature, parseWhopPayment, MAX_WEBHOOK_AGE_SECONDS } from "../src/lib/whopWebhook";

// Standard Webhooks signing, as Whop does it.
const SECRET = "ws_test_secret_123";
const NOW = 1_800_000_000;
function sign(body: string, opts: { id?: string; ts?: number; secret?: string } = {}) {
  const id = opts.id ?? "msg_1";
  const ts = opts.ts ?? NOW;
  const key = Buffer.from(opts.secret ?? SECRET, "utf8");
  const sig = crypto.createHmac("sha256", key).update(`${id}.${ts}.${body}`).digest("base64");
  return { "webhook-id": id, "webhook-timestamp": String(ts), "webhook-signature": `v1,${sig}` };
}
const body = JSON.stringify({ type: "payment.succeeded", data: { id: "pay_1", status: "paid", total: 25, currency: "usd", metadata: { courseId: "c1", userId: "s1" } } });

describe("verifyWhopSignature", () => {
  it("accepts a correctly signed webhook", () => {
    expect(verifyWhopSignature(body, sign(body), SECRET, NOW)).toBe(true);
  });
  it("accepts a whsec_ (base64) secret", () => {
    const raw = crypto.randomBytes(24);
    const secret = `whsec_${raw.toString("base64")}`;
    const sig = crypto.createHmac("sha256", raw).update(`msg_1.${NOW}.${body}`).digest("base64");
    const headers = { "webhook-id": "msg_1", "webhook-timestamp": String(NOW), "webhook-signature": `v1,${sig}` };
    expect(verifyWhopSignature(body, headers, secret, NOW)).toBe(true);
  });
  it("accepts when one of several signatures matches (secret rotation)", () => {
    const h = sign(body);
    h["webhook-signature"] = `v1,AAAA ${h["webhook-signature"]}`;
    expect(verifyWhopSignature(body, h, SECRET, NOW)).toBe(true);
  });
  it("rejects a forged request (no / wrong signature)", () => {
    expect(verifyWhopSignature(body, {}, SECRET, NOW)).toBe(false);
    expect(verifyWhopSignature(body, sign(body, { secret: "attacker" }), SECRET, NOW)).toBe(false);
  });
  it("rejects a tampered body (e.g. a different course)", () => {
    const h = sign(body);
    expect(verifyWhopSignature(body.replace('"c1"', '"expensive"'), h, SECRET, NOW)).toBe(false);
  });
  it("rejects replays of old webhooks", () => {
    const old = NOW - MAX_WEBHOOK_AGE_SECONDS - 1;
    expect(verifyWhopSignature(body, sign(body, { ts: old }), SECRET, NOW)).toBe(false);
  });
  it("fails closed when the secret is not configured", () => {
    expect(verifyWhopSignature(body, sign(body), "", NOW)).toBe(false);
  });
});

describe("parseWhopPayment", () => {
  const p = (o: object) => parseWhopPayment(o);
  it("reads a paid payment", () => {
    expect(p(JSON.parse(body))).toEqual({ kind: "paid", paymentId: "pay_1", courseId: "c1", userId: "s1", amount: 25, currency: "USD" });
  });
  it("ignores events that are not a completed payment", () => {
    expect(p({ type: "payment.created", data: { id: "x", metadata: { courseId: "c", userId: "u" } } }).kind).toBe("ignored");
    expect(p({ type: "membership.went_valid", data: {} }).kind).toBe("ignored");
    expect(p({ type: "payment.succeeded", data: { id: "x", status: "pending", metadata: { courseId: "c", userId: "u" } } }).kind).toBe("ignored");
  });
  it("needs a payment id, course and user", () => {
    expect(p({ type: "payment.succeeded", data: { metadata: { courseId: "c", userId: "u" } } }).kind).toBe("invalid");
    expect(p({ type: "payment.succeeded", data: { id: "x", metadata: { userId: "u" } } }).kind).toBe("invalid");
  });
  // Whop's current payload (API 2026-09-02 and later): money is { amount: "27.50", currency, decimals }.
  // THE BUG: Number({...}) is NaN, so the amount was lost and the underpaid check never ran.
  const current = (data: object) =>
    p({ type: "payment.succeeded", api_version: "v1", api_version_date: "2026-11-02", data: { id: "pay_9", status: "paid", currency: "usd", metadata: { courseId: "c1", userId: "s1" }, ...data } });
  it("reads Whop's money objects (decimal strings)", () => {
    expect(current({ total: { amount: "27.50", currency: "usd", decimals: 2, display_decimals: 2 } })).toMatchObject({ kind: "paid", amount: 27.5, currency: "USD" });
  });
  it("prefers total, then falls back to usd_total / subtotal", () => {
    expect(current({ total: null, usd_total: { amount: "12.00", currency: "usd" } })).toMatchObject({ amount: 12 });
    expect(current({ subtotal: { amount: "9.99", currency: "usd" } })).toMatchObject({ amount: 9.99 });
  });
  it("still reads older payloads with plain numbers or numeric strings", () => {
    expect(current({ total: 25 })).toMatchObject({ amount: 25 });
    expect(current({ final_amount: "30.00" })).toMatchObject({ amount: 30 });
  });
  it("an unreadable amount is 'unknown' (null), never NaN or 0", () => {
    expect(current({ total: { amount: "abc" } })).toMatchObject({ amount: null });
    expect(current({})).toMatchObject({ amount: null });
  });
  it("takes the currency from the money object when the payment has none", () => {
    const r = p({ type: "payment.succeeded", data: { id: "x", status: "paid", total: { amount: "5.00", currency: "eur" }, metadata: { courseId: "c", userId: "u" } } });
    expect(r).toMatchObject({ amount: 5, currency: "EUR" });
  });
  it("finds the metadata wherever Whop puts it", () => {
    const r = p({ type: "payment.succeeded", data: { id: "x", checkout_configuration: { metadata: { course_id: " c9 ", user_id: "u9" } } } });
    expect(r).toMatchObject({ kind: "paid", courseId: "c9", userId: "u9" });
  });
});
