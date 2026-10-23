import { NextRequest, NextResponse } from "next/server";
import { adminDb, adminAuth } from "@/lib/firebaseAdmin";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { couponCode, courseId } = body;

    const cleanCode = (couponCode || "").trim().toUpperCase();

    if (cleanCode !== "CALLIGRO100") {
      return NextResponse.json(
        {
          valid: false,
          error: "Invalid coupon code.",
          error_ar: "كود الكوبون غير صحيح.",
        },
        { status: 400 }
      );
    }

    // Check optional auth to inspect single-use limit upfront
    const authHeader = req.headers.get("authorization");
    let token = authHeader?.startsWith("Bearer ") ? authHeader.substring(7) : null;
    if (!token && body.idToken) {
      token = body.idToken;
    }

    let alreadyUsed = false;
    let alreadyUsedCourseId: string | null = null;
    let userId: string | null = null;

    if (token) {
      try {
        const decodedToken = await adminAuth.verifyIdToken(token);
        userId = decodedToken.uid;

        // Check user record
        const userDoc = await adminDb.collection("users").doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data() || {};
          if (userData.usedFreeCoupon === true || userData.couponUsage?.CALLIGRO100) {
            alreadyUsed = true;
            alreadyUsedCourseId = userData.freeCouponCourseId || userData.couponUsage?.CALLIGRO100?.courseId || null;
          }
        }

        // Secondary check in orders / transactions
        if (!alreadyUsed) {
          const orderSnap = await adminDb
            .collection("orders")
            .where("uid", "==", userId)
            .where("couponCode", "==", "CALLIGRO100")
            .limit(1)
            .get();

          if (!orderSnap.empty) {
            alreadyUsed = true;
          }
        }

        // Check if already enrolled in this course specifically
        if (courseId) {
          const courseDoc = await adminDb.collection("courses").doc(String(courseId)).get();
          if (courseDoc.exists) {
            const courseData = courseDoc.data() || {};
            if (Array.isArray(courseData.enrolledStudents) && courseData.enrolledStudents.includes(userId)) {
              return NextResponse.json({
                valid: false,
                isAlreadyEnrolled: true,
                error: "You are already enrolled in this course.",
                error_ar: "أنت مسجل بالفعل في هذه الدورة.",
              });
            }
          }
        }
      } catch (authErr) {
        console.warn("Coupon validation optional auth token check error:", authErr);
      }
    }

    if (alreadyUsed) {
      return NextResponse.json(
        {
          valid: false,
          alreadyUsed: true,
          error: "The coupon CALLIGRO100 has already been used on your account. Maximum 1 course per user.",
          error_ar: "تم استخدام كوبون CALLIGRO100 مسبقاً في حسابك. الكوبون صالح لدورة واحدة فقط لكل مستخدم.",
        },
        { status: 400 }
      );
    }

    return NextResponse.json({
      valid: true,
      code: "CALLIGRO100",
      discountPercent: 100,
      description: "100% OFF Promotional Grant (Max 1 course per user)",
      description_ar: "خصم 100% مجاني بالكامل (بحد أقصى دورة واحدة لكل مستخدم)",
    });
  } catch (error: any) {
    console.error("Coupon validation error:", error);
    return NextResponse.json(
      { valid: false, error: error.message || "Failed to validate coupon" },
      { status: 500 }
    );
  }
}
