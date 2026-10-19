import { NextRequest, NextResponse } from "next/server";
import { adminDb } from "@/lib/firebaseAdmin";
import { createPayPalOrder } from "@/lib/paypal";

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

    const order = await createPayPalOrder({
      amount: finalAmount,
      courseId,
      courseName,
      userId,
    });

    return NextResponse.json({ id: order.id });
  } catch (error: any) {
    console.error("PayPal Create Order API Error:", error);
    return NextResponse.json({ error: error.message || "Failed to create order" }, { status: 500 });
  }
}
