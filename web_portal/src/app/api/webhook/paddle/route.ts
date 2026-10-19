import { NextRequest, NextResponse } from "next/server";
import { getPaddleInstance } from "@/lib/paddle";
import { adminDb, admin } from "@/lib/firebaseAdmin";

export async function POST(request: NextRequest) {
  const signature = request.headers.get("paddle-signature") ?? "";
  const rawBody = await request.text();
  const secret = process.env.PADDLE_NOTIFICATION_WEBHOOK_SECRET ?? "";

  if (!signature || !rawBody) {
    return NextResponse.json(
      { error: "Missing signature or body" },
      { status: 400 }
    );
  }

  try {
    const paddle = getPaddleInstance();
    // Throws on signature mismatch or expired timestamp
    const eventData = await paddle.webhooks.unmarshal(rawBody, secret, signature);

    if (!eventData) {
      return NextResponse.json({ error: "Empty event" }, { status: 400 });
    }

    console.log(`📡 Paddle Webhook received: ${eventData.eventType} [${eventData.eventId}]`);

    if (
      eventData.eventType === "transaction.completed" ||
      eventData.eventType === "transaction.paid"
    ) {
      const transaction: any = eventData.data;
      const customData = transaction.customData || {};
      const userId = customData.userId || customData.user_id;
      const courseId = customData.courseId || customData.course_id;

      if (!userId || !courseId) {
        console.warn("⚠️ Paddle webhook missing userId or courseId in customData:", customData);
        return NextResponse.json({ received: true, note: "missing_custom_data" });
      }

      console.log(`🏆 Enrolling Student: ${userId} in Course: ${courseId}`);

      // 1. Fetch Course Data
      const courseRef = adminDb.collection("courses").doc(String(courseId));
      const courseSnap = await courseRef.get();
      const courseData = courseSnap.data() || {};

      // 2. Fetch Teacher for Commission Rate
      let commissionRate = 0.6; // Default to 60%
      const teacherId = courseData.teacherId || customData.teacherId;
      if (teacherId) {
        const teacherSnap = await adminDb.collection("users").doc(teacherId).get();
        if (teacherSnap.exists) {
          const teacherData = teacherSnap.data() || {};
          if (teacherData.commissionRate !== undefined) {
            commissionRate = Number(teacherData.commissionRate);
          }
        }
      }

      // 3. Financial Calculations (Exact same accounting logic)
      // Paddle amounts are in lowest unit (cents for USD)
      const totalAmountCents = Number(transaction.details?.totals?.total || transaction.details?.totals?.grandTotal || 972);
      const totalPaid = totalAmountCents / 100; // e.g. 9.72
      const studentNetTuition = totalPaid / 1.08; // e.g. 9.00
      const feeBuffer = totalPaid - studentNetTuition; // e.g. 0.72
      const teacherCommission = studentNetTuition * commissionRate; // e.g. 5.40
      const academyNet = studentNetTuition - teacherCommission; // e.g. 3.60

      const transactionId = transaction.id || eventData.eventId;

      // 4. Enroll Student in Course
      await courseRef.update({
        enrolledStudents: admin.firestore.FieldValue.arrayUnion(userId),
        enrolledCount: admin.firestore.FieldValue.increment(1),
      });

      // 5. Add to Student's Enrolled Courses Subcollection
      await adminDb
        .collection("users")
        .doc(userId)
        .collection("enrolledCourses")
        .doc(String(courseId))
        .set(
          {
            courseId: String(courseId),
            enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
            courseName: courseData.courseName || courseData.courseTitle || "",
            status: "active",
            paymentProvider: "paddle",
            transactionId: transactionId,
          },
          { merge: true }
        );

      // 6. Record Order Document
      await adminDb.collection("orders").doc(transactionId).set(
        {
          orderId: transactionId,
          userId,
          courseId,
          teacherId,
          courseName: courseData.courseName || courseData.courseTitle || "",
          totalPaid,
          studentNetTuition,
          feeBuffer,
          teacherCommission,
          academyNet,
          currency: transaction.currencyCode || "USD",
          status: "completed",
          paymentProvider: "paddle",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // 7. Record Commission Document
      if (teacherId) {
        await adminDb.collection("commissions").add({
          orderId: transactionId,
          teacherId,
          courseId,
          amount: teacherCommission,
          currency: transaction.currencyCode || "USD",
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 8. Update Teacher Earnings
        await adminDb.collection("users").doc(teacherId).update({
          pendingBalance: admin.firestore.FieldValue.increment(teacherCommission),
          totalEarnings: admin.firestore.FieldValue.increment(teacherCommission),
        });
      }

      console.log(`✅ Student ${userId} enrolled successfully via Paddle transaction ${transactionId}`);
    }

    return NextResponse.json({ received: true });
  } catch (err: any) {
    console.error("❌ Paddle Webhook Error:", err);
    // Non-2xx causes Paddle to retry
    return NextResponse.json({ error: err.message || "Webhook processing error" }, { status: 500 });
  }
}
