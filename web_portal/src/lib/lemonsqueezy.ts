import { lemonSqueezySetup } from "@lemonsqueezy/lemonsqueezy.js";

/**
 * Initializes the Lemon Squeezy SDK with the API key from environment variables.
 * Usage: Import this in server actions or API routes.
 */
export function initLemonSqueezy() {
  const apiKey = process.env.LEMONSQUEEZY_API_KEY;
  if (!apiKey) {
    console.error("Missing LEMONSQUEEZY_API_KEY environment variable");
    return;
  }

  lemonSqueezySetup({
    apiKey,
    onError: (error) => {
      console.error("Lemon Squeezy SDK Error:", error);
    },
  });
}
