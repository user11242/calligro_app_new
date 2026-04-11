import { lemonSqueezySetup } from "@lemonsqueezy/lemonsqueezy.js";

/**
 * Initializes the Lemon Squeezy SDK with the API key from environment variables.
 * Usage: Import this in server actions or API routes.
 */
export function initLemonSqueezy() {
  const apiKey = process.env.LEMONSQUEEZY_API_KEY;
  if (!apiKey) {
    throw new Error("LEMONSQUEEZY_API_KEY is not configured on the server.");
  }

  lemonSqueezySetup({
    apiKey,
    onError: (error) => {
      console.error("Lemon Squeezy SDK Error:", error);
    },
  });
}
