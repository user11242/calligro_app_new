/**
 * Email codes against the Firestore emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/email_codes.test.js"
 */
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const admin = require('firebase-admin');
const { issueCode, checkCode, normalizeEmail, codeEmailHtml, sendCodeEmail, MAX_ATTEMPTS } = require('../email_codes');

const app = admin.initializeApp({ projectId: 'demo-calligro-codes' }, 'codes-test');
const db = app.firestore();
const T0 = Date.UTC(2026, 10, 15, 12, 0, 0);

beforeEach(async () => {
  for (const d of await db.collection('emailOtps').listDocuments()) await d.delete();
});

describe('creating a code', () => {
  it('6 digits, stored only on the server, under the lower-cased email', async () => {
    const code = await issueCode(db, '  Ali@Example.com ', T0);
    expect(code).toMatch(/^\d{6}$/);
    const doc = (await db.doc('emailOtps/ali@example.com').get()).data();
    expect(doc.otp).toBe(code);
    expect(doc.attempts).toBe(0);
    expect(doc.expiresAt.toMillis() - T0).toBe(10 * 60 * 1000);
  });
  it('asking again within a minute is refused; after a minute a NEW code replaces the old', async () => {
    const first = await issueCode(db, 'a@x.com', T0);
    await expect(issueCode(db, 'a@x.com', T0 + 30 * 1000)).rejects.toThrow('cooldown');
    const second = await issueCode(db, 'a@x.com', T0 + 61 * 1000);
    expect((await db.doc('emailOtps/a@x.com').get()).data().otp).toBe(second);
    expect((await db.doc('emailOtps/a@x.com').get()).data().attempts).toBe(0);
  });
});

describe('checking a code', () => {
  it('right code → ok, and it can be used only once', async () => {
    const code = await issueCode(db, 'a@x.com', T0);
    expect(await checkCode(db, 'A@X.com', code, { now: T0 + 1000 })).toBe('ok');
    expect(await checkCode(db, 'a@x.com', code, { now: T0 + 2000 })).toBe('missing');
  });
  it('password reset keeps it for the final step (consume: false), which then uses it up', async () => {
    const code = await issueCode(db, 'a@x.com', T0);
    expect(await checkCode(db, 'a@x.com', code, { consume: false, now: T0 + 1000 })).toBe('ok');
    expect(await checkCode(db, 'a@x.com', code, { consume: true, now: T0 + 2000 })).toBe('ok');
    expect(await checkCode(db, 'a@x.com', code, { now: T0 + 3000 })).toBe('missing');
  });
  it('expired after 10 minutes', async () => {
    const code = await issueCode(db, 'a@x.com', T0);
    expect(await checkCode(db, 'a@x.com', code, { now: T0 + 10 * 60 * 1000 + 1 })).toBe('expired');
  });
  it(`${MAX_ATTEMPTS} wrong tries and the code stops working, even the right one (no guessing)`, async () => {
    const code = await issueCode(db, 'a@x.com', T0);
    const wrong = code === '111111' ? '222222' : '111111';
    for (let i = 1; i < MAX_ATTEMPTS; i++) expect(await checkCode(db, 'a@x.com', wrong, { now: T0 + i })).toBe('wrong');
    expect(await checkCode(db, 'a@x.com', wrong, { now: T0 + 99 })).toBe('locked');
    expect(await checkCode(db, 'a@x.com', code, { now: T0 + 100 })).toBe('missing');
  });
  it('no code requested → missing', async () => {
    expect(await checkCode(db, 'nobody@x.com', '123456', { now: T0 })).toBe('missing');
  });
});

describe('the email', () => {
  it('keeps the design the app used to send, with the code', () => {
    const html = codeEmailHtml('482913');
    expect(html).toContain('<div class="otp-code">482913</div>');
    expect(html).toContain('This code expires in <strong>10 minutes</strong>');
  });
  it('is sent through Brevo with the server key', async () => {
    const calls = [];
    await sendCodeEmail('server-key', 'a@x.com', '482913', async (url, init) => { calls.push({ url, init }); return { ok: true }; });
    expect(calls[0].url).toBe('https://api.brevo.com/v3/smtp/email');
    expect(calls[0].init.headers['api-key']).toBe('server-key');
    const body = JSON.parse(calls[0].init.body);
    expect(body.subject).toBe('Your Calligro Verification Code');
    expect(body.to).toEqual([{ email: 'a@x.com' }]);
    await expect(sendCodeEmail('k', 'a@x.com', '1', async () => ({ ok: false, status: 401 }))).rejects.toThrow('Brevo 401');
  });
  it('normalizeEmail', () => expect(normalizeEmail(' A@B.Com ')).toBe('a@b.com'));
});
