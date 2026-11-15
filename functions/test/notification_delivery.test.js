/**
 * One notification per event per user, and one push token per account
 * (Firestore emulator):
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/notification_delivery.test.js"
 */
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const admin = require('firebase-admin');
const { deliverOnce } = require('../notification_delivery');
const { releaseTokenFromOthers } = require('../notification_tokens');

const app = admin.initializeApp({ projectId: 'demo-calligro-notify' }, 'notify-test');
const db = app.firestore();

const fakeMessaging = () => {
  const sent = [];
  return { sent, send: async (m) => { sent.push(m); return 'id'; } };
};
const render = (lang) => (lang === 'ar' ? { title: 'واجب جديد', body: 'ألف' } : { title: 'New Assignment', body: 'Alif' });

async function wipe() {
  const users = await db.collection('users').listDocuments();
  for (const u of users) {
    for (const n of await u.collection('notifications').listDocuments()) await n.delete();
    await u.delete();
  }
}

beforeEach(async () => {
  await wipe();
  await db.doc('users/s1').set({ fcmToken: 'tok-s1', preferredLanguage: 'ar' });
  await db.doc('users/s2').set({});
});

describe('deliverOnce', () => {
  it('one inbox item (with its destination) and one push, in the user\'s language', async () => {
    const m = fakeMessaging();
    const r = await deliverOnce({ db, messaging: m, receiverId: 's1', key: 'evt-1', type: 'assignment', render,
      payload: { route: '/courseDetails', courseId: 'c1' } });
    expect(r).toBe('sent');
    const item = (await db.doc('users/s1/notifications/evt-1').get()).data();
    expect(item).toMatchObject({ title: 'واجب جديد', body: 'ألف', type: 'assignment', read: false, data: { route: '/courseDetails', courseId: 'c1' } });
    expect(m.sent).toHaveLength(1);
    expect(m.sent[0]).toMatchObject({ token: 'tok-s1', data: { route: '/courseDetails', courseId: 'c1', type: 'assignment' } });
  });

  it('the SAME event delivered again (a retried trigger) sends nothing more (THE BUG: 2-3 copies)', async () => {
    const m = fakeMessaging();
    const args = { db, messaging: m, receiverId: 's1', key: 'evt-1', type: 'assignment', render };
    expect(await deliverOnce(args)).toBe('sent');
    expect(await deliverOnce(args)).toBe('duplicate');
    expect(await deliverOnce(args)).toBe('duplicate');
    expect(m.sent).toHaveLength(1);
    expect((await db.collection('users/s1/notifications').get()).size).toBe(1);
  });

  it('different events are different notifications', async () => {
    const m = fakeMessaging();
    await deliverOnce({ db, messaging: m, receiverId: 's1', key: 'evt-1', type: 'x', render });
    await deliverOnce({ db, messaging: m, receiverId: 's1', key: 'evt-2', type: 'x', render });
    expect(m.sent).toHaveLength(2);
  });

  it('no token: inbox only; no user: nothing', async () => {
    const m = fakeMessaging();
    expect(await deliverOnce({ db, messaging: m, receiverId: 's2', key: 'e', type: 'x', render })).toBe('inbox-only');
    expect(await deliverOnce({ db, messaging: m, receiverId: 'ghost', key: 'e', type: 'x', render })).toBe('no-user');
    expect(m.sent).toHaveLength(0);
  });

  it('push data values are strings (FCM refuses anything else)', async () => {
    const m = fakeMessaging();
    await deliverOnce({ db, messaging: m, receiverId: 's1', key: 'e', type: 'x', render, payload: { n: 5, missing: null } });
    expect(m.sent[0].data.n).toBe('5');
    expect(m.sent[0].data).not.toHaveProperty('missing');
  });
});

describe('one push token per account', () => {
  it('when an account claims a token, the other accounts lose it', async () => {
    await db.doc('users/a').set({ fcmToken: 'phone-1' });
    await db.doc('users/b').set({ fcmToken: 'phone-1' });
    await db.doc('users/c').set({ fcmToken: 'phone-2' });
    expect(await releaseTokenFromOthers(db, 'b', 'phone-1')).toBe(1);
    expect((await db.doc('users/a').get()).data().fcmToken).toBeUndefined();
    expect((await db.doc('users/b').get()).data().fcmToken).toBe('phone-1');
    expect((await db.doc('users/c').get()).data().fcmToken).toBe('phone-2');
  });
});
