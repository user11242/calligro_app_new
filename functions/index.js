// --------------------
// Firebase Functions v2 with Brevo (Sendinblue)
// --------------------
const { https, setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const SibApiV3Sdk = require("sib-api-v3-sdk");

// --------------------
// Define Secret
// --------------------
const brevoApiKey = defineSecret("BREVO_API_KEY");

// --------------------
// Initialize Firebase Admin
// --------------------
admin.initializeApp();
setGlobalOptions({ maxInstances: 10 });

// --------------------
// Utility: Generate OTP
// --------------------
function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
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

      const tokens = adminsSnap.docs.map(doc => doc.data().fcmToken).filter(Boolean);
      if (tokens.length === 0) return null;

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "New Teacher Registration",
          body: `${newUser.name || "A new teacher"} is waiting for approval.`,
        },
        data: { userId: event.params.userId, type: "new_teacher" },
      });
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

    const otp = generateOtp();
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000));

    await admin.firestore().collection("emailOtps").doc(email).set({ otp, expiresAt });

    // 🔑 Setup Brevo client
    const defaultClient = SibApiV3Sdk.ApiClient.instance;
    defaultClient.authentications["api-key"].apiKey = brevoApiKey.value();

    const apiInstance = new SibApiV3Sdk.TransactionalEmailsApi();
    const sendSmtpEmail = {
      to: [{ email }],
      sender: { email: "no-reply@calligro.digital", name: "Calligro" },
      subject: "Your OTP Code",
      textContent: `Your OTP is ${otp}. It is valid for 10 minutes.`,
    };

    await apiInstance.sendTransacEmail(sendSmtpEmail);

    console.log(`✅ OTP sent to ${email}: ${otp}`);
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
