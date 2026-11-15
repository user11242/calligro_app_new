import crypto from "crypto";

/**
 * Whop webhooks are signed with the Standard Webhooks scheme:
 *   webhook-id, webhook-timestamp, webhook-signature: "v1,<base64 HMAC-SHA256>"
 * over `${id}.${timestamp}.${rawBody}` with the webhook secret
 * (env WHOP_WEBHOOK_SECRET, from the Whop dashboard → Developer → Webhooks).
 *
 * Without a valid signature a request is NOT from Whop and must be ignored —
 * before this check anyone could POST a fake "payment succeeded".
 */
export const MAX_WEBHOOK_AGE_SECONDS = 5 * 60;

type Headers = Record<string, string | null | undefined>;

function secretKey(secret: string): Buffer {
  // "whsec_<base64>" secrets are base64 bytes; Whop's own secrets are used as-is (UTF-8).
  return secret.startsWith("whsec_") ? Buffer.from(secret.slice(6), "base64") : Buffer.from(secret, "utf8");
}

export function verifyWhopSignature(rawBody: string, headers: Headers, secret: string, nowSeconds: number): boolean {
  if (!secret) return false; // fail closed: never accept unsigned payments
  const id = headers["webhook-id"];
  const timestamp = headers["webhook-timestamp"];
  const signatures = headers["webhook-signature"];
  if (!id || !timestamp || !signatures) return false;

  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(nowSeconds - ts) > MAX_WEBHOOK_AGE_SECONDS) return false;

  const expected = crypto.createHmac("sha256", secretKey(secret)).update(`${id}.${timestamp}.${rawBody}`).digest();
  return signatures.split(" ").some((entry) => {
    const [version, sig] = entry.split(",");
    if (version !== "v1" || !sig) return false;
    const given = Buffer.from(sig, "base64");
    return given.length === expected.length && crypto.timingSafeEqual(given, expected);
  });
}

export type WhopPayment =
  | { kind: "paid"; paymentId: string; courseId: string; userId: string; amount: number | null; currency: string }
  | { kind: "ignored"; reason: string }
  | { kind: "invalid"; reason: string };

/** Only a succeeded, paid payment with our course / user metadata enrols anyone. */
export function parseWhopPayment(payload: any): WhopPayment {
  const type = payload?.type || payload?.action;
  if (type !== "payment.succeeded") return { kind: "ignored", reason: `event ${type}` };

  const payment = payload.data || {};
  if (payment.status && !["paid", "succeeded"].includes(String(payment.status))) {
    return { kind: "ignored", reason: `status ${payment.status}` };
  }
  const metadata =
    payment.metadata ||
    payment.checkout_configuration?.metadata ||
    payment.plan?.metadata ||
    payment.membership?.metadata ||
    payload.metadata ||
    {};
  const courseId = String(metadata.courseId || metadata.course_id || "").trim();
  const userId = String(metadata.userId || metadata.user_id || "").trim();
  const paymentId = String(payment.id || "").trim();
  if (!paymentId) return { kind: "invalid", reason: "missing payment id" };
  if (!courseId || !userId) return { kind: "invalid", reason: "missing courseId / userId metadata" };

  const rawAmount = payment.total ?? payment.final_amount ?? payment.amount ?? payment.usd_total ?? payment.subtotal;
  const amount = rawAmount === undefined || rawAmount === null || rawAmount === "" ? null : Number(rawAmount);
  return {
    kind: "paid",
    paymentId,
    courseId,
    userId,
    amount: amount !== null && Number.isFinite(amount) ? amount : null,
    currency: String(payment.currency || "USD").toUpperCase(),
  };
}
