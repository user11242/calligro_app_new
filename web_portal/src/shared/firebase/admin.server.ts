import * as admin from "firebase-admin";

if (!admin.apps.length) {
  let privateKey = process.env.FIREBASE_PRIVATE_KEY || "";
  privateKey = privateKey.trim();

  // Strip outer quotes if any, and handle escaped newlines
  if (privateKey.startsWith('"') && privateKey.endsWith('"')) {
    try {
      privateKey = JSON.parse(privateKey);
    } catch {
      privateKey = privateKey.slice(1, -1);
    }
  }
  privateKey = privateKey.replace(/\\n/g, "\n").trim();

  const clientEmail = (
    process.env.FIREBASE_CLIENT_EMAIL ||
    "firebase-adminsdk-fbsvc@calligro-bcfb2.iam.gserviceaccount.com"
  )
    .trim()
    .replace(/[\r\n\t\s]/g, "");

  const projectId = (
    process.env.FIREBASE_PROJECT_ID ||
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ||
    "calligro-bcfb2"
  )
    .trim()
    .replace(/[\r\n\t\s]/g, "");

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
