import { NextRequest, NextResponse } from "next/server";
import { adminDb, adminAuth, admin } from "@/lib/firebaseAdmin";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { courseId, couponCode } = body;

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
          error: "You must be logged in to enroll using this promotional coupon.",
          error_ar: "يجب تسجيل الدخول في الموقع لتتمكن من استخدام كوبون التسجيل المجاني.",
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

    // 2. Coupon Validation
    const cleanCode = (couponCode || "").trim().toUpperCase();
    if (cleanCode !== "CALLIGRO100") {
      return NextResponse.json(
        {
          error: "Invalid coupon code.",
          error_ar: "كود الكوبون غير صحيح.",
        },
        { status: 400 }
      );
    }

    // 3. Fetch Course Data
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

    // 4. Check if student is already enrolled in this course
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

    // 5. MAX 1 COURSE PER USER ENFORCEMENT
    // Check 1: User document flag & couponUsage
    const userRef = adminDb.collection("users").doc(userId);
    const userSnap = await userRef.get();
    const userData = userSnap.exists ? userSnap.data() || {} : {};

    if (userData.usedFreeCoupon === true || userData.couponUsage?.CALLIGRO100) {
      const prevCourseId = userData.freeCouponCourseId || userData.couponUsage?.CALLIGRO100?.courseId || "";
      return NextResponse.json(
        {
          error: "The CALLIGRO100 promotional coupon can only be used once per user. You have already claimed your free course.",
          error_ar: "كوبون CALLIGRO100 الترويجي محدد لدورة واحدة فقط لكل مستخدم. لقد قمت بالاستفادة منه مسبقاً لحسابك.",
          limitReached: true,
          previousCourseId: prevCourseId,
        },
        { status: 400 }
      );
    }

    // Check 2: Check in orders collection for any completed CALLIGRO100 order by this user
    const existingOrders = await adminDb
      .collection("orders")
      .where("uid", "==", userId)
      .where("couponCode", "==", "CALLIGRO100")
      .limit(1)
      .get();

    if (!existingOrders.empty) {
      return NextResponse.json(
        {
          error: "The CALLIGRO100 promotional coupon can only be used once per user. You have already claimed your free course.",
          error_ar: "كوبون CALLIGRO100 الترويجي محدد لدورة واحدة فقط لكل مستخدم. لقد قمت بالاستفادة منه مسبقاً لحسابك.",
          limitReached: true,
        },
        { status: 400 }
      );
    }

    // 6. Execute Enrollment Transaction
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

    const orderId = `COUPON_${Date.now()}_${userId.slice(0, 6)}`;

    const batch = adminDb.batch();

    // A. Update Course document
    batch.update(courseRef, {
      enrolledStudents: admin.firestore.FieldValue.arrayUnion(userId),
      enrolledCount: admin.firestore.FieldValue.increment(1),
    });

    // B. Update User Top-Level document (enforce single-use limit and course list)
    batch.set(
      userRef,
      {
        enrolledCourses: admin.firestore.FieldValue.arrayUnion(String(courseId)),
        usedFreeCoupon: true,
        freeCouponCourseId: String(courseId),
        freeCouponCode: "CALLIGRO100",
        freeCouponRedeemedAt: admin.firestore.FieldValue.serverTimestamp(),
        couponUsage: {
          CALLIGRO100: {
            courseId: String(courseId),
            redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
      },
      { merge: true }
    );

    // C. User enrolledCourses subcollection (for legacy & compatibility)
    const userEnrollmentRef = userRef.collection("enrolledCourses").doc(String(courseId));
    batch.set(
      userEnrollmentRef,
      {
        courseId: String(courseId),
        courseName,
        enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
        paymentProvider: "coupon",
        couponCode: "CALLIGRO100",
        amountPaid: 0,
      },
      { merge: true }
    );

    // D. Create Audit Order Document
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
      discount: 100,
      couponCode: "CALLIGRO100",
      paymentProvider: "coupon",
      status: "completed",
      environment: "live",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // E. Create Transaction Document (Ledger)
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
      source: "coupon_CALLIGRO100",
      couponCode: "CALLIGRO100",
      status: "completed",
      orderId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    console.log(
      `🎉 User ${userId} successfully enrolled in course ${courseId} via promo coupon CALLIGRO100 (Order: ${orderId})`
    );

    return NextResponse.json({
      success: true,
      message: "Successfully enrolled in course via CALLIGRO100!",
      message_ar: "تم تسجيلك في الدورة بنجاح بواسطة كوبون CALLIGRO100 مجاناً!",
      orderId,
      courseId: String(courseId),
      redirectUrl: `/courses/${courseId}/success`,
    });
  } catch (error: any) {
    console.error("Coupon Redeem API Error:", error);
    return NextResponse.json(
      {
        error: error.message || "Failed to redeem coupon.",
        error_ar: "حدث خطأ أثناء تفعيل الكوبون. يرجى المحاولة مرة أخرى.",
      },
      { status: 500 }
    );
  }
}
