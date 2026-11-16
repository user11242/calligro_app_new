/**
 * Withdrawal requests are created HERE, never by the app.
 *
 * The app used to write the request itself with any amount (the rules only
 * checked whose it was), so a modified app — or two quick taps / two phones
 * before the page reloaded — could ask for more than was earned. Now the
 * server works out the available balance with the same rules as the app
 * (lib/features/teacher_money/domain/earnings.dart) inside a transaction:
 * a second request for the same money finds it already taken.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const DAY = 24 * 60 * 60 * 1000;
const UNLOCK_DELAY = 2 * DAY;
/** = EarningsRules.earnedStatuses ("settled" = the admin confirmed the store paid). */
const EARNED_STATUSES = ["completed", "settled"];

const ms = (v) => (v && typeof v.toMillis === "function" ? v.toMillis() : v instanceof Date ? v.getTime() : null);
const num = (v) => (typeof v === "number" ? v : 0);

/** = EarningsRules.unlockDate: course end + 2 days; no end date → created + 30 + 2. */
function unlockAt(course, now) {
  if (!course) return null;
  const end = ms(course.endDate) ?? (ms(course.createdAt) != null ? ms(course.createdAt) + 30 * DAY : now);
  return end + UNLOCK_DELAY;
}

/** = WithdrawalRules.fee */
const feeFor = (method) => (method === "western" ? 10 : 0);

/** = EarningsRules.balance (withdrawals count their full requested amount). */
function balanceOf({ sales, courses, withdrawals, now }) {
  const byId = new Map(courses.map((c) => [c.id, c]));
  let total = 0, pending = 0, unlocked = 0;
  for (const s of sales) {
    const share = num(s.teacherShare);
    total += share;
    const unlock = unlockAt(byId.get(s.courseId), now);
    if (unlock == null || now < unlock) pending += share;
    else unlocked += share;
  }
  const withdrawn = withdrawals
    .filter((w) => w.status !== "rejected")
    .reduce((a, w) => a + num(w.requestedAmount ?? w.amount ?? w.netAmount), 0);
  return { total, pending, withdrawn, available: Math.max(0, unlocked - withdrawn) };
}

/** Creates the request for ALL of [uid]'s available money. Returns the stored amounts. */
async function createWithdrawal(db, uid, { methodLabel, now = Date.now() } = {}) {
  const user = (await db.collection("users").doc(uid).get()).data();
  if (!user || user.role !== "teacher") throw new HttpsError("permission-denied", "Only teachers can withdraw.");
  const payout = (await db.doc(`users/${uid}/private/payout`).get()).data();
  if (!payout || !payout.selectedMethod) throw new HttpsError("failed-precondition", "Add a payout method first.");

  return db.runTransaction(async (tx) => {
    const [salesSnap, coursesSnap, withdrawalsSnap] = await Promise.all([
      tx.get(db.collection("transactions").where("teacherId", "==", uid).where("status", "in", EARNED_STATUSES)),
      tx.get(db.collection("courses").where("teacherId", "==", uid)),
      tx.get(db.collection("withdrawal_requests").where("teacherId", "==", uid)),
    ]);
    const b = balanceOf({
      sales: salesSnap.docs.map((d) => d.data()),
      courses: coursesSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      withdrawals: withdrawalsSnap.docs.map((d) => d.data()),
      now,
    });
    const fee = feeFor(payout.selectedMethod);
    const net = b.available - fee;
    if (net <= 0) throw new HttpsError("failed-precondition", "No funds available to withdraw.");

    const label = typeof methodLabel === "string" && methodLabel.trim() ? methodLabel.trim() : payout.selectedMethod;
    const doc = {
      teacherId: uid,
      teacherName: user.name || "Teacher",
      method: label,
      payoutMethod: label, // as before (AdminPayoutsPage reads either)
      fee,
      requestedAmount: b.available,
      netAmount: net,
      amount: net, // as before
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    tx.set(db.collection("withdrawal_requests").doc(), doc);
    return { requestedAmount: b.available, netAmount: net, fee };
  });
}

exports.requestWithdrawal = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  try {
    return await createWithdrawal(admin.firestore(), request.auth.uid, { methodLabel: request.data && request.data.method });
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    console.error("requestWithdrawal failed", e);
    throw new HttpsError("internal", "Could not create the withdrawal request.");
  }
});

exports.balanceOf = balanceOf;
exports.unlockAt = unlockAt;
exports.feeFor = feeFor;
exports.createWithdrawal = createWithdrawal;
