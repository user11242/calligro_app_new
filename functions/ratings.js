/**
 * Teacher and course rating totals, computed by the server from the reviews.
 *
 * The app used to add stars to the teacher's document itself, so a failed or
 * repeated submission (or anyone at all — the rules allowed ±5 stars per
 * write) skewed the totals. Now every change to a review recomputes, from the
 * reviews themselves:
 *   users/{teacherId}    totalStars, reviewCount   (app + web read these)
 *   teachers/{teacherId} same, when that document exists
 *   courses/{courseId}   rating (average), reviewCount (web teacher dashboard)
 * Recomputing (not incrementing) is idempotent and self-healing.
 */
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { AggregateField } = require("firebase-admin/firestore");

async function totals(query) {
  const snap = await query.aggregate({ count: AggregateField.count(), stars: AggregateField.sum("rating") }).get();
  const { count, stars } = snap.data();
  return { reviewCount: count || 0, totalStars: stars || 0 };
}

async function recomputeTeacher(db, teacherId) {
  if (!teacherId) return null;
  const t = await totals(db.collection("reviews").where("teacherId", "==", teacherId));
  for (const collection of ["users", "teachers"]) {
    const ref = db.collection(collection).doc(teacherId);
    if ((await ref.get()).exists) await ref.update(t);
  }
  return t;
}

async function recomputeCourse(db, courseId) {
  if (!courseId) return null;
  const t = await totals(db.collection("reviews").where("courseId", "==", courseId));
  const ref = db.collection("courses").doc(courseId);
  const rating = t.reviewCount ? Math.round((t.totalStars / t.reviewCount) * 10) / 10 : 0;
  if ((await ref.get()).exists) await ref.update({ rating, reviewCount: t.reviewCount });
  return { rating, reviewCount: t.reviewCount };
}

/** Recomputes every teacher / course a review change touched (before and after). */
async function onReviewChange(db, before = {}, after = {}) {
  const teachers = new Set([before.teacherId, after.teacherId].filter(Boolean));
  const courses = new Set([before.courseId, after.courseId].filter(Boolean));
  for (const t of teachers) await recomputeTeacher(db, t);
  for (const c of courses) await recomputeCourse(db, c);
}

exports.recomputeTeacher = recomputeTeacher;
exports.recomputeCourse = recomputeCourse;
exports.onReviewChange = onReviewChange;

exports.recomputeRatingsOnReview = onDocumentWritten("reviews/{reviewId}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : {};
  const after = event.data.after.exists ? event.data.after.data() : {};
  await onReviewChange(admin.firestore(), before, after);
});
