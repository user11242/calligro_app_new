/**
 * The payout migration against the Firestore emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/migrate_payout_private.test.js"
 */
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const admin = require('firebase-admin');
const { migratePayoutToPrivate } = require('../migrations/migrate_payout_private');

const app = admin.initializeApp({ projectId: 'demo-calligro-migration' }, 'migration-test');
const db = app.firestore();
const quiet = { log: () => {} };

const bank = { selectedMethod: 'bankTransfer', cliq: null, bankTransfer: { iban: 'JO94CBJO0010000000000131000302', city: 'Amman' } };
const cliq = { selectedMethod: 'cliq', cliq: { alias: 'ALI.H', holderName: 'Ali' }, bankTransfer: null };

async function clear() {
  for (const c of ['users', 'teachers']) {
    const snap = await db.collection(c).get();
    for (const d of snap.docs) {
      const priv = await d.ref.collection('private').get();
      await Promise.all(priv.docs.map((p) => p.ref.delete()));
      await d.ref.delete();
    }
  }
}

beforeEach(async () => {
  await clear();
  await db.doc('users/t1').set({ name: 'Ali', role: 'teacher', payoutSettings: bank });
  await db.doc('teachers/t1').set({ role: 'teacher', payoutSettings: bank });
  await db.doc('users/t2').set({ name: 'Sara', role: 'teacher', payoutSettings: cliq });
  await db.doc('users/t2/private/payout').set({ ...bank, savedByNewApp: true }); // newer, must win
  await db.doc('teachers/t3').set({ role: 'teacher', payoutSettings: cliq }); // only on teachers
  await db.doc('users/s1').set({ name: 'Student', role: 'student' });
});
afterAll(() => app.delete());

test('dry run changes nothing', async () => {
  const r = await migratePayoutToPrivate(db, quiet);
  expect(r.found).toBe(3);
  expect((await db.doc('users/t1').get()).get('payoutSettings')).toEqual(bank);
  expect((await db.doc('users/t1/private/payout').get()).exists).toBe(false);
});

test('apply: details move to the private doc and leave every public doc', async () => {
  const r = await migratePayoutToPrivate(db, { ...quiet, apply: true });
  expect(r).toMatchObject({ found: 3, moved: 2, keptExisting: 1, cleaned: 4 });

  const t1 = (await db.doc('users/t1/private/payout').get()).data();
  expect(t1.bankTransfer.iban).toBe(bank.bankTransfer.iban);
  expect(t1.migratedAt).toBeDefined();
  expect((await db.doc('users/t2/private/payout').get()).get('savedByNewApp')).toBe(true);
  expect((await db.doc('users/t3/private/payout').get()).get('cliq')).toEqual(cliq.cliq);

  for (const path of ['users/t1', 'teachers/t1', 'users/t2', 'teachers/t3']) {
    const data = (await db.doc(path).get()).data();
    expect(data.payoutSettings).toBeUndefined();
    expect(JSON.stringify(data)).not.toContain('JO94');
  }
  expect((await db.doc('users/t1').get()).get('name')).toBe('Ali'); // nothing else touched
  expect((await db.doc('users/s1').get()).data()).toEqual({ name: 'Student', role: 'student' });
});

test('running it again is harmless', async () => {
  await migratePayoutToPrivate(db, { ...quiet, apply: true });
  const again = await migratePayoutToPrivate(db, { ...quiet, apply: true });
  expect(again.found).toBe(0);
  expect((await db.doc('users/t1/private/payout').get()).get('bankTransfer').iban).toBe(bank.bankTransfer.iban);
});
