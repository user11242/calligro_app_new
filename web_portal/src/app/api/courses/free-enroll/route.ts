import { NextRequest, NextResponse } from "next/server";
import { adminDb, adminAuth, admin } from "@/lib/firebaseAdmin";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { courseId } = body;

    if (!courseId) {
      return NextResponse.json(
        {
          error: "Course ID is required.",
          error_ar: "معرف الدورة مطلوب.",
        },
        { status: 400 }
      );
    }

    // 1. Authentication Check (Mandatory)
    const authHeader = req.headers.get("authorization");
    let token = authHeader?.startsWith("Bearer ") ? authHeader.substring(7) : null;
    if (!token && body.idToken) {
      token = body.idToken;
    }

    if (!token) {
      return NextResponse.json(
        {
          error: "You must be logged in to claim your 1 free course.",
          error_ar: "يجب تسجيل الدخول في الموقع لتتمكن من الحصول على دورتك المجانية.",
          requiresAuth: true,
        },
        { status: 401 }
      );
    }

    let userId: string;
    let decodedToken: any;
    try {
      decodedToken = await adminAuth.verifyIdToken(token);
      userId = decodedToken.uid;
    } catch (authErr: any) {
      console.error("Token verification failed:", authErr);
      return NextResponse.json(
        {
          error: "Authentication session expired or invalid. Please sign in again.",
          error_ar: "انتهت جلسة تسجيل الدخول أو أنها غير صالحة. يرجى تسجيل الدخول مجدداً.",
          requiresAuth: true,
        },
        { status: 401 }
      );
    }

    // 2. Fetch Course Data
    const courseRef = adminDb.collection("courses").doc(String(courseId));
    const courseSnap = await courseRef.get();
    if (!courseSnap.exists) {
      return NextResponse.json(
        {
          error: "Course not found.",
          error_ar: "الدورة المطلوبة غير موجودة.",
        },
        { status: 404 }
      );
    }

    const courseData = courseSnap.data() || {};
    const enrolledStudents: string[] = Array.isArray(courseData.enrolledStudents)
      ? courseData.enrolledStudents
      : [];

    // 3. Check if student is already enrolled in this specific course
    if (enrolledStudents.includes(userId)) {
      return NextResponse.json(
        {
          error: "You are already enrolled in this course.",
          error_ar: "أنت مسجل بالفعل في هذه الدورة.",
          alreadyEnrolled: true,
          redirectUrl: `/courses/${courseId}/classroom`,
        },
        { status: 400 }
      );
    }

    // 4. MAX 1 FREE COURSE PER USER ENFORCEMENT
    const userRef = adminDb.collection("users").doc(userId);
    const userSnap = await userRef.get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};

    const hasAlreadyClaimed =
      userData.hasClaimedFreeCourse === true ||
      userData.usedFreeCoupon === true ||
      Boolean(userData.freeCourseId);

    if (hasAlreadyClaimed) {
      const prevCourseId = userData.freeCourseId || userData.freeCouponCourseId || "";
      return NextResponse.json(
        {
          error: "You have already claimed your 1 free course. Additional courses can be purchased with the standard 50% discount.",
          error_ar: "لقد استفدت مسبقاً من منحة الدورة المجانية (محددة بدورة واحدة فقط لكل طالب). يمكنك الاشتراك في هذه الدورة بسعر الخصم 50%.",
          limitReached: true,
          previousCourseId: prevCourseId,
        },
        { status: 400 }
      );
    }

    // Secondary Check: Orders / Transactions collection
    const existingOrders = await adminDb
      .collection("orders")
      .where("uid", "==", userId)
      .where("isFreeCourse", "==", true)
      .limit(1)
      .get();

    if (!existingOrders.empty) {
      return NextResponse.json(
        {
          error: "You have already claimed your 1 free course. Additional courses can be purchased with the standard 50% discount.",
          error_ar: "لقد استفدت مسبقاً من منحة الدورة المجانية (محددة بدورة واحدة فقط لكل طالب). يمكنك الاشتراك في هذه الدورة بسعر الخصم 50%.",
          limitReached: true,
        },
        { status: 400 }
      );
    }

    // 5. Execute Free Enrollment Transaction
    const courseName =
      courseData.courseName || courseData.courseTitle || courseData.title || "Calligro Course";
    const courseArabicName =
      courseData.courseArabicName || courseData.arabicTitle || courseName;
    const teacherId = courseData.teacherId || "";
    const teacherName = courseData.teacherName || "Calligro Instructor";

    const studentName =
      userData.name ||
      userData.displayName ||
      userData.fullName ||
      decodedToken.name ||
      userData.email?.split("@")[0] ||
      "Student";
    const studentEmail = userData.email || decodedToken.email || "";

    const orderId = `FREE_${Date.now()}_${userId.slice(0, 6)}`;

    const batch = adminDb.batch();

    // A. Update Course document
    batch.update(courseRef, {
      enrolledStudents: admin.firestore.FieldValue.arrayUnion(userId),
      enrolledCount: admin.firestore.FieldValue.increment(1),
    });

    // B. Update User Top-Level document (enforce single free course lock)
    batch.set(
      userRef,
      {
        enrolledCourses: admin.firestore.FieldValue.arrayUnion(String(courseId)),
        hasClaimedFreeCourse: true,
        freeCourseId: String(courseId),
        usedFreeCoupon: true,
        freeCourseClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // C. User enrolledCourses subcollection (for compatibility)
    const userEnrollmentRef = userRef.collection("enrolledCourses").doc(String(courseId));
    batch.set(
      userEnrollmentRef,
      {
        courseId: String(courseId),
        courseName,
        enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
        paymentProvider: "free_grant",
        isFreeCourse: true,
        amountPaid: 0,
      },
      { merge: true }
    );

    // D. Audit Order Document
    const orderRef = adminDb.collection("orders").doc(orderId);
    batch.set(orderRef, {
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
      transactionId: orderId,
      price: 0,
      totalPaid: 0,
      isFreeCourse: true,
      paymentProvider: "free_grant",
      status: "completed",
      environment: "live",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // E. Financial Ledger Transaction
    const transactionRef = adminDb.collection("transactions").doc(orderId);
    batch.set(transactionRef, {
      studentId: userId,
      studentName,
      studentEmail,
      teacherId,
      teacherName,
      courseId: String(courseId),
      courseName,
      amount: 0,
      grossAmount: 0,
      teacherShare: 0,
      academyProfit: 0,
      storeFee: 0,
      currency: "USD",
      source: "free_course_grant",
      isFreeCourse: true,
      status: "completed",
      orderId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    console.log(
      `🎉 User ${userId} successfully claimed free course ${courseId} (Order: ${orderId})`
    );

    return NextResponse.json({
      success: true,
      message: "Successfully claimed your 1 free course!",
      message_ar: "تم تفعيل دورتك المجانية بنجاح!",
      orderId,
      courseId: String(courseId),
      redirectUrl: `/courses/${courseId}/success`,
    });
  } catch (error: any) {
    console.error("Free Course Enroll API Error:", error);
    return NextResponse.json(
      {
        error: error.message || "Failed to enroll in free course.",
        error_ar: "حدث خطأ أثناء تفعيل الدورة المجانية. يرجى المحاولة مرة أخرى.",
      },
      { status: 500 }
    );
  }
}
