"use client";
import { useState } from "react";
import { auth, db } from "@/lib/firebase";
import { signInWithEmailAndPassword, signInWithPopup, GoogleAuthProvider } from "firebase/auth";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { AlertCircle, Loader2, Check, Smartphone } from "lucide-react";
import { doc, getDoc } from "firebase/firestore";
import Image from "next/image";
import Navbar from "@/components/Navbar";
import { useTranslation } from "@/hooks/useTranslation";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const { t } = useTranslation();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const userDoc = await getDoc(doc(db, "users", userCredential.user.uid));
      if (!userDoc.exists()) {
        await auth.signOut();
        setError(t("login.error_student_only"));
        setLoading(false);
        return;
      }
      const userData = userDoc.data();
      const role = userData?.role || "student";
      if (role === "teacher") {
        await auth.signOut();
        setError(t("login.error_teacher_mobile_only"));
        setLoading(false);
        return;
      }
      if (role === "admin") { router.push("/admin/dashboard"); } else { router.push("/courses"); }
    } catch (err: any) {
      setError(err.message || t("login.error_invalid_credentials"));
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
        setError(t("login.error_no_record"));
        setLoading(false);
        return;
      }
      const userData = userDoc.data();
      const role = userData?.role || "student";
      if (role === "teacher") {
        await auth.signOut();
        setError(t("login.error_teacher_mobile_only"));
        setLoading(false);
        return;
      }
      if (role === "admin") { router.push("/admin/dashboard"); } else { router.push("/courses"); }
    } catch (err: any) {
      setError(err.message || t("login.error_google_failed"));
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0A0A0C] font-outfit selection:bg-primary/30 selection:text-primary flex flex-col">
      <Navbar />
      
      <div className="flex-1 flex flex-col md:flex-row mt-[72px] md:mt-[80px]">
        
        {/* ─── Left Side: The Clean Form ─── */}
        <motion.div 
          initial={{ opacity: 0, x: -30 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="w-full md:w-1/2 flex items-center justify-center p-8 md:p-12 lg:p-24 relative z-10 overflow-hidden"
        >
          {/* 🌊 Modern Animated Background (Bubbles/Blobs) */}
          <div className="absolute inset-0 z-0 pointer-events-none opacity-40">
             <motion.div 
               animate={{ 
                 x: [0, 50, 0], 
                 y: [0, 30, 0],
                 scale: [1, 1.1, 1]
               }} 
               transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
               className="absolute top-[-10%] left-[-10%] w-[400px] h-[400px] bg-primary/10 rounded-full blur-[100px]" 
             />
             <motion.div 
               animate={{ 
                 x: [0, -40, 0], 
                 y: [0, 60, 0],
                 scale: [1, 1.2, 1]
               }} 
               transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
               className="absolute bottom-[-20%] right-[-10%] w-[500px] h-[500px] bg-blue-500/10 rounded-full blur-[120px]" 
             />
             <motion.div 
               animate={{ 
                 scale: [1, 1.1, 1],
                 opacity: [0.3, 0.5, 0.3]
               }} 
               transition={{ duration: 8, repeat: Infinity }}
               className="absolute top-[30%] left-[40%] w-[300px] h-[300px] bg-purple-500/5 rounded-full blur-[80px]" 
             />
          </div>
          
          <div className="w-full max-w-md flex flex-col justify-center relative z-10">
            <h1 className="text-4xl lg:text-6xl font-black text-white mb-4 tracking-tighter leading-none">
              {t("login.welcome_title")}
            </h1>
            <p className="text-white/40 text-base font-medium mb-12 max-w-[340px] leading-relaxed">
              {t("login.welcome_subtitle")}
            </p>

            <AnimatePresence>
              {error && (
                <motion.div
                  initial={{ opacity: 0, height: 0, marginBottom: 0 }}
                  animate={{ opacity: 1, height: 'auto', marginBottom: 24 }}
                  exit={{ opacity: 0, height: 0, marginBottom: 0 }}
                  className="overflow-hidden"
                >
                  <div className="flex items-start gap-3 bg-red-500/10 border border-red-500/20 rounded-2xl p-4 text-red-400 text-xs font-semibold">
                    <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                    <p>{error}</p>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            <form onSubmit={handleLogin} className="space-y-6">
              <div className="space-y-4">
                 <div className="relative group">
                    <input 
                      type="email" 
                      required
                      className="w-full bg-white/[0.03] border border-white/10 rounded-[20px] py-5 px-7 text-white text-sm focus:border-primary focus:bg-white/[0.05] outline-none transition-all placeholder:text-white/20 font-medium"
                      placeholder={t("login.email_placeholder")}
                      value={email}
                      onChange={e => setEmail(e.target.value)}
                    />
                 </div>

                 <div className="relative group">
                    <input 
                      type="password" 
                      required
                      className="w-full bg-white/[0.03] border border-white/10 rounded-[20px] py-5 px-7 text-white text-sm focus:border-primary focus:bg-white/[0.05] outline-none transition-all placeholder:text-white/20 font-medium tracking-widest"
                      placeholder={t("login.password_placeholder")}
                      value={password}
                      onChange={e => setPassword(e.target.value)}
                    />
                 </div>
              </div>

              <div className="flex items-center gap-3">
                 <label className="flex items-center gap-3 cursor-pointer group">
                   <div className="w-5 h-5 rounded-lg border border-white/20 flex items-center justify-center bg-white/[0.02] group-hover:border-primary transition-all">
                     <Check className="w-3.5 h-3.5 text-primary opacity-0 group-hover:opacity-50" />
                   </div>
                   <span className="text-white/40 text-xs font-medium group-hover:text-white/60 transition-colors">
                     {t("login.remember_me")}
                   </span>
                 </label>
              </div>

              <button 
                type="submit"
                disabled={loading}
                className="w-full h-[60px] bg-primary text-black font-black text-base rounded-[20px] transition-all duration-300 flex items-center justify-center gap-2 hover:bg-[#F2CE57] active:scale-[0.98] disabled:opacity-50 shadow-[0_15px_30px_-10px_rgba(212,175,55,0.5)]"
              >
                {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : t("login.sign_in_btn")}
              </button>
            </form>

            <div className="relative my-12">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-white/5"></div>
              </div>
              <div className="relative flex justify-center text-[10px] uppercase tracking-[0.3em] font-black text-white/20">
                <span className="bg-[#0A0A0C] px-4">{t("login.secure_gateway")}</span>
              </div>
            </div>

            {/* 🌟 Prominent Google Button */}
            <button 
               onClick={handleGoogleLogin}
               className="w-full h-[60px] flex items-center justify-center gap-4 bg-white text-black rounded-[20px] text-base font-black hover:bg-white/90 transition-all active:scale-[0.98] shadow-xl"
            >
               <svg className="w-6 h-6" viewBox="0 0 24 24">
                 <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                 <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                 <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                 <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
               </svg>
               {t("login.sign_in_google")}
            </button>

            {/* Mobile Registration Note */}
            <motion.div 
               initial={{ opacity: 0, y: 10 }}
               animate={{ opacity: 1, y: 0 }}
               transition={{ delay: 0.5 }}
               className="mt-16 p-6 rounded-[24px] bg-white/[0.02] border border-white/5 flex items-center gap-4 group"
            >
               <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center text-primary shrink-0 group-hover:scale-110 transition-transform">
                  <Smartphone className="w-6 h-6" />
               </div>
               <p className="text-[11px] font-bold text-white/30 leading-relaxed uppercase tracking-wider">
                  {t("login.registration_note")}
               </p>
            </motion.div>
          </div>
        </motion.div>

        {/* ─── Right Side: The Custom Illustration ─── */}
        <motion.div 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1.2, delay: 0.3 }}
          className="hidden md:block md:w-1/2 relative self-stretch"
        >
           <Image 
             src="/assets/images/modern_calligro_login.png"
             alt="Academy Illustration"
             fill
             className="object-cover"
             priority
           />
           <div className="absolute inset-y-0 left-0 w-32 bg-gradient-to-r from-[#0A0A0C] to-transparent pointer-events-none" />
        </motion.div>
      </div>
    </div>
  );
}
