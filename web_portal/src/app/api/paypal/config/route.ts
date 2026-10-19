import { NextResponse } from "next/server";

export async function GET() {
  const clientId =
    process.env.PAYPAL_CLIENT_ID ||
    process.env.NEXT_PUBLIC_PAYPAL_CLIENT_ID ||
    "BAAOp-NbjzhFx9sgtfJ0rAwMpWUVC_O7Wfqr9trbYDAByogKNqri6HvV2zbKT1-7Wi7HOAMDhusI5MZvjI";

  return NextResponse.json({
    clientId: clientId.trim(),
  });
}
