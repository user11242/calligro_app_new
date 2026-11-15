/**
 * Email verification codes: created, emailed and CHECKED on the server.
 *
 * Before, the app made up the 6-digit code itself, emailed it with a Brevo
 * key bundled in the app, and compared what the user typed on the phone — a
 * modified app could skip the check, and password reset never worked (the
 * server was asked to check a code it never had). Now:
 *   sendEmailCode   creates the code (stored server-side only), emails it
 *   verifyEmailCode checks it (registration: used up; reset: kept for the
 *                   final step, which uses it up)
 *   resetPasswordWithOtp (index.js) checks + uses it up via checkCode()
 * A code allows MAX_ATTEMPTS wrong tries, then stops working (no guessing).
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");

const brevoApiKey = defineSecret("BREVO_API_KEY");

const MAX_ATTEMPTS = 5;
const TTL_MS = 10 * 60 * 1000;
const COOLDOWN_MS = 60 * 1000;

/** Same email typed with different capitals is the same email. */
const normalizeEmail = (email) => String(email || "").trim().toLowerCase();

const isEmail = (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

const generateCode = () => crypto.randomInt(100000, 1000000).toString();

const ref = (db, email) => db.collection("emailOtps").doc(normalizeEmail(email));

/** Creates a fresh code for [email]. Throws 'cooldown' if asked again within a minute. */
async function issueCode(db, email, now = Date.now()) {
  const doc = await ref(db, email).get();
  const created = doc.exists ? doc.data().createdAt : null;
  if (created && now - created.toMillis() < COOLDOWN_MS) throw new Error("cooldown");
  const code = generateCode();
  await ref(db, email).set({
    otp: code,
    attempts: 0,
    createdAt: admin.firestore.Timestamp.fromMillis(now),
    expiresAt: admin.firestore.Timestamp.fromMillis(now + TTL_MS),
  });
  return code;
}

/**
 * Checks [code] for [email]: 'ok' | 'wrong' | 'expired' | 'missing' | 'locked'.
 * A wrong code counts an attempt; after MAX_ATTEMPTS the code is deleted.
 * [consume] deletes the code once it was right (it can only be used once).
 */
async function checkCode(db, email, code, { consume = true, now = Date.now() } = {}) {
  const r = ref(db, email);
  return db.runTransaction(async (tx) => {
    const doc = await tx.get(r);
    if (!doc.exists) return "missing";
    const d = doc.data();
    if (!d.expiresAt || d.expiresAt.toMillis() <= now) {
      tx.delete(r);
      return "expired";
    }
    if (String(code || "").trim() !== d.otp) {
      const attempts = (d.attempts || 0) + 1;
      if (attempts >= MAX_ATTEMPTS) {
        tx.delete(r);
        return "locked";
      }
      tx.update(r, { attempts });
      return "wrong";
    }
    if (consume) tx.delete(r);
    return "ok";
  });
}

/** The same email design the app used to send. */
function codeEmailHtml(code) {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 0; }
    .container { max-width: 500px; margin: 30px auto; background: #ffffff; padding: 20px; border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.1); }
    .header { text-align: center; padding-bottom: 20px; border-bottom: 1px solid #eeeeee; }
    .header h1 { color: #ffca28; margin: 0; font-size: 24px; }
    .content { padding: 20px; text-align: center; color: #333333; }
    .otp-code { font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #000000; background: #fff8e1; padding: 15px; border-radius: 5px; display: inline-block; margin: 20px 0; border: 1px dashed #ffca28; }
    .footer { text-align: center; font-size: 12px; color: #888888; margin-top: 20px; border-top: 1px solid #eeeeee; padding-top: 10px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Calligro</h1>
    </div>
    <div class="content">
      <p style="font-size: 16px;">Hello,</p>
      <p>Use the code below to verify your account.</p>
      <div class="otp-code">${code}</div>
      <p style="font-size: 14px; color: #666;">This code expires in <strong>10 minutes</strong>.</p>
      <p>If you didn't request this, you can safely ignore this email.</p>
    </div>
    <div class="footer">
      <p>&copy; 2026 Calligro Team. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`;
}

async function sendCodeEmail(apiKey, email, code, fetchImpl = fetch) {
  const res = await fetchImpl("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { accept: "application/json", "api-key": apiKey, "content-type": "application/json" },
    body: JSON.stringify({
      sender: { name: "Calligro Team", email: "no-reply@calligroacademy.com" },
      to: [{ email }],
      subject: "Your Calligro Verification Code",
      htmlContent: codeEmailHtml(code),
    }),
  });
  if (!res.ok) throw new Error(`Brevo ${res.status}`);
}

exports.sendEmailCode = onCall({ secrets: [brevoApiKey] }, async (request) => {
  const email = normalizeEmail(request.data && request.data.email);
  if (!isEmail(email)) throw new HttpsError("invalid-argument", "A valid email is required.");
  let code;
  try {
    code = await issueCode(admin.firestore(), email);
  } catch (e) {
    if (e.message === "cooldown") {
      throw new HttpsError("resource-exhausted", "Please wait 60 seconds before requesting another code.");
    }
    throw new HttpsError("internal", "Could not create a code.");
  }
  try {
    await sendCodeEmail(brevoApiKey.value(), email, code);
  } catch (e) {
    console.error("sendEmailCode: email failed", e.message);
    throw new HttpsError("unavailable", "Could not send the email. Please try again.");
  }
  return { success: true };
});

exports.verifyEmailCode = onCall(async (request) => {
  const { email, code, purpose } = request.data || {};
  if (!email || !code) throw new HttpsError("invalid-argument", "Email and code are required.");
  // Password reset keeps the code for its final step (resetPasswordWithOtp uses it up).
  const result = await checkCode(admin.firestore(), email, code, { consume: purpose !== "reset" });
  return { valid: result === "ok", result };
});

exports.normalizeEmail = normalizeEmail;
exports.issueCode = issueCode;
exports.checkCode = checkCode;
exports.codeEmailHtml = codeEmailHtml;
exports.sendCodeEmail = sendCodeEmail;
exports.MAX_ATTEMPTS = MAX_ATTEMPTS;
