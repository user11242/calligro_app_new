/**
 * One-off: remove duplicate course ratings and recompute every total.
 *
 * Older app versions saved each rating under a random id and kept asking, so
 * some students rated the same course several times. This keeps ONE review per
 * (student, course) — the newest — at its fixed id `<courseId>_<studentId>`
 * (the only id the new rules accept), deletes the rest, then recomputes the
 * totals of every teacher and course that has reviews.
 *
 *   Dry run (changes nothing, prints what it would do):
 *     node migrations/dedupe_reviews.js
 *   Apply:
 *     node migrations/dedupe_reviews.js --apply
 *
 * Safe to run more than once. Uses the Admin SDK (bypasses rules): run with
 * credentials for the project, e.g. `gcloud auth application-default login`
 * + GOOGLE_CLOUD_PROJECT=<id>.
 */
const admin = require("firebase-admin");
const { recomputeTeacher, recomputeCourse } = require("../ratings");

const millis = (v) => (v && typeof v.toMillis === "function" ? v.toMillis() : 0);

async function dedupeReviews(db, { apply = false, log = console.log } = {}) {
  const report = { reviews: 0, pairs: 0, duplicatesRemoved: 0, moved: 0, teachers: 0, courses: 0 };
  const snap = await db.collection("reviews").get();
  report.reviews = snap.size;

  const groups = new Map(); // "<courseId>_<studentId>" → docs
  for (const d of snap.docs) {
    const { courseId, studentId } = d.data();
    if (!courseId || !studentId) continue;
    const key = `${courseId}_${studentId}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(d);
  }
  report.pairs = groups.size;

  const teachers = new Set();
  const courses = new Set();
  const writer = apply ? db.bulkWriter() : null;
  for (const [key, docs] of groups) {
    docs.sort((a, b) => millis(b.data().timestamp) - millis(a.data().timestamp));
    const keep = docs[0];
    teachers.add(keep.data().teacherId);
    courses.add(keep.data().courseId);
    const extras = docs.slice(1);
    if (extras.length) log(`${key}: keeping newest of ${docs.length}`);
    report.duplicatesRemoved += extras.length;
    if (keep.id !== key) {
      report.moved++;
      if (writer) writer.set(db.collection("reviews").doc(key), keep.data());
    }
    for (const d of [...extras, ...(keep.id !== key ? [keep] : [])]) {
      if (d.id === key) continue;
      if (writer) writer.delete(d.ref);
    }
  }
  if (writer) await writer.close();

  if (apply) {
    for (const t of teachers) if (t) { await recomputeTeacher(db, t); report.teachers++; }
    for (const c of courses) if (c) { await recomputeCourse(db, c); report.courses++; }
  } else {
    report.teachers = [...teachers].filter(Boolean).length;
    report.courses = [...courses].filter(Boolean).length;
  }
  log(`${apply ? "APPLIED" : "DRY RUN"}: ${JSON.stringify(report)}`);
  return report;
}

module.exports = { dedupeReviews };

if (require.main === module) {
  admin.initializeApp();
  dedupeReviews(admin.firestore(), { apply: process.argv.includes("--apply") })
    .then(() => process.exit(0))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}
