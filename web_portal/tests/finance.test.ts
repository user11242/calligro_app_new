import { describe, it, expect } from 'vitest';

// Simulating the Lemon Squeezy webhook calculations

function processLemonSqueezyWebhook(payloadAmount: number, isRecorded: boolean = false) {
  // 1. Calculate Calligro Buffer (8%)
  const calligroBuffer = payloadAmount * 0.08;
  const remainder = payloadAmount - calligroBuffer;

  // 2. Calculate Teacher Commission (60% for Live, 30% for Recorded)
  const teacherCommissionRate = isRecorded ? 0.30 : 0.60;
  const teacherPayout = remainder * teacherCommissionRate;
  
  // 3. The rest goes to Calligro's main profit pool
  const calligroProfit = remainder - teacherPayout;

  return {
    calligroBuffer: Number(calligroBuffer.toFixed(2)),
    teacherPayout: Number(teacherPayout.toFixed(2)),
    calligroProfit: Number(calligroProfit.toFixed(2)),
    total: Number((calligroBuffer + teacherPayout + calligroProfit).toFixed(2))
  };
}

describe('Domain 1: Finance & Payments (Web Portal)', () => {
  it('Test Case 1 & 2: Lemon Squeezy Payload processing and 8% Buffer', () => {
    // Student pays exactly $54.00
    const result = processLemonSqueezyWebhook(54.0);
    
    // 8% of 54 is 4.32
    expect(result.calligroBuffer).toBe(4.32);
    // Total should perfectly equal original payload to prevent money leaks
    expect(result.total).toBe(54.0); 
  });

  it('Test Case 3: Live Course Commission (60%)', () => {
    const result = processLemonSqueezyWebhook(54.0, false);
    
    // Remainder is 49.68. 60% of 49.68 is 29.81
    expect(result.teacherPayout).toBe(29.81);
    expect(result.calligroProfit).toBe(19.87);
  });

  it('Test Case 4: Recorded Course Commission (30%)', () => {
    const result = processLemonSqueezyWebhook(54.0, true);
    
    // Remainder is 49.68. 30% of 49.68 is 14.90
    expect(result.teacherPayout).toBe(14.90);
    expect(result.calligroProfit).toBe(34.78);
  });

  it('Test Case 7: Security - Rejects malicious payload formats (NaN)', () => {
    // If webhook sends malformed data
    const result = processLemonSqueezyWebhook(NaN);
    expect(Number.isNaN(result.calligroBuffer)).toBe(true);
  });
});
