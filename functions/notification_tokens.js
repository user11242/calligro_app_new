/**
 * One push token belongs to ONE account.
 *
 * A phone used by several accounts kept its token on each of them, so every
 * notification sent to those accounts arrived on the phone 2-3 times (and the
 * signed-out accounts' notifications kept arriving). When an account saves a
 * token, it is removed from every other account.
 */
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

async function releaseTokenFromOthers(db, uid, token) {
  if (!token) return 0;
  const snap = await db.collection("users").where("fcmToken", "==", token).get();
  const others = snap.docs.filter((d) => d.id !== uid);
  await Promise.all(others.map((d) => d.ref.update({ fcmToken: admin.firestore.FieldValue.delete() })));
  return others.length;
}

exports.releaseTokenFromOthers = releaseTokenFromOthers;

exports.claimPushToken = onDocumentWritten("users/{uid}", async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : {};
  const after = event.data.after.exists ? event.data.after.data() : {};
  if (!after.fcmToken || after.fcmToken === before.fcmToken) return;
  await releaseTokenFromOthers(admin.firestore(), event.params.uid, after.fcmToken);
});
