/**
 * Delivers ONE notification to ONE user, at most once per event.
 *
 * Cloud Functions run a trigger at least once — a retry used to send the
 * same push again (and add a second inbox item). The inbox item's id is now
 * the event's key, created with create(): a second run finds it already
 * there and sends nothing.
 *
 * The inbox item stores the push's `data` (route + ids), so tapping it in
 * the app opens the same screen as tapping the push (see
 * lib/features/notifications/domain/notification_models.dart for the routes).
 */
const admin = require("firebase-admin");

const ALREADY_EXISTS = 6;

/** FCM data values must be strings. */
function stringData(obj = {}) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) if (v !== undefined && v !== null) out[k] = String(v);
  return out;
}

/**
 * @param {object} o
 * @param {FirebaseFirestore.Firestore} o.db
 * @param {{send: Function}} o.messaging
 * @param {string} o.receiverId
 * @param {string} o.key        unique per event (event.id) — the inbox item's id
 * @param {string} o.type
 * @param {(lang: string, user: object) => {title: string, body: string}} o.render  (user: the receiver's profile)
 * @param {object} [o.payload]  route + ids
 * @returns {Promise<'sent'|'inbox-only'|'duplicate'|'no-user'>}
 */
async function deliverOnce({ db, messaging, receiverId, key, type, render, payload = {} }) {
  if (!receiverId || !key) throw new Error("deliverOnce needs receiverId and key");
  const userDoc = await db.collection("users").doc(receiverId).get();
  if (!userDoc.exists) return "no-user";
  const user = userDoc.data();
  const { title, body } = render(user.preferredLanguage || "en", user);
  const data = stringData(payload);

  try {
    await db.collection("users").doc(receiverId).collection("notifications").doc(key).create({
      title,
      body,
      type,
      read: false,
      data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    if (e.code === ALREADY_EXISTS) return "duplicate"; // a retry: already delivered
    throw e;
  }

  if (!user.fcmToken) return "inbox-only";
  await messaging.send({
    token: user.fcmToken,
    notification: { title, body },
    data: { type, title, body, ...data },
    android: { priority: "high", notification: { channelId: "calligro_alerts" } },
    apns: { payload: { aps: { alert: { title, body }, sound: "default" } } },
  });
  return "sent";
}

module.exports = { deliverOnce, stringData };
