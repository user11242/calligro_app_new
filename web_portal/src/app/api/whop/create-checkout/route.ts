import { NextRequest, NextResponse } from "next/server";
import { adminDb } from "@/lib/firebaseAdmin";
import { createWhopCheckout } from "@/lib/whop";
import { calculateWebPrice } from "@/lib/pricingConfig";
import { checkoutBlock, type CheckoutBlock } from "@/lib/checkoutRules";

const BLOCK_STATUS: Record<CheckoutBlock, number> = {
  course_not_found: 404,
  invalid_price: 400,
  already_enrolled: 409,
  course_full: 409,
  commission_not_set: 409,
};

/**
 * Opens a Whop checkout for one course. The price and whether the student may buy
 * at all are decided here from Firestore (never from the browser), before any payment.
 * Enrolment itself happens only in the signed webhook (api/whop/webhook).
 */
export async function POST(req: NextRequest) {
  try {
    const { courseId, userId } = await req.json();

    if (!courseId || !userId) {
      return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
    }

    const courseDoc = await adminDb.collection("courses").doc(courseId).get();
    const courseData = courseDoc.exists ? courseDoc.data() : undefined;
    const teacherId = String(courseData?.teacherId || "");
    const teacherDoc = teacherId ? await adminDb.collection("users").doc(teacherId).get() : null;
    const teacherData = teacherDoc?.exists ? teacherDoc.data() : undefined;

    const block = checkoutBlock(courseData, teacherData, userId);
    if (block) {
      if (block === "commission_not_set") {
        console.warn(`Whop checkout refused: teacher ${teacherId} has no commission rate set (course ${courseId}).`);
      }
      return NextResponse.json({ error: block, code: block }, { status: BLOCK_STATUS[block] });
    }

    const finalAmount = calculateWebPrice(Number(courseData!.price));
    const courseName = courseData!.courseName || courseData!.courseTitle || "Calligro Course Enrollment";

    const origin = req.headers.get("origin") || process.env.NEXT_PUBLIC_APP_URL || "https://calligroacademy.com";
    const redirectUrl = `${origin}/courses/${courseId}/success`;

    const checkout = await createWhopCheckout({
      amount: finalAmount,
      courseId,
      courseName,
      userId,
      teacherId,
      redirectUrl,
    });

    return NextResponse.json({
      success: true,
      id: checkout.id,
      purchaseUrl: checkout.purchaseUrl,
    });
  } catch (error: any) {
    console.error("Whop Create Checkout API Error:", error);
    const msg =
      error?.message ||
      (typeof error === "string" ? error : JSON.stringify(error)) ||
      "Failed to initialize Whop checkout";
    return NextResponse.json(
      { error: msg },
      { status: 500 }
    );
  }
}
