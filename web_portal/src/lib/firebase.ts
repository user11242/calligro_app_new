import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  // We force fixed values here because of persistent hidden character issues in the environment variables
  apiKey: (process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "AIzaSyCgj1z12glctRJ-LjD8ebyZLDfFf_EDhwM").trim(),
  authDomain: (process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "calligro-bcfb2.firebaseapp.com").trim(),
  projectId: "calligro-bcfb2",
  storageBucket: (process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || "calligro-bcfb2.firebasestorage.app").trim(),
  messagingSenderId: (process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "500166558232").trim(),
  appId: (process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "1:500166558232:web:88e9a2f3556a3a3361396d").trim(),
  measurementId: (process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID || "G-0507DP0E4Q").trim(),
};

const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);

export { app, auth, db, storage };
