/**
 * Rating totals + duplicate clean-up against the Firestore emulator:
 *   firebase emulators:exec --only firestore --project demo-calligro \
 *     "cd functions && npx jest test/ratings.test.js"
 */
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const admin = require('firebase-admin');
const { onReviewChange, recomputeTeacher } = require('../ratings');
const { dedupeReviews } = require('../migrations/dedupe_reviews');

const app = admin.initializeApp({ projectId: 'demo-calligro-ratings-server' }, 'ratings-test');
const db = app.firestore();
const ts = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));

async function wipe() {
  for (const c of ['reviews', 'users', 'teachers', 'courses']) {
    const docs = await db.collection(c).listDocuments();
    await Promise.all(docs.map((d) => d.delete()));
  }
}

beforeEach(async () => {
  await wipe();
  await db.doc('users/t1').set({ role: 'teacher', totalStars: 999, reviewCount: 999 });
  await db.doc('teachers/t1').set({ role: 'teacher', totalStars: 999, reviewCount: 999 });
  await db.doc('courses/c1').set({ teacherId: 't1' });
  await db.doc('courses/c2').set({ teacherId: 't1' });
});

describe('totals are recomputed from the reviews (never incremented)', () => {
  it('teacher (users + teachers) and course totals', async () => {
    await db.doc('reviews/c1_s1').set({ teacherId: 't1', courseId: 'c1', studentId: 's1', rating: 5 });
    await db.doc('reviews/c1_s2').set({ teacherId: 't1', courseId: 'c1', studentId: 's2', rating: 4 });
    await db.doc('reviews/c2_s1').set({ teacherId: 't1', courseId: 'c2', studentId: 's1', rating: 3 });
    await onReviewChange(db, {}, { teacherId: 't1', courseId: 'c1' });
    expect((await db.doc('users/t1').get()).data()).toMatchObject({ totalStars: 12, reviewCount: 3 });
    expect((await db.doc('teachers/t1').get()).data()).toMatchObject({ totalStars: 12, reviewCount: 3 });
    expect((await db.doc('courses/c1').get()).data()).toMatchObject({ rating: 4.5, reviewCount: 2 });
  });

  it('a deleted review (admin moderation) is taken out of the totals', async () => {
    await db.doc('reviews/c1_s1').set({ teacherId: 't1', courseId: 'c1', studentId: 's1', rating: 5 });
    await recomputeTeacher(db, 't1');
    await db.doc('reviews/c1_s1').delete();
    await onReviewChange(db, { teacherId: 't1', courseId: 'c1' }, {});
    expect((await db.doc('users/t1').get()).data()).toMatchObject({ totalStars: 0, reviewCount: 0 });
    expect((await db.doc('courses/c1').get()).data()).toMatchObject({ rating: 0, reviewCount: 0 });
  });

  it('a missing teacher / course document is not created', async () => {
    await db.doc('reviews/x_s1').set({ teacherId: 'gone', courseId: 'gone-course', studentId: 's1', rating: 5 });
    await onReviewChange(db, {}, { teacherId: 'gone', courseId: 'gone-course' });
    expect((await db.doc('users/gone').get()).exists).toBe(false);
    expect((await db.doc('courses/gone-course').get()).exists).toBe(false);
  });
});

describe('dedupe_reviews migration', () => {
  beforeEach(async () => {
    // Sara rated c1 three times (old app), Omar once; one old review sits under a random id.
    await db.doc('reviews/r1').set({ teacherId: 't1', courseId: 'c1', studentId: 's1', rating: 2, timestamp: ts('2026-01-01') });
    await db.doc('reviews/r2').set({ teacherId: 't1', courseId: 'c1', studentId: 's1', rating: 5, timestamp: ts('2026-03-01') });
    await db.doc('reviews/r3').set({ teacherId: 't1', courseId: 'c1', studentId: 's1', rating: 3, timestamp: ts('2026-02-01') });
    await db.doc('reviews/r4').set({ teacherId: 't1', courseId: 'c2', studentId: 's2', rating: 4, timestamp: ts('2026-02-01') });
  });

  it('dry run changes nothing', async () => {
    const report = await dedupeReviews(db, { log: () => {} });
    expect(report).toMatchObject({ reviews: 4, pairs: 2, duplicatesRemoved: 2, moved: 2 });
    expect((await db.collection('reviews').get()).size).toBe(4);
    expect((await db.doc('users/t1').get()).data().totalStars).toBe(999);
  });

  it('apply: one review per student per course (the newest), at its fixed id, totals fixed', async () => {
    await dedupeReviews(db, { apply: true, log: () => {} });
    const ids = (await db.collection('reviews').get()).docs.map((d) => d.id).sort();
    expect(ids).toEqual(['c1_s1', 'c2_s2']);
    expect((await db.doc('reviews/c1_s1').get()).data().rating).toBe(5);
    expect((await db.doc('users/t1').get()).data()).toMatchObject({ totalStars: 9, reviewCount: 2 });
    expect((await db.doc('courses/c1').get()).data()).toMatchObject({ rating: 5, reviewCount: 1 });
  });

  it('running it again changes nothing', async () => {
    await dedupeReviews(db, { apply: true, log: () => {} });
    const again = await dedupeReviews(db, { apply: true, log: () => {} });
    expect(again).toMatchObject({ duplicatesRemoved: 0, moved: 0 });
    expect((await db.collection('reviews').get()).size).toBe(2);
  });
});
