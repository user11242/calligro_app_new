/**
 * App enrolment: in-app purchases (Apple / Google Play) and free courses.
 *
 * The rules that were missing before:
 *  - the product bought must be THIS course's product (a cheap tier never
 *    unlocks an expensive course), checked before / after the store check;
 *  - one store transaction enrols exactly one user in one course, atomically
 *    (orders/{transactionId} is created in the same Firestore transaction);
 *  - Apple: use this product's newest unused transaction, not in_app[0];
 *  - already enrolled → no second seat / count; a full course is refused
 *    before anything is recorded.
 * The accounting (order + transaction documents) is unchanged.
 */
const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const PRODUCT_PREFIX = "com.yazan.calligro.tier_";
const STORE_FEE = 0.30; // Apple / Google commission

function expectedProductId(course) {
  return course.iapProductId || `${PRODUCT_PREFIX}${Math.trunc(Number(course.price || 0))}`;
}

function tierOf(productId) {
  const m = /tier_(\d+)$/.exec(String(productId || ""));
  return m ? Number(m[1]) : null;
}

/** The product must be the course's product AND not a cheaper tier than the price. */
function isProductValidForCourse(productId, course) {
  if (!productId || productId !== expectedProductId(course)) return false;
  const tier = tierOf(productId);
  return tier === null || tier >= Math.trunc(Number(course.price || 0));
}

/** Apple receipt transactions for [productId], newest first. */
function appleCandidates(receipt, productId) {
  const all = [...((receipt && receipt.in_app) || []), ...((receipt && receipt.latest_receipt_info) || [])];
  const seen = new Set();
  return all
    .filter((t) => t && t.product_id === productId && !seen.has(t.transaction_id) && seen.add(t.transaction_id))
    .sort((a, b) => Number(b.purchase_date_ms || 0) - Number(a.purchase_date_ms || 0));
}

function enrolledIds(course) {
  return Array.isArray(course.enrolledStudents) ? course.enrolledStudents : [];
}

function isFull(course, uid) {
  const max = Number(course.maxStudents || 0);
  if (max <= 0 || enrolledIds(course).includes(uid)) return false;
  return Math.max(Number(course.enrolledCount || 0), enrolledIds(course).length) >= max;
}

/** Enrols [uid] for store transaction [transactionId], once, with the order + ledger records. */
async function enrollAfterPurchase(db, { uid, courseId, transactionId, productId, environment, source }) {
  const FieldValue = admin.firestore.FieldValue;
  const orderRef = db.collection("orders").doc(String(transactionId));
  const courseRef = db.collection("courses").doc(courseId);
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (t) => {
    const [order, course, user] = await Promise.all([t.get(orderRef), t.get(courseRef), t.get(userRef)]);
    if (order.exists) {
      const o = order.data();
      if (o.uid === uid && o.courseId === courseId) return { status: "duplicate" };
      throw new HttpsError("already-exists", "This purchase was already used.");
    }
    if (!course.exists) throw new HttpsError("not-found", "Course not found.");
    const c = course.data();
    if (isFull(c, uid)) throw new HttpsError("failed-precondition", "This course is fully booked.");

    let commissionRate = 0.0;
    if (c.teacherId) {
      const teacher = await t.get(db.collection("users").doc(c.teacherId));
      if (teacher.exists) {
        const rate = teacher.data().commissionRate;
        if (rate === undefined) throw new HttpsError("failed-precondition", "Teacher commission rate is not set by admin yet.");
        commissionRate = Number(rate);
      }
    }

    const u = user.data() || {};
    const basePrice = Number(c.price || 0);
    const totalPaid = basePrice;
    const fee = totalPaid * STORE_FEE;
    const net = totalPaid - fee;
    const teacherShare = net * commissionRate;
    const academyShare = net - teacherShare;
    const already = enrolledIds(c).includes(uid);
    const now = FieldValue.serverTimestamp();

    t.set(orderRef, {
      uid,
      studentName: u.name || "Unknown Student",
      studentEmail: u.email || "",
      courseId,
      courseName: c.courseName || "Unknown Course",
      courseArabicName: c.courseArabicName || "",
      teacherId: c.teacherId || "",
      teacherName: c.teacherName || "Unknown Teacher",
      productId,
      transactionId: String(transactionId),
      price: totalPaid,
      basePrice,
      actualPrice: basePrice / 2,
      fee,
      teacherShare,
      academyShare,
      timestamp: now,
      environment: environment || "unknown",
    });
    t.set(db.collection("transactions").doc(), {
      amount: totalPaid,
      basePrice,
      actualPrice: basePrice / 2,
      fee,
      teacherShare,
      academyShare,
      teacherId: c.teacherId || "",
      teacherName: c.teacherName || "Unknown Teacher",
      courseId,
      courseName: c.courseName || "Unknown Course",
      studentId: uid,
      studentName: u.name || "Unknown Student",
      createdAt: now,
      status: "completed",
      source,
    });
    if (!already) {
      t.update(courseRef, { enrolledStudents: FieldValue.arrayUnion(uid), enrolledCount: FieldValue.increment(1) });
    }
    t.set(userRef, { enrolledCourses: FieldValue.arrayUnion(courseId) }, { merge: true });
    return { status: already ? "already_enrolled" : "enrolled" };
  });
}

/**
 * verifyPurchase callable. deps.verifyApple(receiptData) → Apple's verifyReceipt JSON;
 * deps.verifyGoogle({ productId, token }) → Google's purchases.products resource.
 */
async function handleVerifyPurchase(request, deps) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be logged in to verify purchase.");
  const { receiptData, purchaseToken, courseId, productId, platform = "ios" } = request.data || {};
  if (!courseId) throw new HttpsError("invalid-argument", "courseId is required.");
  const uid = request.auth.uid;
  const db = deps.db;

  const courseSnap = await db.collection("courses").doc(String(courseId)).get();
  if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
  const course = courseSnap.data();
  const wanted = expectedProductId(course);

  let transactionId;
  let environment;
  if (platform === "android") {
    if (!isProductValidForCourse(productId, course)) {
      throw new HttpsError("permission-denied", "This purchase is not for this course.");
    }
    const token = purchaseToken || receiptData;
    if (!token) throw new HttpsError("invalid-argument", "purchaseToken is required.");
    const purchase = await deps.verifyGoogle({ productId, token });
    if (!purchase || purchase.purchaseState !== 0) {
      throw new HttpsError("permission-denied", "Google Play purchase is not completed.");
    }
    transactionId = purchase.orderId || token;
    environment = purchase.purchaseType === 0 ? "sandbox" : "production";
  } else {
    if (!receiptData) throw new HttpsError("invalid-argument", "receiptData is required.");
    const result = await deps.verifyApple(receiptData);
    if (!result || result.status !== 0) {
      throw new HttpsError("permission-denied", `Apple validation failed with status ${result && result.status}`);
    }
    if (!isProductValidForCourse(wanted, course)) {
      throw new HttpsError("permission-denied", "This course's product is misconfigured.");
    }
    const candidates = appleCandidates(result.receipt, wanted);
    if (!candidates.length) throw new HttpsError("permission-denied", "This purchase is not for this course.");
    // Newest transaction not yet used; if all are used, the newest (→ duplicate / already used).
    let chosen = candidates[0];
    for (const c of candidates) {
      if (!(await db.collection("orders").doc(String(c.transaction_id)).get()).exists) {
        chosen = c;
        break;
      }
    }
    transactionId = chosen.transaction_id;
    environment = result.environment || "unknown";
  }

  const outcome = await enrollAfterPurchase(db, {
    uid,
    courseId: String(courseId),
    transactionId,
    productId: wanted,
    environment,
    source: "app",
  });
  console.log(`verifyPurchase: ${uid} / ${courseId} / ${transactionId} → ${outcome.status}`);
  return { success: true, transactionId: String(transactionId), status: outcome.status, message: "Purchase verified and course unlocked." };
}

/** enrollInFreeCourse callable: free courses only, once per student. */
async function handleEnrollFree(request, deps) {
  if (!request.auth) throw new HttpsError("unauthenticated", "You must be logged in to enroll.");
  const courseId = request.data && request.data.courseId;
  if (!courseId) throw new HttpsError("invalid-argument", "courseId is required.");
  const uid = request.auth.uid;
  const db = deps.db;
  const FieldValue = admin.firestore.FieldValue;
  const courseRef = db.collection("courses").doc(String(courseId));
  const userRef = db.collection("users").doc(uid);

  const status = await db.runTransaction(async (t) => {
    const [course, user] = await Promise.all([t.get(courseRef), t.get(userRef)]);
    if (!course.exists) throw new HttpsError("not-found", "Course not found.");
    const c = course.data();
    if (Number(c.price || 0) > 0) throw new HttpsError("permission-denied", "Cannot enroll in paid course for free.");
    if (enrolledIds(c).includes(uid)) return "already_enrolled";
    if (isFull(c, uid)) throw new HttpsError("failed-precondition", "This course is fully booked.");
    const u = user.data() || {};
    t.update(courseRef, { enrolledStudents: FieldValue.arrayUnion(uid), enrolledCount: FieldValue.increment(1) });
    t.set(userRef, { enrolledCourses: FieldValue.arrayUnion(String(courseId)) }, { merge: true });
    t.set(db.collection("transactions").doc(), {
      studentId: uid,
      studentName: u.name || "Academy Student",
      teacherId: c.teacherId || "",
      teacherName: c.teacherName || "Unknown Teacher",
      courseId: String(courseId),
      courseName: c.courseName || c.courseTitle || c.title || "Untitled Course",
      amount: 0,
      currency: "USD",
      source: "free_enrollment",
      status: "completed",
      teacherShare: 0,
      academyProfit: 0,
      storeFee: 0,
      createdAt: FieldValue.serverTimestamp(),
    });
    return "enrolled";
  });
  return { success: true, status, message: "Enrolled successfully in free course." };
}

// ── Real store verifiers ────────────────────────────────────────────────────
async function verifyAppleReceipt(receiptData) {
  const post = (url) =>
    fetch(url, { method: "POST", body: JSON.stringify({ "receipt-data": receiptData }) }).then((r) => r.json());
  let result = await post("https://buy.itunes.apple.com/verifyReceipt");
  if (result.status === 21007) result = await post("https://sandbox.itunes.apple.com/verifyReceipt"); // sandbox receipt
  return result;
}

async function verifyGooglePurchase({ productId, token }) {
  const { google } = require("googleapis");
  const auth = new google.auth.GoogleAuth({ scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
  const publisher = google.androidpublisher({ version: "v3", auth });
  try {
    const res = await publisher.purchases.products.get({ packageName: "com.yazan.calligro", productId, token });
    return res.data;
  } catch (e) {
    console.error("Google Play validation failed:", e);
    throw new HttpsError("permission-denied", "Google Play validation failed.");
  }
}

function asCallableError(e) {
  if (e instanceof HttpsError) return e;
  console.error(e);
  return new HttpsError("internal", "Something went wrong. Please try again.");
}

module.exports = {
  expectedProductId,
  isProductValidForCourse,
  appleCandidates,
  enrollAfterPurchase,
  handleVerifyPurchase,
  handleEnrollFree,
  verifyAppleReceipt,
  verifyGooglePurchase,
  asCallableError,
};
