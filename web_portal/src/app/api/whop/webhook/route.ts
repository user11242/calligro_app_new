import { NextRequest, NextResponse } from "next/server";
import { adminDb, admin } from "@/lib/firebaseAdmin";

export async function POST(req: NextRequest) {
  try {
    const rawBody = await req.text();
    const payload = JSON.parse(rawBody);

    const eventType = payload.type || payload.action;

    // Handle payment.succeeded event
    if (eventType === "payment.succeeded" || eventType === "payment.created") {
      const payment = payload.data || {};
      const metadata =
        payment.metadata ||
        payment.checkout_configuration?.metadata ||
        payload.data?.metadata ||
        payment.plan?.metadata ||
        payment.membership?.metadata ||
        payload.metadata ||
        {};

      const rawCourseId = metadata.courseId || metadata.course_id;
      const rawUserId = metadata.userId || metadata.user_id;

      if (!rawCourseId || !rawUserId) {
        console.warn("Whop Webhook: Missing courseId or userId in metadata", metadata);
        return NextResponse.json({ received: true, note: "Ignored: missing metadata" });
      }

      const courseId = String(rawCourseId).trim();
      const userId = String(rawUserId).trim();
      const paymentId = String(payment.id || `whop_${Date.now()}`);

      // 1. Idempotency Check: Prevent duplicate counting and double payouts
      const existingOrder = await adminDb.collection("orders").doc(paymentId).get();
      if (existingOrder.exists) {
        console.log(`Whop Webhook: Payment ${paymentId} already processed. Skipping duplicate.`);
        return NextResponse.json({ success: true, message: "Already processed" });
      }

      // 2. Fetch Course Data
      const courseRef = adminDb.collection("courses").doc(courseId);
      const courseSnap = await courseRef.get();
      if (!courseSnap.exists) {
        console.error(`Whop Webhook: Course ${courseId} not found`);
        return NextResponse.json({ error: "Course not found" }, { status: 404 });
      }

      const courseData = courseSnap.data() || {};
      const courseName = courseData.courseName || courseData.courseTitle || "Calligro Course Enrollment";
      const courseArabicName = courseData.courseArabicName || courseData.arabicTitle || courseName;
      const teacherId = String(courseData.teacherId || metadata.teacherId || "").trim();

      // 3. Amount & Currency Calculation (with robust fallback)
      let totalPaid = Number(
        payment.total ??
        payment.amount ??
        payment.usd_total ??
        payment.subtotal ??
        0
      );

      if (totalPaid <= 0) {
        const originalPrice = Number(courseData.price || 0);
        totalPaid = Number(((originalPrice / 2) * 1.08).toFixed(2));
      }

      const currency = (payment.currency || "USD").toUpperCase();

      // Financial Calculations (Tuition, fee buffer, teacher share, academy profit)
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

      // 4. Fetch Student Profile
      const studentSnap = await adminDb.collection("users").doc(userId).get();
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

      // 5. Check if user is already enrolled to prevent double increment of enrolledCount
      const existingEnrolled = Array.isArray(courseData.enrolledStudents)
        ? courseData.enrolledStudents
        : [];
      const isAlreadyEnrolled = existingEnrolled.includes(userId);

      // 6. Enroll Student in Course
      await courseRef.set(
        {
          enrolledStudents: admin.firestore.FieldValue.arrayUnion(userId),
          enrolledCount: admin.firestore.FieldValue.increment(isAlreadyEnrolled ? 0 : 1),
        },
        { merge: true }
      );

      // 7. Update User Document & Subcollection
      await adminDb
        .collection("users")
        .doc(userId)
        .collection("enrolledCourses")
        .doc(courseId)
        .set(
          {
            courseId,
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
        .doc(userId)
        .set(
          {
            enrolledCourses: admin.firestore.FieldValue.arrayUnion(courseId),
          },
          { merge: true }
        );

      // 8. Record Order Audit Document
      await adminDb.collection("orders").doc(paymentId).set(
        {
          id: paymentId,
          orderId: paymentId,
          uid: userId,
          studentName,
          studentEmail,
          courseId,
          courseName,
          courseArabicName,
          teacherId,
          teacherName,
          productId: courseId,
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

      // 9. Record Transaction Document (Accounting Ledger for financeService.ts)
      await adminDb.collection("transactions").doc(paymentId).set(
        {
          studentId: userId,
          studentName,
          studentEmail,
          teacherId,
          teacherName,
          courseId,
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

      // 10. Record Teacher Commission & Update Balances (Only if not already enrolled)
      if (teacherId && !isAlreadyEnrolled) {
        await adminDb.collection("commissions").add({
          orderId: paymentId,
          teacherId,
          courseId,
          amount: teacherCommission,
          currency,
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await adminDb.collection("users").doc(teacherId).set(
          {
            pendingBalance: admin.firestore.FieldValue.increment(teacherCommission),
            totalEarnings: admin.firestore.FieldValue.increment(teacherCommission),
          },
          { merge: true }
        );
      }

      console.log(`Whop Webhook Success: User ${userId} successfully enrolled in ${courseId} via payment ${paymentId}`);
    }

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error("Whop Webhook Error:", error);
    return NextResponse.json({ error: error.message || "Webhook processing failed" }, { status: 500 });
  }
}
