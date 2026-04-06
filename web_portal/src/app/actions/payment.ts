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
    console.log("Initiating Lemon Squeezy checkout...");
    initLemonSqueezy();

    const storeId = process.env.LEMONSQUEEZY_STORE_ID;
    if (!storeId) {
      console.error("DEBUG: LEMONSQUEEZY_STORE_ID is missing");
      throw new Error("Missing Store Configuration. Please check Vercel environment variables.");
    }

    console.log(`DEBUG: Creating checkout for Store: ${storeId}, Variant: ${variantId}`);

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
      console.error("Lemon Squeezy API Error Details:", JSON.stringify(error, null, 2));
      throw new Error(error.message || "Failed to create checkout session");
    }

    const checkoutUrl = data?.data.attributes.url;
    if (!checkoutUrl) {
      throw new Error("Checkout URL not found in API response");
    }

    return { checkoutUrl };
  } catch (error: any) {
    console.error("Payment action error [Trace]:", error.message || error);
    throw new Error(error.message || "Internal Payment Error");
  }
}
