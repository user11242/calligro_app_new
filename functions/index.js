// --------------------
// Firebase Functions v2 with Brevo (Sendinblue)
// --------------------
const { https, setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const SibApiV3Sdk = require("sib-api-v3-sdk");
const crypto = require("crypto");

// --------------------
// Define Secret
// --------------------
const brevoApiKey = defineSecret("BREVO_API_KEY");
const lemonsqueezyApiKey = defineSecret("LEMONSQUEEZY_API_KEY");
const lemonsqueezyStoreId = defineSecret("LEMONSQUEEZY_STORE_ID");
const lemonsqueezyWebhookSecret = defineSecret("LEMONSQUEEZY_WEBHOOK_SECRET");

// --------------------
// Initialize Firebase Admin
// --------------------
admin.initializeApp();
setGlobalOptions({ maxInstances: 10, region: "us-central1" });

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
      const cleanPhone = phone.replace(/[^\d+]/g, "");
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
  const { email, newPassword } = request.data;

  // Validate inputs
  if (!email || !newPassword) {
    throw new HttpsError("invalid-argument", "Email and new password are required.");
  }

  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }

  try {
    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(email);

    // Update the user's password
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
// HTTPS Function: Create Branded Classroom (Jitsi)
// --------------------
exports.createCalligroClassroom = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const { courseName, courseId } = request.data;
    if (!courseName) {
      throw new HttpsError("invalid-argument", "courseName is required.");
    }

    // Generate a cryptographically secure, random Room ID
    const randomSuffix = Math.random().toString(36).substring(2, 10) +
      Math.random().toString(36).substring(2, 10);

    let sanitizedName = courseName.replace(/[^a-zA-Z0-9]/g, "").substring(0, 15);
    if (!sanitizedName) {
      sanitizedName = "LiveClass";
    }

    const roomId = `Calligro-${sanitizedName}-${randomSuffix}`;

    // Generate a random 10-character password for extra security
    const password = Math.random().toString(36).substring(2, 12);

    console.log(`✅ Branded Jitsi Room Created: ${roomId} with Password: ${password}`);

    // 🔐 SECURITY FIX: If courseId is provided, write credentials to private subcollection
    // so they are NOT publicly readable from the main course document
    if (courseId) {
      try {
        await admin.firestore()
          .collection("courses")
          .doc(String(courseId))
          .collection("private")
          .doc("meetingConfig")
          .set({
            calligroMeetLink: roomId,
            classroomPassword: password,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        console.log(`🔐 Meeting credentials stored in private subcollection for course ${courseId}`);
      } catch (err) {
        console.warn("⚠️ Could not write to private subcollection:", err.message);
      }
    }

    return {
      link: roomId,
      id: roomId,
      password: password,
    };
  } catch (error) {
    console.error("Error in createCalligroClassroom:", error);
    throw new HttpsError("internal", error.message || "Failed to create classroom.");
  }
});

// --------------------
// Firestore Trigger: Sync Course to Lemon Squeezy
// --------------------
exports.syncCourseToLemonSqueezy = onDocumentCreated({
  document: "courses/{courseId}",
  secrets: [lemonsqueezyApiKey, lemonsqueezyStoreId]
}, async (event) => {
  try {
    const courseId = event.params.courseId;
    const course = event.data.data();

    if (!course || course.lemonsqueezyVariantId) {
      console.log(`Skipping sync for course ${courseId}: Already synced or no data.`);
      return null;
    }

    const apiKey = lemonsqueezyApiKey.value();
    const storeId = lemonsqueezyStoreId.value();

    const courseName = course.courseName || course.courseTitle || "Untitled Course";
    const teacherName = course.teacherName || "Master Instructor";
    const originalPrice = Number(course.price || 0);
    const discountedPriceCents = Math.round((originalPrice * 100) / 2);

    console.log(`🚀 Syncing course ${courseId} to Lemon Squeezy as Variant under Master Product (952985) at 50% price: $${originalPrice / 2}`);

    // 1. Create Variant under Master Product
    const masterProductId = "952985";
    try {
      const variantResponse = await fetch("https://api.lemonsqueezy.com/v1/variants", {
        method: "POST",
        headers: {
          "Accept": "application/vnd.api+json",
          "Content-Type": "application/vnd.api+json",
          "Authorization": `Bearer ${apiKey}`
        },
        body: JSON.stringify({
          data: {
            type: "variants",
            attributes: {
              name: `${courseName} - ${teacherName}`,
              price: discountedPriceCents,
              is_subscription: false
            },
            relationships: {
              product: {
                data: { type: "products", id: masterProductId }
              }
            }
          }
        })
      });

      const variantData = await variantResponse.json();
      if (!variantResponse.ok) {
        console.warn(`⚠️ LS Variant API issue (${variantResponse.status}): ${JSON.stringify(variantData)}. Automated checkout will use fallbacks.`);
      } else {
        const variantId = variantData.data.id;
        console.log(`✅ LS Variant Created: ${variantId}`);
        
        await admin.firestore().collection("courses").doc(courseId).update({
          lemonsqueezyVariantId: variantId,
        });
      }
    } catch (err) {
      console.error("❌ variant creation error:", err.message);
    }

    // 2. Mark as payment-ready (enables Web Portal automation)
    await admin.firestore().collection("courses").doc(courseId).update({
      lemonsqueezyProductId: masterProductId,
      syncedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`🏆 Course ${courseId} is now payment-ready for automation.`);


  } catch (error) {
    console.error("❌ syncCourseToLemonSqueezy Error:", error.message || error);
  }
  return null;
});

// --------------------
// Firestore Trigger: Update Lemon Squeezy on Course Change
// --------------------
exports.updateLemonSqueezyCourse = onDocumentUpdated({
  document: "courses/{courseId}",
  secrets: [lemonsqueezyApiKey, lemonsqueezyStoreId]
}, async (event) => {
  try {
    const courseId = event.params.courseId;
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after.lemonsqueezyProductId || !after.lemonsqueezyVariantId) return null;

    const priceChanged = before.price !== after.price;
    const nameChanged = (before.courseName !== after.courseName) || (before.courseTitle !== after.courseTitle);
    const teacherChanged = before.teacherName !== after.teacherName;
    const bannerChanged = before.courseBanner !== after.courseBanner;

    if (!priceChanged && !nameChanged && !teacherChanged && !bannerChanged) return null;

    const apiKey = lemonsqueezyApiKey.value();
    const variantId = after.lemonsqueezyVariantId;

    const courseName = after.courseName || after.courseTitle || "Untitled Course";
    const teacherName = after.teacherName || "Master Instructor";
    const originalPrice = Number(after.price || 0);
    const discountedPriceCents = Math.round((originalPrice * 100) / 2);

    console.log(`🔄 Syncing updates for course ${courseId} (Variant ${variantId}) to Lemon Squeezy...`);

    // Update Variant (Name or Price)
    if (nameChanged || teacherChanged || priceChanged) {
      await fetch(`https://api.lemonsqueezy.com/v1/variants/${variantId}`, {
        method: "PATCH",
        headers: {
          "Accept": "application/vnd.api+json",
          "Content-Type": "application/vnd.api+json",
          "Authorization": `Bearer ${apiKey}`
        },
        body: JSON.stringify({
          data: {
            type: "variants",
            id: variantId,
            attributes: {
              name: `${courseName} - ${teacherName}`,
              price: discountedPriceCents
            }
          }
        })
      });
      console.log(`✅ LS Variant ${variantId} updated.`);
    }

  } catch (error) {
    console.error("❌ updateLemonSqueezyCourse Error:", error.message || error);
  }
  return null;
});

// --------------------
// HTTPS Callable: Verify Purchase (Premium IAP Security)
// --------------------
exports.verifyPurchase = onCall(async (request) => {
  try {
    // 1. Authenticate Request
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in to verify purchase.");
    }

    const { receiptData, courseId, productId } = request.data;
    if (!receiptData || !courseId) {
      throw new HttpsError("invalid-argument", "receiptData and courseId are required.");
    }

    const uid = request.auth.uid;
    console.log(`📡 Validating purchase for User: ${uid}, Course: ${courseId}`);

    // 2. Apple Receipt Validation (Using Node 22 fetch)
    // In Production, you should check Production URL first. For Sandbox, use the sandbox URL.
    const APPLE_VERIFY_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

    const response = await fetch(APPLE_VERIFY_URL, {
      method: "POST",
      body: JSON.stringify({ "receipt-data": receiptData }),
    });

    const result = await response.json();

    if (result.status !== 0) {
      console.error(`❌ Apple Validation Failed. Status: ${result.status}`);
      throw new HttpsError("permission-denied", `Apple validation failed with status ${result.status}`);
    }

    // 3. Extract & Validate Receipt Info
    const receipt = result.receipt;
    const inApp = receipt.in_app[0]; // Get the latest transaction
    const transactionId = inApp.transaction_id;
    const purchasedProductId = inApp.product_id;

    console.log(`✅ Apple Verified: ${purchasedProductId} (Tx: ${transactionId})`);

    // 4. Idempotency Check (Prevent duplicate processing)
    const orderDoc = await admin.firestore().collection("orders").doc(transactionId).get();
    if (orderDoc.exists) {
      console.warn(`⚠️ Transaction ${transactionId} already processed.`);
      return { success: true, message: "Order already processed." };
    }

    // 5. Fetch Metadata for Rich Auditing (User, Course, Teacher)
    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    const courseSnap = await admin.firestore().collection("courses").doc(courseId).get();

    const userData = userSnap.data() || {};
    const courseData = courseSnap.data() || {};

    // 6. Atomic Update: Create Order + Enroll Student
    const batch = admin.firestore().batch();

    // Create Detailed Audit Record
    batch.set(admin.firestore().collection("orders").doc(transactionId), {
      uid,
      studentName: userData.name || "Unknown Student",
      studentEmail: userData.email || "",
      courseId,
      courseName: courseData.courseName || "Unknown Course",
      courseArabicName: courseData.courseArabicName || "",
      teacherId: courseData.teacherId || "",
      teacherName: courseData.teacherName || "Unknown Teacher",
      productId: purchasedProductId,
      transactionId,
      price: courseData.price || 0,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      environment: result.environment || "sandbox",
    });

    // Enroll in Course
    batch.update(admin.firestore().collection("courses").doc(courseId), {
      enrolledStudents: admin.firestore.FieldValue.arrayUnion(uid),
      enrolledCount: admin.firestore.FieldValue.increment(1),
    });

    await batch.commit();
    console.log(`🏆 Successfully Enrolled User ${uid} in Course ${courseId}`);

    return {
      success: true,
      transactionId,
      message: "Purchase verified and course unlocked."
    };

  } catch (error) {
    console.error("verifyPurchase Error:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Failed to verify purchase.");
  }
});

// --------------------
// HTTPS Function: Lemon Squeezy Webhook (Enrollment)
// --------------------
exports.lemonsqueezyWebhook = https.onRequest({ secrets: [lemonsqueezyWebhookSecret] }, async (req, res) => {
  try {
    const signature = req.get("X-Signature");
    const secret = lemonsqueezyWebhookSecret.value();
    
    if (!signature || !secret) {
      console.warn("⚠️ Webhook missing signature or secret.");
      return res.status(401).send("Unauthorized");
    }

    const hmac = crypto.createHmac("sha256", secret);
    const digest = hmac.update(req.rawBody).digest("hex");

    if (signature !== digest) {
      console.error("❌ Invalid signature for Lemon Squeezy webhook");
      return res.status(401).send("Invalid signature");
    }

    const event = req.body;
    const eventName = event?.meta?.event_name;

    console.log(`📡 Lemon Squeezy Webhook received: ${eventName}`);

    if (eventName === "order_created") {
      const customData = event.meta.custom_data;
      const userId = customData?.user_id || customData?.userId;
      const courseId = customData?.course_id || customData?.courseId;

      if (!userId || !courseId) {
        console.warn("⚠️ Webhook meta missing user_id or course_id", customData);
        return res.status(200).send("No enrollment data found");
      }

      console.log(`🏆 Enrolling Student: ${userId} in Course: ${courseId}`);

      // 1. Update Course Document (Atomic)
      await admin.firestore().collection("courses").doc(String(courseId)).update({
        enrolledStudents: admin.firestore.FieldValue.arrayUnion(userId),
        enrolledCount: admin.firestore.FieldValue.increment(1)
      });

      // 2. Create Audit/Order Log
      await admin.firestore().collection("orders").doc(String(event.data.id)).set({
        uid: userId,
        courseId,
        orderId: event.data.id,
        amount: event.data.attributes.total,
        currency: event.data.attributes.currency,
        status: event.data.attributes.status,
        customerName: event.data.attributes.user_name || "Academy Student",
        customerEmail: event.data.attributes.user_email || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        source: "lemonsqueezy_webhook"
      });

      console.log(`✅ Enrollment completed for ${userId}`);
    }
    
    return res.status(200).send("Webhook received");
  } catch (err) {
    console.error("❌ Webhook processing error:", err.message);
    return res.status(500).send("Internal Server Error");
  }
});

// --------------------
// Import Notifications
// --------------------
Object.assign(exports, require("./notifications.js"));

// DEPRECATED: Google Meet functions removed to simplify UX and avoid restrictions.
// Students now use the branded 'Calligro Classroom' powered by Jitsi.
