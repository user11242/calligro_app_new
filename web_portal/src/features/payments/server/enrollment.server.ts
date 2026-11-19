import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { calculateNetTuition, calculateWebPrice } from "../domain/pricing";
import type { WhopPayment } from "./whopWebhook.server";
import { isCourseFull } from "../domain/checkoutRules";

type PaidWhop = Extract<WhopPayment, { kind: "paid" }>;

export type EnrollmentResult = {
  status: "enrolled" | "already_enrolled" | "duplicate" | "underpaid" | "course_not_found";
  detail?: string;
};

const DEFAULT_COMMISSION = 0.6;
const round2 = (n: number) => Number(n.toFixed(2));

/**
 * The ONE place a Whop payment becomes an enrolment (+ order, transaction,
 * teacher commission). Runs in a single Firestore transaction keyed by the
 * payment id, so Whop's retries / duplicate deliveries count once.
 */
export async function recordWhopPurchase(db: Firestore, payment: PaidWhop): Promise<EnrollmentResult> {
  const { paymentId, courseId, userId } = payment;
  const orderRef = db.collection("orders").doc(paymentId);
  const courseRef = db.collection("courses").doc(courseId);
  const studentRef = db.collection("users").doc(userId);

  return db.runTransaction(async (tx) => {
    const [order, course, student] = await Promise.all([tx.get(orderRef), tx.get(courseRef), tx.get(studentRef)]);
    if (order.exists) return { status: "duplicate" as const };
    if (!course.exists) return { status: "course_not_found" as const };

    const courseData = course.data() || {};
    const expected = calculateWebPrice(Number(courseData.price || 0));
    if (payment.amount !== null && payment.amount + 0.01 < expected) {
      return { status: "underpaid" as const, detail: `paid ${payment.amount}, expected ${expected}` };
    }

    const teacherId = String(courseData.teacherId || "");
    const teacherRef = teacherId ? db.collection("users").doc(teacherId) : null;
    const teacher = teacherRef ? await tx.get(teacherRef) : null;
    const teacherData = teacher?.data() || {};
    const commissionRate =
      teacherData.commissionRate !== undefined ? Number(teacherData.commissionRate) : DEFAULT_COMMISSION;

    const totalPaid = payment.amount ?? expected;
    const net = calculateNetTuition(totalPaid);
    const feeBuffer = round2(totalPaid - net);
    const teacherCommission = round2(net * commissionRate);
    const academyNet = round2(net - teacherCommission);
    const alreadyEnrolled = Array.isArray(courseData.enrolledStudents) && courseData.enrolledStudents.includes(userId);
    // Checkout refuses full courses; a payment can still land after the last seat filled
    // (two buyers at once). They paid, so they are enrolled, and the order is flagged for the admin.
    const overCapacity = !alreadyEnrolled && isCourseFull(courseData, userId);

    const studentData = student.data() || {};
    const courseName = courseData.courseName || courseData.courseTitle || "Calligro Course Enrollment";
    const teacherName = teacherData.name || courseData.teacherName || "Calligro Instructor";
    const now = FieldValue.serverTimestamp();

    if (!alreadyEnrolled) {
      tx.set(courseRef, { enrolledStudents: FieldValue.arrayUnion(userId), enrolledCount: FieldValue.increment(1) }, { merge: true });
    }
    tx.set(
      studentRef.collection("enrolledCourses").doc(courseId),
      { courseId, courseName, enrolledAt: now, status: "active", paymentProvider: "whop", paymentId, amountPaid: totalPaid },
      { merge: true },
    );
    tx.set(studentRef, { enrolledCourses: FieldValue.arrayUnion(courseId) }, { merge: true });
    tx.set(orderRef, {
      id: paymentId,
      orderId: paymentId,
      uid: userId,
      studentName: studentData.name || studentData.displayName || "Student",
      studentEmail: studentData.email || "",
      courseId,
      courseName,
      courseArabicName: courseData.courseArabicName || courseData.arabicTitle || courseName,
      teacherId,
      teacherName,
      productId: courseId,
      transactionId: paymentId,
      price: totalPaid,
      totalPaid,
      studentNetTuition: net,
      feeBuffer,
      teacherCommission,
      academyNet,
      currency: payment.currency,
      status: "completed",
      paymentProvider: "whop",
      overCapacity,
      environment: "live",
      timestamp: now,
      createdAt: now,
    });
    tx.set(db.collection("transactions").doc(paymentId), {
      studentId: userId,
      studentName: studentData.name || "Student",
      studentEmail: studentData.email || "",
      teacherId,
      teacherName,
      courseId,
      courseName,
      amount: totalPaid,
      grossAmount: totalPaid,
      teacherShare: teacherCommission,
      academyProfit: academyNet,
      storeFee: feeBuffer,
      currency: payment.currency,
      source: "whop",
      status: "completed",
      orderId: paymentId,
      captureId: paymentId,
      createdAt: now,
    });
    // One commission per real new seat (an extra payment for a course you already have earns none).
    if (teacherRef && !alreadyEnrolled) {
      tx.set(db.collection("commissions").doc(paymentId), {
        orderId: paymentId,
        teacherId,
        courseId,
        amount: teacherCommission,
        currency: payment.currency,
        status: "pending",
        createdAt: now,
      });
      tx.set(
        teacherRef,
        { pendingBalance: FieldValue.increment(teacherCommission), totalEarnings: FieldValue.increment(teacherCommission) },
        { merge: true },
      );
    }
    if (alreadyEnrolled) return { status: "already_enrolled" as const };
    return overCapacity ? { status: "enrolled" as const, detail: "over_capacity" } : { status: "enrolled" as const };
  });
}
