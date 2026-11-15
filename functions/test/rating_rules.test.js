/**
 * firestore.rules for ratings:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/rating_rules.test.js"
 */
const fs = require('fs');
const path = require('path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc, addDoc, collection, serverTimestamp, Timestamp, runTransaction, increment } = require('firebase/firestore');

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-calligro-ratings',
    firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { role: 'admin' });
    await setDoc(doc(db, 'users/s1'), { role: 'student', name: 'Sara' });
    await setDoc(doc(db, 'users/s2'), { role: 'student' });
    await setDoc(doc(db, 'users/t1'), { role: 'teacher', totalStars: 0, reviewCount: 0 });
    await setDoc(doc(db, 'courses/ended'), { teacherId: 't1', enrolledStudents: ['s1'], endDate: Timestamp.fromDate(new Date(Date.now() - 864e5)) });
    await setDoc(doc(db, 'courses/running'), { teacherId: 't1', enrolledStudents: ['s1'], endDate: Timestamp.fromDate(new Date(Date.now() + 864e5)) });
  });
});

// Exactly what FirestoreRatingRepository writes (Review.toDocument).
const review = (over = {}) => ({
  studentId: 's1', studentName: 'Sara', teacherId: 't1', courseId: 'ended', courseName: 'Thuluth',
  rating: 5, reviewText: 'Lovely', timestamp: serverTimestamp(), isPublic: true, ...over,
});

describe('rating a course', () => {
  it('an enrolled student rates a finished course, at its fixed id', () =>
    assertSucceeds(setDoc(doc(as('s1'), 'reviews/ended_s1'), review())));

  it('the app\'s transaction (read, then create) works', () => {
    const db = as('s1');
    return assertSucceeds(runTransaction(db, async (tx) => {
      const ref = doc(db, 'reviews/ended_s1');
      await tx.get(ref);
      tx.set(ref, review());
    }));
  });

  it('a SECOND rating of the same course is refused (THE BUG)', async () => {
    await assertSucceeds(setDoc(doc(as('s1'), 'reviews/ended_s1'), review()));
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1'), review({ rating: 1 })));
    await assertFails(addDoc(collection(as('s1'), 'reviews'), review()));
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1_again'), review()));
  });

  it('not before the course ends, not by outsiders, not for someone else', async () => {
    await assertFails(setDoc(doc(as('s1'), 'reviews/running_s1'), review({ courseId: 'running' })));
    await assertFails(setDoc(doc(as('s2'), 'reviews/ended_s2'), review({ studentId: 's2' })));
    await assertFails(setDoc(doc(as('s2'), 'reviews/ended_s1'), review()));
  });

  it('no fake teacher, stars outside 1-5, back-dating, extra fields or essays', async () => {
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1'), review({ teacherId: 'someoneElse' })));
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1'), review({ rating: 6 })));
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1'), review({ rating: 0 })));
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1'), review({ rating: 4.5 })));
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1'), review({ timestamp: Timestamp.fromDate(new Date('2020-01-01')) })));
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1'), review({ featured: true })));
    await assertFails(setDoc(doc(as('s1'), 'reviews/ended_s1'), review({ reviewText: 'x'.repeat(1001) })));
  });

  it('a rating is final for students; admins moderate', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'reviews/ended_s1'), review({ timestamp: Timestamp.now() })));
    await assertFails(updateDoc(doc(as('s1'), 'reviews/ended_s1'), { rating: 1 }));
    await assertFails(deleteDoc(doc(as('s1'), 'reviews/ended_s1')));
    await assertSucceeds(deleteDoc(doc(as('admin'), 'reviews/ended_s1')));
  });

  it('anyone can read reviews (public profiles)', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'reviews/ended_s1'), review({ timestamp: Timestamp.now() })));
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'reviews/ended_s1')));
  });
});

describe('totals and pop-up state', () => {
  it('students cannot touch a teacher\'s totals any more', async () => {
    await assertFails(updateDoc(doc(as('s1'), 'users/t1'), { totalStars: increment(5), reviewCount: increment(1) }));
  });
  it('the pop-up counter is private to the student', async () => {
    await assertSucceeds(setDoc(doc(as('s1'), 'users/s1/rating_prompts/ended'), { timesShown: increment(1), lastShownAt: serverTimestamp() }, { merge: true }));
    await assertFails(getDoc(doc(as('s2'), 'users/s1/rating_prompts/ended')));
    await assertFails(setDoc(doc(as('s2'), 'users/s1/rating_prompts/ended'), { timesShown: 99 }));
  });
});
