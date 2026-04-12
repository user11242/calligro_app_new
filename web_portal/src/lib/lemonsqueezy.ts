import { lemonSqueezySetup } from "@lemonsqueezy/lemonsqueezy.js";

/**
 * Initializes the Lemon Squeezy SDK with the API key from environment variables.
 * Usage: Import this in server actions or API routes.
 */
export function initLemonSqueezy() {
  const mode = process.env.NEXT_PUBLIC_PAYMENT_MODE || 'test';
  const apiKey = mode === 'live' 
    ? process.env.LEMONSQUEEZY_LIVE_API_KEY 
    : process.env.LEMONSQUEEZY_TEST_API_KEY;

  if (!apiKey) {
    throw new Error(`LEMONSQUEEZY_${mode.toUpperCase()}_API_KEY is not configured on the server.`);
  }

  lemonSqueezySetup({
    apiKey,
    onError: (error) => {
      console.error("Lemon Squeezy SDK Error:", error);
    },
  });
}
