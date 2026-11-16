/**
 * Withdrawals (Firestore emulator):
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/withdrawals.test.js"
 */
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { createWithdrawal, balanceOf } = require('../withdrawals');
const { assertFails, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { addDoc, collection, serverTimestamp } = require('firebase/firestore');

const app = admin.initializeApp({ projectId: 'demo-calligro-money' }, 'money-test');
const db = app.firestore();
const ts = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));
const NOW = new Date('2026-11-16T12:00:00Z').getTime();

async function wipe() {
  for (const c of ['users', 'transactions', 'courses', 'withdrawal_requests']) {
    for (const d of await db.collection(c).listDocuments()) {
      for (const sub of await d.listCollections()) for (const x of await sub.listDocuments()) await x.delete();
      await d.delete();
    }
  }
}

beforeEach(async () => {
  await wipe();
  await db.doc('users/t1').set({ role: 'teacher', name: 'Ustadh Ali' });
  await db.doc('users/t1/private/payout').set({ selectedMethod: 'cliq' });
  await db.doc('users/s1').set({ role: 'student' });
  await db.doc('courses/ended').set({ teacherId: 't1', endDate: ts('2026-11-01'), createdAt: ts('2026-08-01') });
  await db.doc('courses/running').set({ teacherId: 't1', endDate: ts('2027-01-30'), createdAt: ts('2026-09-01') });
  await db.collection('transactions').add({ teacherId: 't1', courseId: 'ended', teacherShare: 60, status: 'completed' });
  await db.collection('transactions').add({ teacherId: 't1', courseId: 'ended', teacherShare: 40, status: 'completed' });
  await db.collection('transactions').add({ teacherId: 't1', courseId: 'running', teacherShare: 70, status: 'completed' });
  await db.collection('transactions').add({ teacherId: 't1', courseId: 'ended', teacherShare: 999, status: 'refunded' });
});

describe('the server works out the balance with the app\'s rules', () => {
  it('ended course available; a long course created 2+ months ago but still running is pending', () => {
    const b = balanceOf({
      sales: [{ courseId: 'ended', teacherShare: 100 }, { courseId: 'running', teacherShare: 70 }],
      courses: [{ id: 'ended', endDate: ts('2026-11-01') }, { id: 'running', endDate: ts('2027-01-30'), createdAt: ts('2026-09-01') }],
      withdrawals: [],
      now: NOW,
    });
    expect(b).toEqual({ total: 170, pending: 70, withdrawn: 0, available: 100 });
  });
  it('withdrawals count their FULL amount (the fee is not given back)', () => {
    const b = balanceOf({
      sales: [{ courseId: 'ended', teacherShare: 100 }],
      courses: [{ id: 'ended', endDate: ts('2026-11-01') }],
      withdrawals: [{ requestedAmount: 100, netAmount: 90, amount: 90, status: 'pending' }],
      now: NOW,
    });
    expect(b.available).toBe(0);
  });
});

describe('requestWithdrawal', () => {
  it('creates ONE request for exactly the available money, with the same fields as before', async () => {
    const r = await createWithdrawal(db, 't1', { methodLabel: 'CliQ (Jordan only)', now: NOW });
    expect(r).toEqual({ requestedAmount: 100, netAmount: 100, fee: 0 });
    const docs = (await db.collection('withdrawal_requests').get()).docs.map((d) => d.data());
    expect(docs).toHaveLength(1);
    expect(docs[0]).toMatchObject({
      teacherId: 't1', teacherName: 'Ustadh Ali', method: 'CliQ (Jordan only)', payoutMethod: 'CliQ (Jordan only)',
      fee: 0, requestedAmount: 100, netAmount: 100, amount: 100, status: 'pending',
    });
  });

  it('asking again (second tap / second phone) is refused: the money is already requested', async () => {
    await createWithdrawal(db, 't1', { now: NOW });
    await expect(createWithdrawal(db, 't1', { now: NOW })).rejects.toThrow('No funds available');
    expect((await db.collection('withdrawal_requests').get()).size).toBe(1);
  });

  it('two requests at the same moment: only one succeeds', async () => {
    const results = await Promise.allSettled([createWithdrawal(db, 't1', { now: NOW }), createWithdrawal(db, 't1', { now: NOW })]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect((await db.collection('withdrawal_requests').get()).size).toBe(1);
  });

  it('a rejected request gives the money back', async () => {
    await createWithdrawal(db, 't1', { now: NOW });
    const req = (await db.collection('withdrawal_requests').get()).docs[0];
    await req.ref.update({ status: 'rejected' });
    expect((await createWithdrawal(db, 't1', { now: NOW })).requestedAmount).toBe(100);
  });

  it('Western Union keeps its 10 fee, counted in the full amount', async () => {
    await db.doc('users/t1/private/payout').set({ selectedMethod: 'western' });
    expect(await createWithdrawal(db, 't1', { now: NOW })).toEqual({ requestedAmount: 100, netAmount: 90, fee: 10 });
    await expect(createWithdrawal(db, 't1', { now: NOW })).rejects.toThrow('No funds available');
  });

  it('no payout method, not a teacher, nothing available → refused', async () => {
    await db.doc('users/t1/private/payout').delete();
    await expect(createWithdrawal(db, 't1', { now: NOW })).rejects.toThrow('payout method');
    await expect(createWithdrawal(db, 's1', { now: NOW })).rejects.toThrow('Only teachers');
    await db.doc('users/t1/private/payout').set({ selectedMethod: 'cliq' });
    await expect(createWithdrawal(db, 't1', { now: new Date('2026-11-02T00:00:00Z').getTime() })).rejects.toThrow('No funds available');
  });
});

describe('firestore.rules', () => {
  let env;
  beforeAll(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-calligro-money-rules',
      firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
    });
  });
  afterAll(() => env.cleanup());
  it('the app can no longer write a withdrawal request (any amount)', () =>
    assertFails(addDoc(collection(env.authenticatedContext('t1').firestore(), 'withdrawal_requests'), {
      teacherId: 't1', amount: 999999, requestedAmount: 999999, status: 'pending', createdAt: serverTimestamp(),
    })));
});
