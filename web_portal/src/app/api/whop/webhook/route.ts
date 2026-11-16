import { NextRequest, NextResponse } from "next/server";
import { adminDb } from "@/lib/firebaseAdmin";
import { parseWhopPayment, verifyWhopSignature } from "@/lib/whopWebhook";
import { recordWhopPurchase } from "@/lib/enrollment";

/**
 * Whop → enrolment. Only signed webhooks (WHOP_WEBHOOK_SECRET) of a succeeded
 * payment enrol anyone; the enrolment itself is idempotent (lib/enrollment.ts).
 */
export async function POST(req: NextRequest) {
  const rawBody = await req.text();
  const secret = (process.env.WHOP_WEBHOOK_SECRET || "").replace(/['"]/g, "").trim();

  if (!secret) {
    console.error("Whop Webhook: WHOP_WEBHOOK_SECRET is not set — refusing every webhook until it is configured.");
    return NextResponse.json({ error: "Webhook not configured" }, { status: 500 });
  }
  const headers = {
    "webhook-id": req.headers.get("webhook-id"),
    "webhook-timestamp": req.headers.get("webhook-timestamp"),
    "webhook-signature": req.headers.get("webhook-signature"),
  };
  if (!verifyWhopSignature(rawBody, headers, secret, Math.floor(Date.now() / 1000))) {
    console.warn("Whop Webhook: rejected a request with a missing or invalid signature.");
    return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
  }

  let payload: unknown;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const payment = parseWhopPayment(payload);
  if (payment.kind === "ignored") return NextResponse.json({ received: true, note: payment.reason });
  if (payment.kind === "invalid") {
    console.error(`Whop Webhook: unusable payment (${payment.reason}).`);
    return NextResponse.json({ error: payment.reason }, { status: 400 });
  }

  try {
    const result = await recordWhopPurchase(adminDb, payment);
    if (result.detail === "over_capacity") {
      console.warn(`Whop Webhook: payment ${payment.paymentId} enrolled user ${payment.userId} in FULL course ${payment.courseId} (paid as the last seat filled). Admin: review.`);
    }
    if (result.status === "underpaid" || result.status === "course_not_found") {
      // Retrying would not help; log loudly so an admin can follow up with the student.
      console.error(`Whop Webhook: payment ${payment.paymentId} NOT enrolled: ${result.status} ${result.detail || ""}`);
    } else {
      console.log(`Whop Webhook: payment ${payment.paymentId} → ${result.status} (user ${payment.userId}, course ${payment.courseId})`);
    }
    return NextResponse.json({ received: true, status: result.status });
  } catch (error: any) {
    console.error("Whop Webhook Error:", error);
    return NextResponse.json({ error: "Webhook processing failed" }, { status: 500 }); // Whop will retry
  }
}
