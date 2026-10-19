import * as admin from "firebase-admin";

if (!admin.apps.length) {
  let privateKey = process.env.FIREBASE_PRIVATE_KEY || "";
  // Strip outer quotes if any, and handle escaped newlines
  if (privateKey.startsWith('"') && privateKey.endsWith('"')) {
    try {
      privateKey = JSON.parse(privateKey);
    } catch {
      privateKey = privateKey.slice(1, -1);
    }
  }
  privateKey = privateKey.replace(/\\n/g, "\n");

  const clientEmail =
    process.env.FIREBASE_CLIENT_EMAIL ||
    "firebase-adminsdk-fbsvc@calligro-bcfb2.iam.gserviceaccount.com";
  const projectId =
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "calligro-bcfb2";

  if (privateKey && clientEmail) {
    try {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
    } catch (e) {
      console.error("Firebase admin init failed:", e);
    }
  }
}

export const adminDb = admin.firestore();
export const adminAuth = admin.auth();
export { admin };
