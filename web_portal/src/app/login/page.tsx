"use client";
import { useState } from "react";
import { auth, db } from "@/lib/firebase";
import { signInWithEmailAndPassword, signInWithPopup, GoogleAuthProvider } from "firebase/auth";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Mail, Lock, AlertCircle, Loader2, ArrowRight, Pen, BookOpen, Users } from "lucide-react";
import { doc, getDoc } from "firebase/firestore";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();



  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const userDoc = await getDoc(doc(db, "users", userCredential.user.uid));
      if (!userDoc.exists()) {
        await auth.signOut();
        setError("Access denied. The web portal is for registered Academy students only.");
        setLoading(false);
        return;
      }
      const userData = userDoc.data();
      const role = userData?.role || "student";
      if (role === "teacher") {
        await auth.signOut();
        setError("Access denied. Teachers must use the Calligro Mobile App.");
        setLoading(false);
        return;
      }
      if (role === "admin") { router.push("/admin/dashboard"); } else { router.push("/courses"); }
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
      const result = await signInWithPopup(auth, provider);
      const user = result.user;
      const userDoc = await getDoc(doc(db, "users", user.uid));
      if (!userDoc.exists()) {
        await auth.signOut();
        setError("Access denied. No student record found. Please register via the Calligro mobile app first.");
        setLoading(false);
        return;
      }
      const userData = userDoc.data();
      const role = userData?.role || "student";
      if (role === "teacher") {
        await auth.signOut();
        setError("Access denied. Teachers must use the Calligro Mobile App.");
        setLoading(false);
        return;
      }
      if (role === "admin") { router.push("/admin/dashboard"); } else { router.push("/courses"); }
    } catch (err: any) {
      setError(err.message || "Google Sign-In failed.");
      setLoading(false);
    }
  };

  const stats = [
    { icon: BookOpen, label: "Courses", value: "12+" },
    { icon: Users, label: "Students", value: "500+" },
    { icon: Pen, label: "Masters", value: "8" },
  ];

  return (
    <div className="min-h-screen flex bg-[#080808] overflow-hidden">
      {/* ─── LEFT PANEL — Brand Story ─── */}
      <div className="hidden lg:flex flex-col w-[52%] relative overflow-hidden">
        {/* Background Layers */}
        <div className="absolute inset-0 bg-gradient-to-br from-[#0a0a0a] via-[#111] to-[#0a0a0a]" />
        <div className="absolute top-0 left-0 w-full h-full">
          <div className="absolute top-[-10%] left-[-10%] w-[70%] h-[70%] rounded-full bg-primary/5 blur-[120px]" />
          <div className="absolute bottom-[-10%] right-[-5%] w-[50%] h-[60%] rounded-full bg-primary/8 blur-[100px]" />
        </div>

        {/* Grid Pattern */}
        <div
          className="absolute inset-0 opacity-[0.03]"
          style={{
            backgroundImage: `
              linear-gradient(rgba(255,255,255,0.3) 1px, transparent 1px),
              linear-gradient(90deg, rgba(255,255,255,0.3) 1px, transparent 1px)
            `,
            backgroundSize: "60px 60px",
          }}
        />

        {/* Content */}
        <div className="relative z-10 flex flex-col h-full px-16 py-16">
          {/* Logo */}
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.6 }}
            className="flex items-center gap-3"
          >
            <div className="w-10 h-10 rounded-2xl bg-primary flex items-center justify-center shadow-[0_0_30px_rgba(212,175,55,0.4)]">
              <Pen className="w-5 h-5 text-black" />
            </div>
            <span className="text-white font-black text-xl tracking-tighter font-outfit uppercase">Calligro</span>
          </motion.div>

          {/* Hero Text */}
          <div className="flex-1 flex flex-col justify-center">
            <motion.div
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.9, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
            >
              <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full border border-primary/20 bg-primary/5 mb-10">
                <div className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse" />
                <span className="text-[11px] font-black uppercase tracking-[0.25em] text-primary/80">Academy Portal</span>
              </div>

              <h1 className="text-6xl xl:text-7xl font-black font-outfit text-white leading-[0.95] tracking-tighter mb-8">
                Master the<br />
                <span className="text-primary relative">
                  Art of Arabic
                  <svg className="absolute -bottom-2 left-0 w-full" height="4" viewBox="0 0 300 4">
                    <path d="M0 2 Q75 0 150 2 Q225 4 300 2" stroke="#D4AF37" strokeWidth="2" fill="none" strokeLinecap="round" />
                  </svg>
                </span>
                <br />Calligraphy.
              </h1>

              <p className="text-white/30 text-lg leading-relaxed max-w-md font-medium">
                Join world-class live sessions, access curated courses, and transform your calligraphic artistry with expert masters.
              </p>
            </motion.div>

            {/* Stats Row */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.5 }}
              className="flex items-center gap-8 mt-16"
            >
              {stats.map(({ icon: Icon, label, value }, i) => (
                <div key={i} className="flex flex-col gap-1">
                  <div className="flex items-center gap-2">
                    <Icon className="w-4 h-4 text-primary/60" />
                    <span className="text-2xl font-black text-white font-outfit">{value}</span>
                  </div>
                  <span className="text-[11px] font-bold uppercase tracking-widest text-white/20">{label}</span>
                </div>
              ))}
            </motion.div>
          </div>

          {/* Bottom Quote */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.8, delay: 0.7 }}
            className="border-t border-white/5 pt-8"
          >
            <p className="text-white/20 text-sm font-medium leading-relaxed">
              &quot;Calligraphy is the geometry of the soul expressed through the body.&quot;
            </p>
            <p className="text-white/10 text-xs mt-2 font-bold uppercase tracking-widest">— Ibn Muqla</p>
          </motion.div>
        </div>
      </div>

      {/* ─── RIGHT PANEL — Login Form ─── */}
      <div className="flex-1 flex flex-col items-center justify-center px-8 md:px-16 lg:px-20 relative">
        {/* Subtle right-side glow */}
        <div className="absolute top-1/2 right-0 -translate-y-1/2 w-72 h-72 bg-primary/5 rounded-full blur-[100px] pointer-events-none" />

        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="w-full max-w-sm relative z-10"
        >
          {/* Mobile Logo */}
          <div className="lg:hidden flex items-center gap-3 mb-12">
            <div className="w-9 h-9 rounded-xl bg-primary flex items-center justify-center">
              <Pen className="w-4 h-4 text-black" />
            </div>
            <span className="text-white font-black text-lg tracking-tighter font-outfit uppercase">Calligro</span>
          </div>

          {/* Header */}
          <div className="mb-10">
            <h2 className="text-3xl font-black text-white font-outfit tracking-tighter mb-2">
              Welcome back
            </h2>
            <p className="text-white/30 text-sm font-medium">
              Sign in to your Academy account
            </p>
          </div>

          {/* Error */}
          {error && (
            <motion.div
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex items-start gap-3 bg-red-500/8 border border-red-500/15 rounded-2xl p-4 mb-8 text-red-400 text-xs font-semibold"
            >
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <p className="leading-relaxed">{error}</p>
            </motion.div>
          )}

          {/* Form */}
          <form onSubmit={handleLogin} className="space-y-5">
            {/* Email */}
            <div className="group">
              <label className="block text-[11px] font-black uppercase tracking-[0.2em] text-white/20 mb-2.5 ml-1 group-focus-within:text-primary/60 transition-colors">
                Email Address
              </label>
              <div className="relative">
                <Mail className="absolute left-5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/15 group-focus-within:text-primary/50 transition-colors" />
                <input
                  type="email"
                  required
                  className="w-full bg-white/[0.04] border border-white/8 rounded-2xl pl-12 pr-5 py-4 text-white text-sm placeholder:text-white/15 outline-none focus:border-primary/40 focus:bg-white/[0.07] focus:ring-4 focus:ring-primary/8 transition-all duration-300 font-medium"
                  placeholder="your@email.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
            </div>

            {/* Password */}
            <div className="group">
              <label className="block text-[11px] font-black uppercase tracking-[0.2em] text-white/20 mb-2.5 ml-1 group-focus-within:text-primary/60 transition-colors">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/15 group-focus-within:text-primary/50 transition-colors" />
                <input
                  type="password"
                  required
                  className="w-full bg-white/[0.04] border border-white/8 rounded-2xl pl-12 pr-5 py-4 text-white text-sm placeholder:text-white/15 outline-none focus:border-primary/40 focus:bg-white/[0.07] focus:ring-4 focus:ring-primary/8 transition-all duration-300 font-medium"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
            </div>

            {/* Sign In Button */}
            <button
              type="submit"
              disabled={loading}
              className="relative w-full py-4 rounded-2xl font-black uppercase tracking-[0.15em] text-sm text-black overflow-hidden group disabled:opacity-50 transition-all mt-2"
              style={{
                background: "linear-gradient(135deg, #FFEF96 0%, #D4AF37 100%)",
                boxShadow: "0 10px 40px -10px rgba(212,175,55,0.5)",
              }}
            >
              <div className="absolute inset-0 bg-white/20 opacity-0 group-hover:opacity-100 transition-opacity" />
              <span className="relative flex items-center justify-center gap-3">
                {loading ? (
                  <Loader2 className="w-5 h-5 animate-spin" />
                ) : (
                  <>
                    Sign In
                    <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                  </>
                )}
              </span>
            </button>
          </form>

          {/* Divider */}
          <div className="relative my-8 flex items-center">
            <div className="flex-1 border-t border-white/5" />
            <span className="mx-4 text-[11px] font-black uppercase tracking-widest text-white/15">or</span>
            <div className="flex-1 border-t border-white/5" />
          </div>

          {/* Google */}
          <button
            onClick={handleGoogleLogin}
            disabled={loading}
            className="w-full flex items-center justify-center gap-3 py-4 px-6 rounded-2xl bg-white/[0.03] border border-white/8 hover:bg-white/[0.07] hover:border-white/15 transition-all duration-300 group disabled:opacity-40"
          >
            <svg className="w-4 h-4 flex-shrink-0" viewBox="0 0 24 24">
              <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
              <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
              <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
              <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
            </svg>
            <span className="text-sm font-bold text-white/50 group-hover:text-white/80 tracking-wide transition-colors">
              Continue with Google
            </span>
          </button>

          {/* Footer */}
          <p className="text-center text-[10px] font-bold uppercase tracking-[0.2em] text-white/15 mt-10">
            Register via the Calligro Mobile App
          </p>
        </motion.div>
      </div>
    </div>
  );
}
