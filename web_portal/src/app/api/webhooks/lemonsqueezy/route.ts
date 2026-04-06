import { NextResponse } from "next/server";
import crypto from "crypto";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK (Only if credentials exist)
const getDb = () => {
  if (!admin.apps.length) {
    const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

    if (projectId && clientEmail && privateKey) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
    } else {
      console.warn("Firebase Admin credentials missing. Skipping initialization.");
    }
  }
  return admin.firestore();
};

export async function POST(req: Request) {
  try {
    const rawBody = await req.text();
    const signature = req.headers.get("x-signature");
    const secret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET;

    if (!signature || !secret) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // Verify the Lemon Squeezy signature
    const hmac = crypto.createHmac("sha256", secret);
    const digest = hmac.update(rawBody).digest("hex");

    if (signature !== digest) {
      return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
    }

    const payload = JSON.parse(rawBody);
    const eventName = payload.meta.event_name;

    console.log(`Received Lemon Squeezy event: ${eventName}`);

    // We only care about successful orders
    if (eventName === "order_created" || eventName === "order_paid") {
      const customData = payload.meta.custom_data;
      const { user_id, course_id } = customData;

      if (!user_id || !course_id) {
        console.error("Missing user_id or course_id in custom_data");
        return NextResponse.json({ error: "Missing metadata" }, { status: 400 });
      }

      console.log(`Fulfilling order for User: ${user_id}, Course: ${course_id}`);

      // 1. Enroll the student in the course document
      const courseRef = getDb().collection("courses").doc(course_id);
      await courseRef.update({
        enrolledStudents: admin.firestore.FieldValue.arrayUnion(user_id),
      });

      // 2. Add the course to the user document (optional but recommended for fast fetching)
      const userRef = getDb().collection("users").doc(user_id);
      await userRef.update({
        enrolledCourses: admin.firestore.FieldValue.arrayUnion(course_id),
      });

      console.log(`Enrollment success for ${user_id}`);
    }

    return NextResponse.json({ success: true }, { status: 200 });
  } catch (error: any) {
    console.error("Webhook Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
