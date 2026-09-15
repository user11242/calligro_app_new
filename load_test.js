import http from 'k6/http';
import { check, sleep } from 'k6';

// -----------------------------------------------------------
// Phase 8: Calligro Viral Spike Load Test
// -----------------------------------------------------------
// Simulating an influencer posting about Calligro, causing 
// 10,000 students to buy a course in exactly 1 minute.
// We are hammering the Lemon Squeezy webhook on the Next.js portal.

export const options = {
  stages: [
    { duration: '10s', target: 50 },  // Ramp up to 50 concurrent buyers
    { duration: '30s', target: 1000 }, // Massive viral spike (1,000 buyers at once)
    { duration: '10s', target: 0 },   // Cool down
  ],
};

export default function () {
  const url = 'http://localhost:3000/api/webhooks/lemon-squeezy';
  
  const payload = JSON.stringify({
    meta: { event_name: 'order_created' },
    data: {
      attributes: {
        total_formatted: '$54.00',
        total: 5400,
        user_email: `student_${__VU}_${__ITER}@gmail.com`, // Unique fake user
      }
    }
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Signature': 'fake_signature_for_testing'
    },
  };

  // Blast the Web Portal with the fake purchase
  const res = http.post(url, payload, params);

  // Mathematically prove the Web Portal did not crash (Must return 200 OK)
  check(res, {
    'Transaction successful (200 OK)': (r) => r.status === 200,
    'Transaction did not timeout': (r) => r.timings.duration < 2000, // Must process in under 2 seconds
  });

  // Short pause between purchases
  sleep(1);
}
