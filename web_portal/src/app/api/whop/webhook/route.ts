import { NextRequest, NextResponse } from "next/server";
import { adminDb, admin } from "@/lib/firebaseAdmin";

export async function POST(req: NextRequest) {
  try {
    const rawBody = await req.text();
    const payload = JSON.parse(rawBody);

    const eventType = payload.type || payload.action;

    // Handle payment.succeeded event
    if (eventType === "payment.succeeded") {
      const payment = payload.data || {};
      const metadata = payment.metadata || {};
      const courseId = metadata.courseId;
      const userId = metadata.userId;

      if (!courseId || !userId) {
        console.warn("Whop Webhook: Missing courseId or userId in metadata", metadata);
        return NextResponse.json({ received: true, note: "Ignored: missing metadata" });
      }

      const paymentId = payment.id || `whop_${Date.now()}`;
      const totalPaid = Number(payment.total || payment.amount || payment.usd_total || 0);
      const currency = (payment.currency || "USD").toUpperCase();

      // 1. Fetch Course Data
      const courseRef = adminDb.collection("courses").doc(String(courseId));
      const courseSnap = await courseRef.get();
      if (!courseSnap.exists) {
        console.error(`Whop Webhook: Course ${courseId} not found`);
        return NextResponse.json({ error: "Course not found" }, { status: 404 });
      }

      const courseData = courseSnap.data() || {};
      const courseName = courseData.courseName || courseData.courseTitle || "Calligro Course Enrollment";
      const courseArabicName = courseData.courseArabicName || courseData.arabicTitle || courseName;
      const teacherId = courseData.teacherId || metadata.teacherId || "";

      // 2. Financial Calculations
      const studentNetTuition = Number((totalPaid / 1.08).toFixed(2));
      const feeBuffer = Number((totalPaid - studentNetTuition).toFixed(2));

      let commissionRate = 0.6;
      let teacherName = courseData.teacherName || "Calligro Instructor";

      if (teacherId) {
        const teacherSnap = await adminDb.collection("users").doc(teacherId).get();
        if (teacherSnap.exists) {
          const teacherData = teacherSnap.data() || {};
          if (teacherData.commissionRate !== undefined) {
            commissionRate = Number(teacherData.commissionRate);
          }
          if (teacherData.name || teacherData.displayName) {
            teacherName = teacherData.name || teacherData.displayName;
          }
        }
      }

      const teacherCommission = Number((studentNetTuition * commissionRate).toFixed(2));
      const academyNet = Number((studentNetTuition - teacherCommission).toFixed(2));

      // 3. Fetch Student Profile
      const studentSnap = await adminDb.collection("users").doc(String(userId)).get();
      const studentData = studentSnap.exists ? studentSnap.data() || {} : {};
      const studentName =
        studentData.name ||
        studentData.displayName ||
        studentData.fullName ||
        payment.user?.name ||
        studentData.email?.split("@")[0] ||
        "Student";
      const studentEmail =
        studentData.email ||
        payment.user?.email ||
        "";

      // 4. Enroll Student in Course
      await courseRef.update({
        enrolledStudents: admin.firestore.FieldValue.arrayUnion(userId),
        enrolledCount: admin.firestore.FieldValue.increment(1),
      });

      // 5. Update User Document & Subcollection
      await adminDb
        .collection("users")
        .doc(String(userId))
        .collection("enrolledCourses")
        .doc(String(courseId))
        .set(
          {
            courseId: String(courseId),
            courseName,
            enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "active",
            paymentProvider: "whop",
            paymentId,
            amountPaid: totalPaid,
          },
          { merge: true }
        );

      await adminDb
        .collection("users")
        .doc(String(userId))
        .set(
          {
            enrolledCourses: admin.firestore.FieldValue.arrayUnion(String(courseId)),
          },
          { merge: true }
        );

      // 6. Record Order Audit Document
      await adminDb.collection("orders").doc(paymentId).set(
        {
          id: paymentId,
          orderId: paymentId,
          uid: userId,
          studentName,
          studentEmail,
          courseId: String(courseId),
          courseName,
          courseArabicName,
          teacherId,
          teacherName,
          productId: String(courseId),
          transactionId: paymentId,
          price: totalPaid,
          totalPaid,
          studentNetTuition,
          feeBuffer,
          teacherCommission,
          academyNet,
          currency,
          status: "completed",
          paymentProvider: "whop",
          environment: "live",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // 7. Record Transaction Document (Accounting Ledger for financeService.ts)
      await adminDb.collection("transactions").doc(paymentId).set(
        {
          studentId: userId,
          studentName,
          studentEmail,
          teacherId,
          teacherName,
          courseId: String(courseId),
          courseName,
          amount: totalPaid,
          grossAmount: totalPaid,
          teacherShare: teacherCommission,
          academyProfit: academyNet,
          storeFee: feeBuffer,
          currency,
          source: "whop",
          status: "completed",
          orderId: paymentId,
          captureId: paymentId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // 8. Record Teacher Commission & Update Balances
      if (teacherId) {
        await adminDb.collection("commissions").add({
          orderId: paymentId,
          teacherId,
          courseId: String(courseId),
          amount: teacherCommission,
          currency,
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await adminDb.collection("users").doc(teacherId).update({
          pendingBalance: admin.firestore.FieldValue.increment(teacherCommission),
          totalEarnings: admin.firestore.FieldValue.increment(teacherCommission),
        });
      }

      console.log(`Whop Webhook Success: User ${userId} enrolled in ${courseId} via payment ${paymentId}`);
    }

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error("Whop Webhook Error:", error);
    return NextResponse.json({ error: error.message || "Webhook processing failed" }, { status: 500 });
  }
}
