/**
 * storage.rules against the Storage + Firestore emulators (the rules read
 * Firestore for admin role, course owner and enrolment):
 *
 *   firebase emulators:exec --only firestore,storage --project demo-calligro \
 *     "cd functions && npx jest test/storage_rules.test.js"
 *
 * Paths are the ones the Flutter app uploads to.
 */
const fs = require('fs');
const path = require('path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { ref, uploadString, deleteObject, getBytes } = require('firebase/storage');
const { doc, setDoc } = require('firebase/firestore');

let env;
const PROJECT = 'demo-calligro';
const image = { contentType: 'image/jpeg' };

const as = (uid) => env.authenticatedContext(uid).storage();
const guest = () => env.unauthenticatedContext().storage();
const put = (storage, p, meta = image, body = 'x') => uploadString(ref(storage, p), body, 'raw', meta);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
    storage: { host: '127.0.0.1', port: 9199, rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8') },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { role: 'admin' });
    await setDoc(doc(db, 'users/s1'), { role: 'student' });
    await setDoc(doc(db, 'users/s2'), { role: 'student' });
    await setDoc(doc(db, 'users/t1'), { role: 'teacher' });
    await setDoc(doc(db, 'courses/c1'), { teacherId: 't1', enrolledStudents: ['s1'] });
    const st = ctx.storage();
    await put(st, 'community_posts/s1/a.jpg');
    await put(st, 'user_profile_images/s1/me.jpg');
    await put(st, 'course_materials/c1/sheet.pdf', { contentType: 'application/pdf' });
    await put(st, 'course_submissions/c1/a1/s1_work.jpg');
    await put(st, 'course_chats/c1/s1_1.jpg');
  });
});

describe('community post images', () => {
  it('everyone can view', () => assertSucceeds(getBytes(ref(guest(), 'community_posts/s1/a.jpg'))));
  it('you upload images into your own folder only', async () => {
    await assertSucceeds(put(as('s1'), 'community_posts/s1/b.jpg'));
    await assertFails(put(as('s2'), 'community_posts/s1/c.jpg'));
    await assertFails(put(guest(), 'community_posts/s1/d.jpg'));
  });
  it('images only, and not huge', async () => {
    await assertFails(put(as('s1'), 'community_posts/s1/x.html', { contentType: 'text/html' }));
    await assertFails(put(as('s1'), 'community_posts/s1/big.jpg', image, 'x'.repeat(11 * 1024 * 1024)));
  });
  it('others cannot overwrite or delete your images; admins can delete (post removal)', async () => {
    await assertFails(put(as('s2'), 'community_posts/s1/a.jpg'));
    await assertFails(deleteObject(ref(as('s2'), 'community_posts/s1/a.jpg')));
    await assertSucceeds(deleteObject(ref(as('admin'), 'community_posts/s1/a.jpg')));
  });
  it('the author deletes their own', () => assertSucceeds(deleteObject(ref(as('s1'), 'community_posts/s1/a.jpg'))));
});

describe('profile images', () => {
  it('own folder only', async () => {
    await assertSucceeds(put(as('s1'), 'user_profile_images/s1/new.jpg'));
    await assertFails(put(as('s2'), 'user_profile_images/s1/me.jpg'));
    await assertFails(deleteObject(ref(as('s2'), 'user_profile_images/s1/me.jpg')));
    await assertSucceeds(getBytes(ref(guest(), 'user_profile_images/s1/me.jpg')));
  });
});

describe('course materials', () => {
  it('only the course teacher (or an admin) uploads / deletes', async () => {
    await assertSucceeds(put(as('t1'), 'course_materials/c1/new.pdf', { contentType: 'application/pdf' }));
    await assertFails(put(as('s1'), 'course_materials/c1/evil.pdf', { contentType: 'application/pdf' }));
    await assertFails(deleteObject(ref(as('s1'), 'course_materials/c1/sheet.pdf')));
    await assertSucceeds(deleteObject(ref(as('admin'), 'course_materials/c1/sheet.pdf')));
  });
  it('are readable (shared with students)', () => assertSucceeds(getBytes(ref(as('s2'), 'course_materials/c1/sheet.pdf'))));
});

describe('assignment submissions', () => {
  const mine = 'course_submissions/c1/a1/s1_work.jpg';
  it('a student uploads files named with their own id only', async () => {
    await assertSucceeds(put(as('s1'), 'course_submissions/c1/a1/s1_v2.jpg'));
    await assertFails(put(as('s2'), 'course_submissions/c1/a1/s1_fake.jpg'));
  });
  it('only the student, the course teacher and admins can see a submission', async () => {
    await assertSucceeds(getBytes(ref(as('s1'), mine)));
    await assertSucceeds(getBytes(ref(as('t1'), mine)));
    await assertSucceeds(getBytes(ref(as('admin'), mine)));
    await assertFails(getBytes(ref(as('s2'), mine)));
  });
});

describe('course chat images', () => {
  it('members (teacher, enrolled) read and post their own; outsiders cannot', async () => {
    await assertSucceeds(put(as('s1'), 'course_chats/c1/s1_2.jpg'));
    await assertSucceeds(getBytes(ref(as('t1'), 'course_chats/c1/s1_1.jpg')));
    await assertFails(put(as('s2'), 'course_chats/c1/s2_1.jpg'));
    await assertFails(getBytes(ref(as('s2'), 'course_chats/c1/s1_1.jpg')));
    await assertFails(put(as('t1'), 'course_chats/c1/s1_3.jpg'), 'cannot post under someone else\'s id');
  });
});

describe('anything else', () => {
  it('no uploads to unknown paths', async () => {
    await assertFails(put(as('s1'), 'random/thing.jpg'));
    await assertFails(put(as('s1'), 'community_posts.jpg'));
  });
});
