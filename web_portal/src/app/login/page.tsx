"use client";
import { useState, useEffect } from "react";
import { auth, db } from "@/lib/firebase";
import { signInWithEmailAndPassword, signInWithRedirect, getRedirectResult, GoogleAuthProvider } from "firebase/auth";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { motion } from "framer-motion";
import { LogIn, Mail, Lock, AlertCircle } from "lucide-react";
import Navbar from "@/components/Navbar";
import AutoTranslatedText from "@/components/AutoTranslatedText";
import { doc, getDoc } from "firebase/firestore";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  // Handle the result of Google redirect sign-in on page load
  useEffect(() => {
    const handleRedirectResult = async () => {
      try {
        const result = await getRedirectResult(auth);
        if (!result) return;
        const user = result.user;

        const userDoc = await getDoc(doc(db, "users", user.uid));
        if (!userDoc.exists()) {
          await auth.signOut();
          setError("Access denied. No student record found. Please register via the Calligro mobile app first.");
          return;
        }

        const userData = userDoc.data();
        const role = userData?.role || "student";

        if (role === "teacher") {
          await auth.signOut();
          setError("Access denied. Teachers must use the Calligro Mobile App.");
          return;
        }

        if (role === "admin") {
          router.push("/admin/dashboard");
        } else {
          router.push("/courses");
        }
      } catch (err: any) {
        if (err.code !== "auth/no-current-user") {
          setError(err.message || "Google Sign-In failed.");
        }
      }
    };

    handleRedirectResult();
  }, [router]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const userDoc = await getDoc(doc(db, "users", userCredential.user.uid));
      if (!userDoc.exists()) {
        await auth.signOut();
        setError("Access denied. The web portal is for registered Academy students only. Please register via our mobile app first.");
        setLoading(false);
        return;
      }

      const userData = userDoc.data();
      const role = userData?.role || "student";

      if (role === "teacher") {
        await auth.signOut();
        setError("Access denied. Teachers must use the Calligro Mobile App for management. The web portal is for students and admins only.");
        setLoading(false);
        return;
      }

      if (role === "admin") {
        router.push("/admin/dashboard");
      } else {
        router.push("/courses");
      }
    } catch (err: any) {
      setError(err.message || "Failed to login. Please check your credentials.");
      setLoading(false);
    }
  };

  const handleGoogleLogin = async () => {
    setLoading(true);
    setError("");
    try {
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: "select_account" });
      await signInWithRedirect(auth, provider);
      // Page will redirect to Google and come back — result handled in useEffect above
    } catch (err: any) {
      console.error("Google Auth Error:", err);
      setError(err.message || "Google Sign-In failed.");
      setLoading(false);
    }
  };

  return (
    <main className="academy-bg min-h-screen flex flex-col items-center justify-center p-6 relative overflow-hidden">
      <Navbar />

      <motion.div
        initial={{ opacity: 0, scale: 0.98 }}
        animate={{ opacity: 1, scale: 1 }}
        className="w-full max-w-md glass-premium rounded-[32px] p-12 mt-12 z-10 border-white/5 relative shadow-2xl"
      >
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full glass border-white/5 mb-6">
            <LogIn className="w-3 h-3 text-primary" />
            <span className="text-[8px] font-black uppercase tracking-[3px] text-primary">Academy Portal</span>
          </div>
          <h1 className="text-3xl font-black mb-3 font-outfit uppercase tracking-tighter gold-glow">
            <AutoTranslatedText text="Academy Portal" />
          </h1>
          <p className="text-white/40 text-[10px] font-bold uppercase tracking-widest">
            <AutoTranslatedText text="Authenticate to access your dashboard" />
          </p>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500/20 rounded-xl p-4 mb-6 flex items-center gap-3 text-red-500 text-sm">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <p><AutoTranslatedText text={error} /></p>
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-6">
          <div className="space-y-2">
            <label className="text-xs font-bold uppercase tracking-widest text-white/40 ml-1">
              <AutoTranslatedText text="Email Address" />
            </label>
            <div className="relative group">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-white/20 group-focus-within:text-primary transition-colors" />
              <input
                type="email"
                required
                className="input-glass pl-12"
                placeholder="master@calligro.digital"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-xs font-bold uppercase tracking-widest text-white/40 ml-1">
              <AutoTranslatedText text="Password" />
            </label>
            <div className="relative group">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-white/20 group-focus-within:text-primary transition-colors" />
              <input
                type="password"
                required
                className="input-glass pl-12"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="btn-gold w-full mt-4 flex items-center justify-center gap-3 disabled:opacity-50"
          >
            {loading ? <AutoTranslatedText text="Authenticating..." /> : (
              <>
                <LogIn className="w-5 h-5" />
                <AutoTranslatedText text="Sign In" />
              </>
            )}
          </button>
        </form>

        <div className="relative my-8 text-center">
          <div className="absolute inset-0 flex items-center"><div className="w-full border-t border-white/5" /></div>
          <span className="relative bg-secondary px-4 text-xs font-bold uppercase tracking-widest text-white/20">
            <AutoTranslatedText text="OR" />
          </span>
        </div>

        <button
          onClick={handleGoogleLogin}
          disabled={loading}
          className="w-full flex items-center justify-center gap-4 py-3 px-6 rounded-xl border border-white/10 hover:bg-white/5 transition-all group disabled:opacity-50"
        >
          <svg className="w-5 h-5 group-hover:scale-110 transition-transform" viewBox="0 0 24 24">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
          </svg>
          <span className="text-sm font-bold tracking-wide">
            <AutoTranslatedText text="Continue with Google" />
          </span>
        </button>

        <div className="mt-12 text-center text-[10px] font-black uppercase tracking-[2px] text-white/20">
          <AutoTranslatedText text="Register via Calligro Mobile App" />
        </div>
      </motion.div>
    </main>
  );
}
