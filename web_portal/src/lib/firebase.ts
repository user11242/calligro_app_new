import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyCgj1z12glctRJ-LjD8ebyZLDfFf_EDhwM",
  authDomain: "calligro-bcfb2.firebaseapp.com",
  projectId: "calligro-bcfb2",
  storageBucket: "calligro-bcfb2.firebasestorage.app",
  messagingSenderId: "500166558232",
  appId: "1:500166558232:web:88e9a2f3556a3a3361396d",
  measurementId: "G-0507DP0E4Q"
};

const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);

export { app, auth, db, storage };
