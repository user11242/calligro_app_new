// --------------------
// Firebase Functions v2 with Brevo (Sendinblue)
// --------------------
const { https, setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const SibApiV3Sdk = require("sib-api-v3-sdk");
const crypto = require("crypto");
const { checkCode, normalizeEmail } = require("./email_codes.js");

/** = lib/features/auth/domain/account_keys.dart AccountKeys.phone */
function phoneKey(phone) {
  const foreign = "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹०१२३४५६७८९০১২৩৪৫৬৭৮৯";
  let out = "";
  for (const ch of String(phone || "")) {
    const i = foreign.indexOf(ch);
    if (i !== -1) out += String(i % 10);
    else if (/[0-9+]/.test(ch)) out += ch;
  }
  return out;
}
exports.phoneKey = phoneKey;

// --------------------
// Define Secret
// --------------------
const brevoApiKey = defineSecret("BREVO_API_KEY");

// --------------------
// Initialize Firebase Admin
// --------------------
admin.initializeApp();
// 5 copies per function is ample for current traffic and keeps the project under
// the Cloud Run CPU quota (max instances × CPU is reserved per function).
setGlobalOptions({ maxInstances: 5, region: "us-central1" });

// --------------------
// Export Modular Functions
// --------------------
exports.livekit = require("./livekit.js");
exports.transcoder = require("./transcoder.js");

// --------------------
// Utility: Generate OTP
// --------------------
function generateOtp() {
  return crypto.randomInt(100000, 999999).toString();
}

// --------------------
// Firestore Trigger: Notify Admin
// --------------------
exports.notifyAdminOnTeacherRegistration = onDocumentCreated(
  "users/{userId}",
  async (event) => {
    try {
      const newUser = event.data.data();
      if (!newUser || newUser.role !== "teacher" || newUser.status !== "pending") return null;

      const adminsSnap = await admin.firestore()
        .collection("users")
        .where("role", "==", "admin")
        .get();

      if (adminsSnap.empty) return null;

      // Import sendNotification from notifications module
      const { notifyAdminHelper } = require("./notifications.js");

      // Notify each admin individually using their preferred language
      const notifyPromises = adminsSnap.docs.map(adminDoc => {
        return notifyAdminHelper({
          receiverId: adminDoc.id,
          teacherName: newUser.name || "A new teacher",
          teacherUserId: event.params.userId,
        });
      });

      await Promise.all(notifyPromises);
    } catch (err) {
      console.error("notifyAdmin error:", err);
    }
    return null;
  }
);

// --------------------
// HTTPS Function: Send Email OTP
// --------------------
exports.sendEmailOtp = https.onRequest({ secrets: [brevoApiKey] }, async (req, res) => {
  try {
    const email = req.body.email;
    if (!email) return res.status(400).send({ success: false, error: "Email required" });

    const docRef = admin.firestore().collection("emailOtps").doc(email);
    const docSnap = await docRef.get();
    
    if (docSnap.exists) {
      const data = docSnap.data();
      if (data.createdAt && Date.now() - data.createdAt.toMillis() < 60000) {
        return res.status(429).send({ success: false, error: "Please wait 60 seconds before requesting another OTP." });
      }
    }

    const otp = generateOtp();
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000));
    const createdAt = admin.firestore.FieldValue.serverTimestamp();

    await docRef.set({ otp, expiresAt, createdAt });

    // 🔑 Setup Brevo client
    const defaultClient = SibApiV3Sdk.ApiClient.instance;
    defaultClient.authentications["api-key"].apiKey = brevoApiKey.value();

    const apiInstance = new SibApiV3Sdk.TransactionalEmailsApi();
    const sendSmtpEmail = {
      to: [{ email }],
      sender: { email: "no-reply@calligroacademy.com", name: "Calligro" },
      subject: "Your OTP Code",
      textContent: `Your OTP is ${otp}. It is valid for 10 minutes.`,
    };

    await apiInstance.sendTransacEmail(sendSmtpEmail);

    console.log(`✅ OTP sent to ${email}`);
    return res.status(200).send({ success: true });
  } catch (err) {
    console.error("sendEmailOtp error:", err.response?.body || err.message);
    return res.status(500).send({ success: false, error: err.message });
  }
});

// --------------------
// HTTPS Function: Verify OTP
// --------------------
exports.verifyEmailOtp = https.onRequest(async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) return res.status(400).send({ valid: false });

    const docRef = admin.firestore().collection("emailOtps").doc(email);
    const doc = await docRef.get();
    if (!doc.exists) return res.status(200).send({ valid: false });

    const data = doc.data();
    if (data.otp === otp && data.expiresAt.toMillis() > Date.now()) {
      await docRef.delete();
      return res.status(200).send({ valid: true });
    }

    return res.status(200).send({ valid: false });
  } catch (err) {
    console.error("verifyEmailOtp error:", err);
    return res.status(500).send({ valid: false, error: err.message });
  }
});

// --------------------
// Callable Function: Delete User Account
// --------------------
const { onCall, HttpsError } = require("firebase-functions/v2/https");

exports.deleteUserAccount = onCall(async (request) => {
  try {
    // 1. Check Authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    // 2. Check Admin Role (Optional but recommended security)
    const requesterUid = request.auth.uid;
    const requesterDoc = await admin.firestore().collection("users").doc(requesterUid).get();
    if (!requesterDoc.exists || requesterDoc.data().role !== "admin") {
      throw new HttpsError("permission-denied", "Only admins can delete user accounts.");
    }

    // 3. Get Target UID
    const targetUid = request.data.uid;
    if (!targetUid) {
      throw new HttpsError("invalid-argument", "The function must be called with a 'uid' argument.");
    }

    // 4. Delete from Firebase Authentication
    await admin.auth().deleteUser(targetUid);
    console.log(`Successfully deleted user ${targetUid} from Authentication.`);

    return { success: true, message: `User ${targetUid} deleted from Auth.` };

  } catch (error) {
    console.error("Error deleting user:", error);

    // Re-throw HttpsError or wrap others
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "Unable to delete user account.", error);
  }
});

// --------------------
// Callable Function: Delete Own Account
// --------------------
exports.deleteOwnAccount = onCall(async (request) => {
  try {
    // 1. Check Authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const uid = request.auth.uid;
    console.log(`[DeleteOwnAccount] Proceeding to delete account for user: ${uid}`);

    // 2. Fetch user data to know what to clean up (locks, etc)
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) {
      console.warn(`[DeleteOwnAccount] User document for ${uid} not found. Proceeding with Auth deletion.`);
    }

    const data = userDoc.data() || {};
    const email = data.email || "";
    const name = data.name || "";
    const phone = data.phone || "";

    const batch = admin.firestore().batch();

    // 3. Queue Firestore Cleanup
    // Delete user and teacher docs
    batch.delete(admin.firestore().collection("users").doc(uid));
    batch.delete(admin.firestore().collection("teachers").doc(uid));

    // 4. Unlock credentials (so they can sign up again)
    if (email) {
      const emailKey = email.trim().toLowerCase();
      batch.delete(admin.firestore().collection("locked_emails").doc(emailKey));
    }
    if (name) {
      const nameKey = name.trim().toLowerCase();
      batch.delete(admin.firestore().collection("locked_usernames").doc(nameKey));
    }
    if (phone) {
      // Same key as the app's AccountKeys.phone (foreign digits → 0-9, keep "+").
      const cleanPhone = phoneKey(phone);
      batch.delete(admin.firestore().collection("locked_phones").doc(cleanPhone));
    }

    // 5. Commit Firestore changes
    await batch.commit();
    console.log(`[DeleteOwnAccount] Firestore data (profile and locks) cleaned up for ${uid}`);

    // 6. Delete from Firebase Authentication
    await admin.auth().deleteUser(uid);
    console.log(`[DeleteOwnAccount] Auth account deleted for ${uid}`);

    return { success: true, message: "Account deleted successfully." };

  } catch (error) {
    console.error("[DeleteOwnAccount] Error:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "Unable to delete your account.", error);
  }
});

// --------------------
// HTTPS Callable: Reset Password with OTP
// --------------------
exports.resetPasswordWithOtp = onCall(async (request) => {
  const { email, otp, newPassword } = request.data;

  // Validate inputs
  if (!email || !otp || !newPassword) {
    throw new HttpsError("invalid-argument", "Email, OTP, and new password are required.");
  }

  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }

  try {
    // 1. Verify AND use up the code (5 wrong tries and it stops working).
    const check = await checkCode(admin.firestore(), email, otp, { consume: true });
    if (check === "missing") {
      throw new HttpsError("permission-denied", "No verification code found for this email.");
    }
    if (check !== "ok") {
      throw new HttpsError("permission-denied", "Invalid or expired verification code.");
    }

    // 2. Get user by email
    const userRecord = await admin.auth().getUserByEmail(normalizeEmail(email));

    // 3. Update the user's password
    await admin.auth().updateUser(userRecord.uid, {
      password: newPassword,
    });

    console.log(`Successfully reset password for user: ${email}`);

    return {
      success: true,
      message: "Password reset successful!"
    };
  } catch (error) {
    console.error("Error resetting password:", error);

    if (error instanceof HttpsError) throw error;
    if (error.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "No user found with this email.");
    }

    throw new HttpsError("internal", "Unable to reset password. Please try again.");
  }
});

// --------------------
// Callable Function: Get User Providers
// --------------------
exports.getUserProviders = onCall(async (request) => {
  const { email } = request.data;

  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    const providers = userRecord.providerData.map((provider) => provider.providerId);
    return { providers };
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return { providers: [] };
    }
    throw new HttpsError("internal", "Unable to fetch user providers.", error);
  }
});

// --------------------
// HTTPS Callable: Verify Purchase (Premium IAP Security)
// --------------------
// In-app purchases (Apple / Google Play) and free courses — logic and tests in purchases.js.
const purchases = require("./purchases.js");

exports.verifyPurchase = onCall(async (request) => {
  try {
    return await purchases.handleVerifyPurchase(request, {
      db: admin.firestore(),
      verifyApple: purchases.verifyAppleReceipt,
      verifyGoogle: purchases.verifyGooglePurchase,
    });
  } catch (e) {
    throw purchases.asCallableError(e);
  }
});

exports.enrollInFreeCourse = onCall({ region: "us-central1", enforceAppCheck: false }, async (request) => {
  try {
    return await purchases.handleEnrollFree(request, { db: admin.firestore() });
  } catch (e) {
    throw purchases.asCallableError(e);
  }
});

// --------------------
// Import Notifications
// --------------------
Object.assign(exports, require("./notifications.js"));

// Keeps name / photo copies (courses, posts, comments, replies) in sync after a profile edit.
exports.syncProfileCopiesOnUpdate = require("./profile_sync.js").syncProfileCopiesOnUpdate;
// Rating totals recomputed from the reviews (the app no longer touches them).
exports.recomputeRatingsOnReview = require("./ratings.js").recomputeRatingsOnReview;
// One push token per account (a phone switching accounts got 2-3 copies).
exports.claimPushToken = require("./notification_tokens.js").claimPushToken;
// Email codes created, sent and checked on the server (the app no longer holds the Brevo key).
exports.sendEmailCode = require("./email_codes.js").sendEmailCode;
exports.verifyEmailCode = require("./email_codes.js").verifyEmailCode;
// Withdrawal requests are created by the server from the real balance.
exports.requestWithdrawal = require("./withdrawals.js").requestWithdrawal;

exports.rescheduleNextSession = require("./schedule.js").rescheduleNextSession;
exports.cancelNextSessionReschedule = require("./schedule.js").cancelNextSessionReschedule;

