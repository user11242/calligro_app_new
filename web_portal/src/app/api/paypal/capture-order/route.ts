import { NextRequest, NextResponse } from "next/server";
import { adminDb, admin } from "@/lib/firebaseAdmin";
import { capturePayPalOrder } from "@/lib/paypal";

export async function POST(req: NextRequest) {
  try {
    const { orderId, courseId, userId } = await req.json();

    if (!orderId || !courseId || !userId) {
      return NextResponse.json(
        { error: "Missing required fields: orderId, courseId, or userId" },
        { status: 400 }
      );
    }

    // 1. Capture payment via PayPal API
    const captureResult = await capturePayPalOrder(orderId);

    if (captureResult.status !== "COMPLETED") {
      return NextResponse.json(
        { error: `Payment status is ${captureResult.status}, expected COMPLETED` },
        { status: 400 }
      );
    }

    // 2. Extract payment capture details
    const purchaseUnit = captureResult.purchase_units?.[0];
    const capture = purchaseUnit?.payments?.captures?.[0];
    const captureId = capture?.id || orderId;
    const currency = capture?.amount?.currency_code || "USD";

    // 3. Fetch Course Data from Firestore
    const courseRef = adminDb.collection("courses").doc(String(courseId));
    const courseSnap = await courseRef.get();
    if (!courseSnap.exists) {
      return NextResponse.json({ error: "Course not found" }, { status: 404 });
    }
    const courseData = courseSnap.data() || {};
    const courseName = courseData.courseName || courseData.courseTitle || "Calligro Course Enrollment";
    const courseArabicName = courseData.courseArabicName || courseData.arabicTitle || courseName;
    const teacherId = courseData.teacherId || "";

    // 4. Financial Calculations
    // Final price paid by student
    const totalPaid = capture?.amount?.value
      ? Number(capture.amount.value)
      : Number(((Number(courseData.price || 0) / 2) * 1.08).toFixed(2));

    // Net tuition after removing 8% payment buffer
    const studentNetTuition = Number((totalPaid / 1.08).toFixed(2));
    const feeBuffer = Number((totalPaid - studentNetTuition).toFixed(2));

    // Fetch Teacher info & Commission Rate (default 60%)
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

    // 5. Fetch Student Profile
    const studentSnap = await adminDb.collection("users").doc(String(userId)).get();
    const studentData = studentSnap.exists ? studentSnap.data() || {} : {};
    const studentName =
      studentData.name ||
      studentData.displayName ||
      studentData.fullName ||
      captureResult.payer?.name?.given_name
        ? `${captureResult.payer?.name?.given_name || ""} ${captureResult.payer?.name?.surname || ""}`.trim()
        : studentData.email?.split("@")[0] || "Student";
    const studentEmail =
      studentData.email ||
      captureResult.payer?.email_address ||
      "";

    // 6. Update Course Document (Enroll student)
    await courseRef.update({
      enrolledStudents: admin.firestore.FieldValue.arrayUnion(userId),
      enrolledCount: admin.firestore.FieldValue.increment(1),
    });

    // 7. Update User Subcollection (enrolledCourses)
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
          paymentProvider: "paypal",
          orderId,
          captureId,
          amountPaid: totalPaid,
        },
        { merge: true }
      );

    // 8. Update User Document Top-Level (enrolledCourses array)
    await adminDb
      .collection("users")
      .doc(String(userId))
      .set(
        {
          enrolledCourses: admin.firestore.FieldValue.arrayUnion(String(courseId)),
        },
        { merge: true }
      );

    // 9. Record Order Audit Document
    await adminDb.collection("orders").doc(orderId).set(
      {
        id: orderId,
        orderId,
        uid: userId,
        studentName,
        studentEmail,
        courseId: String(courseId),
        courseName,
        courseArabicName,
        teacherId,
        teacherName,
        productId: String(courseId),
        transactionId: captureId,
        price: totalPaid,
        totalPaid,
        studentNetTuition,
        feeBuffer,
        teacherCommission,
        academyNet,
        currency,
        status: "completed",
        paymentProvider: "paypal",
        environment: "live",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 10. Record Transaction Document (Accounting Ledger)
    await adminDb.collection("transactions").doc(orderId).set(
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
        source: "paypal",
        status: "completed",
        orderId,
        captureId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 11. Record Teacher Commission & Update Balances
    if (teacherId) {
      await adminDb.collection("commissions").add({
        orderId,
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

    console.log(`✅ PayPal Enrollment complete for student ${userId} in course ${courseId}. Order: ${orderId}`);

    return NextResponse.json({
      success: true,
      orderId,
      captureId,
      status: "COMPLETED",
    });
  } catch (error: any) {
    console.error("PayPal Capture Order API Error:", error);
    return NextResponse.json(
      { error: error.message || "Failed to capture PayPal order" },
      { status: 500 }
    );
  }
}
