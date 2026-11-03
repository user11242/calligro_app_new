import { NextRequest, NextResponse } from "next/server";
import { adminDb } from "@/lib/firebaseAdmin";
import { createWhopCheckout } from "@/lib/whop";

export async function POST(req: NextRequest) {
  try {
    const { courseId, userId } = await req.json();

    if (!courseId || !userId) {
      return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
    }

    // Fetch authoritative course data from Firestore
    const courseDoc = await adminDb.collection("courses").doc(courseId).get();
    if (!courseDoc.exists) {
      return NextResponse.json({ error: "Course not found" }, { status: 404 });
    }

    const courseData = courseDoc.data()!;
    const originalPrice = Number(courseData.price || 0);

    // 50% Academy Grant + 8% Service Fee Buffer
    const discountedPrice = originalPrice / 2;
    const finalAmount = Number((discountedPrice * 1.08).toFixed(2));

    if (finalAmount <= 0) {
      return NextResponse.json({ error: "Invalid course price" }, { status: 400 });
    }

    const courseName = courseData.courseName || courseData.courseTitle || "Calligro Course Enrollment";
    const teacherId = courseData.teacherId || "";

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
    return NextResponse.json(
      { error: error.message || "Failed to initialize Whop checkout" },
      { status: 500 }
    );
  }
}
