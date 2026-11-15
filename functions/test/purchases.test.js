/**
 * In-app purchases and free enrolment, against the Firestore emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/purchases.test.js"
 * Apple / Google are replaced by fakes; everything else is the real code.
 */
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const admin = require('firebase-admin');
const { HttpsError } = require('firebase-functions/v2/https');
const {
  expectedProductId, isProductValidForCourse, appleCandidates, handleVerifyPurchase, handleEnrollFree,
} = require('../purchases');

const app = admin.initializeApp({ projectId: 'demo-calligro-purchases' }, 'purchases-test');
const db = app.firestore();
const get = async (p) => (await db.doc(p).get()).data();

// Fake stores.
function appleReceipt(...entries) {
  return async () => ({ status: 0, environment: 'Sandbox', receipt: { in_app: entries } });
}
const tx = (id, product, ms) => ({ transaction_id: id, product_id: product, purchase_date_ms: String(ms) });
const googleOk = async ({ productId }) => ({ purchaseState: 0, orderId: `GPA.${productId}.1` });
const call = (data, uid = 's1') => ({ auth: uid ? { uid } : null, data });

async function wipe() {
  for (const c of ['courses', 'users', 'orders', 'transactions']) {
    for (const d of await db.collection(c).listDocuments()) await d.delete();
  }
}

beforeEach(async () => {
  await wipe();
  await db.doc('courses/cheap').set({ price: 10, teacherId: 't1', courseName: 'Cheap', iapProductId: 'com.yazan.calligro.tier_10', enrolledStudents: [], enrolledCount: 0 });
  await db.doc('courses/pricey').set({ price: 100, teacherId: 't1', courseName: 'Pricey', iapProductId: 'com.yazan.calligro.tier_100', enrolledStudents: [], enrolledCount: 0, maxStudents: 2 });
  await db.doc('courses/free').set({ price: 0, teacherId: 't1', courseName: 'Free', enrolledStudents: [], enrolledCount: 0, maxStudents: 1 });
  await db.doc('users/t1').set({ name: 'Ali', role: 'teacher', commissionRate: 0.6 });
  await db.doc('users/s1').set({ name: 'Sara', role: 'student' });
  await db.doc('users/s2').set({ name: 'Omar', role: 'student' });
});
afterAll(() => app.delete());

describe('which product a course needs', () => {
  test('the course\'s product, or the tier for its price', () => {
    expect(expectedProductId({ price: 100, iapProductId: 'com.yazan.calligro.tier_100' })).toBe('com.yazan.calligro.tier_100');
    expect(expectedProductId({ price: 49.9 })).toBe('com.yazan.calligro.tier_49');
  });
  test('a cheaper tier never unlocks a pricier course (even if the course doc says so)', () => {
    expect(isProductValidForCourse('com.yazan.calligro.tier_10', { price: 100, iapProductId: 'com.yazan.calligro.tier_100' })).toBe(false);
    expect(isProductValidForCourse('com.yazan.calligro.tier_10', { price: 100, iapProductId: 'com.yazan.calligro.tier_10' })).toBe(false);
    expect(isProductValidForCourse('com.yazan.calligro.tier_100', { price: 100, iapProductId: 'com.yazan.calligro.tier_100' })).toBe(true);
  });
  test('Apple: only this product\'s transactions, newest first', () => {
    const receipt = { in_app: [tx('1', 'p10', 100), tx('2', 'p100', 200), tx('3', 'p100', 300)] };
    expect(appleCandidates(receipt, 'p100').map((t) => t.transaction_id)).toEqual(['3', '2']);
  });
});

describe('verifyPurchase (Apple)', () => {
  test('paying for the course enrols the buyer and records the order', async () => {
    const res = await handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey', productId: 'com.yazan.calligro.tier_100' }),
      { db, verifyApple: appleReceipt(tx('T1', 'com.yazan.calligro.tier_100', 1)) });
    expect(res.success).toBe(true);
    expect((await get('courses/pricey')).enrolledStudents).toEqual(['s1']);
    expect((await get('courses/pricey')).enrolledCount).toBe(1);
    expect((await get('users/s1')).enrolledCourses).toEqual(['pricey']);
    expect(await get('orders/T1')).toMatchObject({ uid: 's1', courseId: 'pricey', productId: 'com.yazan.calligro.tier_100' });
  });

  test('THE EXPLOIT: a receipt for the cheap course cannot unlock the expensive one', async () => {
    await expect(handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey', productId: 'com.yazan.calligro.tier_10' }),
      { db, verifyApple: appleReceipt(tx('T1', 'com.yazan.calligro.tier_10', 1)) })).rejects.toMatchObject({ code: 'permission-denied' });
    expect((await get('courses/pricey')).enrolledStudents).toEqual([]);
    expect(await get('orders/T1')).toBeUndefined();
  });

  test('…not even by lying about productId', async () => {
    await expect(handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey', productId: 'com.yazan.calligro.tier_100' }),
      { db, verifyApple: appleReceipt(tx('T1', 'com.yazan.calligro.tier_10', 1)) })).rejects.toMatchObject({ code: 'permission-denied' });
  });

  test('one transaction enrols once: replaying it for another course or user does nothing', async () => {
    const deps = { db, verifyApple: appleReceipt(tx('T1', 'com.yazan.calligro.tier_100', 1)) };
    await handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }), deps);
    await db.doc('courses/pricey2').set({ price: 100, teacherId: 't1', iapProductId: 'com.yazan.calligro.tier_100', enrolledStudents: [] });
    await expect(handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey2' }), deps)).rejects.toMatchObject({ code: 'already-exists' });
    await expect(handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }, 's2'), deps)).rejects.toMatchObject({ code: 'already-exists' });
    expect((await get('courses/pricey2')).enrolledStudents).toEqual([]);
    expect((await get('courses/pricey')).enrolledStudents).toEqual(['s1']);
  });

  test('re-sending your own processed purchase is a harmless success (restore)', async () => {
    const deps = { db, verifyApple: appleReceipt(tx('T1', 'com.yazan.calligro.tier_100', 1)) };
    await handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }), deps);
    expect((await handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }), deps)).success).toBe(true);
    expect((await get('courses/pricey')).enrolledCount).toBe(1);
  });

  test('a receipt with an older used purchase and a new one uses the NEW one', async () => {
    const used = { db, verifyApple: appleReceipt(tx('OLD', 'com.yazan.calligro.tier_100', 1)) };
    await handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }, 's2'), used);
    const res = await handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }),
      { db, verifyApple: appleReceipt(tx('OLD', 'com.yazan.calligro.tier_100', 1), tx('NEW', 'com.yazan.calligro.tier_100', 2)) });
    expect(res.transactionId).toBe('NEW');
  });

  test('a failed Apple check enrols nobody', async () => {
    await expect(handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }),
      { db, verifyApple: async () => ({ status: 21003 }) })).rejects.toMatchObject({ code: 'permission-denied' });
  });

  test('must be signed in; must name a course', async () => {
    await expect(handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }, null), { db })).rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(handleVerifyPurchase(call({ receiptData: 'r' }), { db })).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  test('a full course refuses before anything is recorded', async () => {
    await db.doc('courses/pricey').update({ enrolledStudents: ['a', 'b'], enrolledCount: 2 });
    await expect(handleVerifyPurchase(call({ receiptData: 'r', courseId: 'pricey' }),
      { db, verifyApple: appleReceipt(tx('T1', 'com.yazan.calligro.tier_100', 1)) })).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(await get('orders/T1')).toBeUndefined();
  });
});

describe('verifyPurchase (Google Play)', () => {
  test('a verified purchase of the right product enrols', async () => {
    const res = await handleVerifyPurchase(call({ purchaseToken: 'tok', courseId: 'pricey', productId: 'com.yazan.calligro.tier_100', platform: 'android' }),
      { db, verifyGoogle: googleOk });
    expect(res.success).toBe(true);
    expect((await get('courses/pricey')).enrolledStudents).toEqual(['s1']);
  });

  test('THE EXPLOIT on Android: the cheap product cannot unlock the expensive course', async () => {
    let asked = false;
    await expect(handleVerifyPurchase(call({ purchaseToken: 'tok', courseId: 'pricey', productId: 'com.yazan.calligro.tier_10', platform: 'android' }),
      { db, verifyGoogle: async (a) => { asked = true; return googleOk(a); } })).rejects.toMatchObject({ code: 'permission-denied' });
    expect(asked).toBe(false);
  });

  test('a cancelled / pending Google purchase enrols nobody', async () => {
    await expect(handleVerifyPurchase(call({ purchaseToken: 'tok', courseId: 'pricey', productId: 'com.yazan.calligro.tier_100', platform: 'android' }),
      { db, verifyGoogle: async () => ({ purchaseState: 1, orderId: 'x' }) })).rejects.toMatchObject({ code: 'permission-denied' });
  });
});

describe('enrollInFreeCourse', () => {
  test('enrols in a free course and records it on the student', async () => {
    expect((await handleEnrollFree(call({ courseId: 'free' }), { db })).success).toBe(true);
    expect((await get('courses/free')).enrolledStudents).toEqual(['s1']);
    expect((await get('users/s1')).enrolledCourses).toEqual(['free']);
  });
  test('tapping twice enrols once', async () => {
    await handleEnrollFree(call({ courseId: 'free' }), { db });
    expect((await handleEnrollFree(call({ courseId: 'free' }), { db })).success).toBe(true);
    expect((await get('courses/free')).enrolledCount).toBe(1);
  });
  test('paid courses are refused with a clear reason (not "internal")', async () => {
    await expect(handleEnrollFree(call({ courseId: 'pricey' }), { db })).rejects.toMatchObject({ code: 'permission-denied' });
  });
  test('a full course is refused', async () => {
    await handleEnrollFree(call({ courseId: 'free' }, 's2'), { db });
    await expect(handleEnrollFree(call({ courseId: 'free' }), { db })).rejects.toMatchObject({ code: 'failed-precondition' });
  });
  test('errors are HttpsErrors the app can show', async () => {
    await expect(handleEnrollFree(call({ courseId: 'nope' }), { db })).rejects.toBeInstanceOf(HttpsError);
  });
});
