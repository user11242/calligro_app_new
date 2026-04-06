"use server";
import { createCheckout } from "@lemonsqueezy/lemonsqueezy.js";
import { initLemonSqueezy } from "@/lib/lemonsqueezy";

/**
 * Creates a Lemon Squeezy checkout session for a specific course.
 * @param variantId The Lemon Squeezy Variant ID for the course.
 * @param userId The ID of the student purchasing the course.
 * @param courseId The Firestore document ID of the course.
 * @param userEmail The email of the student for pre-filling the checkout.
 */
export async function createCheckoutSession(
  variantId: string,
  userId: string,
  courseId: string,
  userEmail: string
) {
  try {
    initLemonSqueezy();

    const storeId = process.env.LEMONSQUEEZY_STORE_ID;
    if (!storeId) {
      throw new Error("Missing LEMONSQUEEZY_STORE_ID environment variable");
    }

    const { data, error } = await createCheckout(storeId, variantId, {
      checkoutData: {
        email: userEmail,
        custom: {
          user_id: userId,
          course_id: courseId,
        },
      },
      productOptions: {
        redirectUrl: `${process.env.NEXT_PUBLIC_APP_URL || "https://calligro.digital"}/courses/${courseId}/success`,
      },
    });

    if (error) {
      console.error("Lemon Squeezy API Error:", error);
      throw new Error(error.message || "Failed to create checkout session");
    }

    return { checkoutUrl: data?.data.attributes.url };
  } catch (error) {
    console.error("Payment action error:", error);
    throw error;
  }
}
