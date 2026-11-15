/**
 * Pricing & Platform Fee Configuration
 *
 * Toggle `ENABLE_8_PERCENT_FEE` to enable or disable the 8% platform fee buffer.
 * Set to `false`: Students pay the clean, flat tuition (e.g. $30.00 instead of $32.40).
 * Set to `true`: Re-enables the +8% platform fee buffer.
 */
export const ENABLE_8_PERCENT_FEE = false;

export const FEE_RATE = ENABLE_8_PERCENT_FEE ? 0.08 : 0.0;
export const FEE_MULTIPLIER = 1 + FEE_RATE; // 1.0 when disabled, 1.08 when enabled

/**
 * Calculates display & checkout price for a course on the web portal.
 * Default is 50% academy grant applied to the course base price.
 */
export function calculateWebPrice(basePrice: number): number {
  const discounted = basePrice / 2;
  return Number((discounted * FEE_MULTIPLIER).toFixed(2));
}

/**
 * Strips the fee buffer from gross total to compute net tuition.
 */
export function calculateNetTuition(totalPaid: number): number {
  return Number((totalPaid / FEE_MULTIPLIER).toFixed(2));
}

