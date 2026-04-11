"use server";
import { createCheckout } from "@lemonsqueezy/lemonsqueezy.js";
import { initLemonSqueezy } from "@/lib/lemonsqueezy";

/**
 * Creates a Lemon Squeezy checkout session for a specific course using dynamic overrides.
 * This allows us to fulfill the "automatic product creation" requirement within API limits.
 * 
 * @param variantId The specific Variant ID for the course (if synced). Fallbacks to Master Variant if null.
 * @param userId The ID of the student purchasing the course.
 * @param courseId The Firestore document ID of the course.
 * @param userEmail The email of the student for pre-filling the checkout.
 * @param courseName The dynamic name of the course to show on checkout.
 * @param amountCents The final price in cents (after Grant/Discount logic).
 * @param description Optional course description for the checkout page.
 * @param imageUrl Optional course banner image for the checkout page.
 */
export async function createCheckoutSession(
  variantId: string | null | undefined,
  userId: string,
  courseId: string,
  userEmail: string,
  courseName: string,
  amountCents: number,
  description?: string,
  mediaUrls: string[] = []
) {
  try {
    const validMedia = mediaUrls.filter(url => url && url.startsWith('http'));
    console.log(`Lemon Squeezy: Media URLs for checkout:`, validMedia);

    console.log(`Lemon Squeezy: Initiating automated checkout for [${courseName}]...`);
    initLemonSqueezy();

    const storeId = process.env.LEMONSQUEEZY_STORE_ID?.trim();
    if (!storeId) {
      throw new Error("Payment configuration missing: LEMONSQUEEZY_STORE_ID is not set.");
    }

    // Use specific variant if available, otherwise fallback to Master Variant (1500080)
    const masterVariantId = process.env.LEMONSQUEEZY_VARIANT_ID?.trim() || "1500080"; 
    const cleanVariantId = (variantId?.trim() || masterVariantId).trim();

    console.log(`Lemon Squeezy: Creating session. Variant: ${cleanVariantId}, Price: $${(amountCents / 100).toFixed(2)}`);

    const { data, error, statusCode } = await createCheckout(storeId, cleanVariantId, {
      checkoutData: {
        email: userEmail,
        custom: {
          user_id: userId,
          course_id: courseId,
        },
      },
      checkoutOptions: {
        embed: false,
        media: true,
        logo: true,
        desc: true,
        discount: false,
      },
      productOptions: {
        name: courseName,
        description: description || "Calligro Digital Masterclass",
        media: validMedia,
        redirectUrl: `${process.env.NEXT_PUBLIC_APP_URL || "https://calligro.digital"}/courses/${courseId}/success`,
        receiptButtonText: "Enter Classroom",
        receiptLinkUrl: `${process.env.NEXT_PUBLIC_APP_URL || "https://calligro.digital"}/courses/${courseId}/classroom`,
      },
      customPrice: amountCents,
      testMode: true, 
    });

    if (error) {
      console.error("Lemon Squeezy API Error:", JSON.stringify(error, null, 2));
      throw new Error(error.message || `LS API Error ${statusCode}`);
    }

    const checkoutUrl = data?.data.attributes.url;
    if (!checkoutUrl) {
      throw new Error("No URL returned from Lemon Squeezy.");
    }

    console.log("Lemon Squeezy: Automated checkout session created.");
    return { checkoutUrl };
  } catch (error: any) {
    console.error("Lemon Squeezy Server Action Failure:", error.message || error);
    throw new Error(error.message || "Unable to initialize secure checkout. Please try again later.");
  }
}

