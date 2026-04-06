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
    console.log("Lemon Squeezy: Starting createCheckoutSession...");
    initLemonSqueezy();

    const rawStoreId = process.env.LEMONSQUEEZY_STORE_ID;
    const storeId = rawStoreId?.trim();
    
    if (!storeId) {
      console.error("Lemon Squeezy: STORE_ID is missing from environment");
      throw new Error("Payment configuration is missing (Store ID). Please check Vercel settings.");
    }

    const cleanVariantId = variantId.trim();
    console.log(`Lemon Squeezy: Creating checkout for Store [${storeId}] and Variant [${cleanVariantId}]`);

    const { data, error, statusCode } = await createCheckout(storeId, cleanVariantId, {
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
      testMode: true, // Force test mode for now while store is in review
    });

    if (error) {
      console.error("Lemon Squeezy: API Error Response:", JSON.stringify(error, null, 2));
      console.error(`Lemon Squeezy: HTTP Status Code: ${statusCode}`);
      throw new Error(error.message || "Lemon Squeezy API rejected the checkout request.");
    }

    const checkoutUrl = data?.data.attributes.url;
    if (!checkoutUrl) {
      console.error("Lemon Squeezy: Response missing URL", JSON.stringify(data, null, 2));
      throw new Error("The payment provider did not return a checkout URL.");
    }

    console.log("Lemon Squeezy: Checkout session created successfully.");
    return { checkoutUrl };
  } catch (error: any) {
    console.error("Lemon Squeezy: Server Action Failure:", error.message || error);
    throw new Error(error.message || "An unexpected error occurred during checkout initialization.");
  }
}
