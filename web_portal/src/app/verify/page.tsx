"use client";

import { useState } from "react";
import Navbar from "@/components/Navbar";
import { Search, CheckCircle2, ShieldCheck, XCircle, Loader2, ArrowRight } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
import Link from "next/link";
import { useTranslation } from "@/hooks/useTranslation";

export default function VerifySearchPage() {
  const [certId, setCertId] = useState("");
  const [isFocused, setIsFocused] = useState(false);
  
  const [loading, setLoading] = useState(false);
  const [certificate, setCertificate] = useState<any>(null);
  const [error, setError] = useState("");
  const { t } = useTranslation();

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!certId.trim()) return;
    
    setLoading(true);
    setError("");
    setCertificate(null);

    try {
      const docRef = doc(db, "certificates", certId.trim());
      const docSnap = await getDoc(docRef);

      if (docSnap.exists()) {
        setCertificate({ id: docSnap.id, ...docSnap.data() });
      } else {
        setError(t("verify.invalid_desc") || "Invalid Certificate ID. No record found.");
      }
    } catch (err) {
      console.error(err);
      setError(t("verify.error_desc") || "An error occurred while verifying. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setCertificate(null);
    setError("");
    setCertId("");
  };

  return (
    <div className="min-h-screen bg-[#1F1F1F] flex flex-col relative text-[#FDFBF7] overflow-hidden">
      
      <div className="relative z-50">
        <Navbar />
      </div>
      
      <main className="flex-grow flex items-center justify-center p-6 relative z-10 w-full h-full">
        
        <motion.div 
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="max-w-2xl w-full relative z-20"
        >
          {/* Main Card */}
          <div className="bg-gradient-to-b from-[#1c1c1c]/80 to-[#0f0f0f]/90 backdrop-blur-2xl border border-white/10 rounded-[2.5rem] shadow-[0_20px_80px_-20px_rgba(232,196,104,0.15)] overflow-hidden p-10 md:p-16 relative">
            
            {/* Inner top glow line */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-[1px] bg-gradient-to-r from-transparent via-[#E8C468]/50 to-transparent" />

            <div className="flex flex-col items-center text-center space-y-8">
              
              <AnimatePresence mode="wait">
                
                {/* STATE: INITIAL SEARCH */}
                {!certificate && !error && (
                  <motion.div 
                    key="search"
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.95, filter: "blur(10px)" }}
                    className="w-full flex flex-col items-center space-y-8"
                  >
                    {/* Icon Container */}
                    <div className="relative group">
                      <div className="absolute inset-0 bg-[#E8C468] blur-xl opacity-20 rounded-full group-hover:opacity-40 transition-opacity duration-700" />
                      <div className="w-20 h-20 rounded-full bg-gradient-to-tr from-[#111] to-[#222] border border-[#E8C468]/30 flex items-center justify-center relative shadow-inner">
                        <ShieldCheck className="w-10 h-10 text-[#E8C468]" strokeWidth={1.5} />
                      </div>
                    </div>
                    
                    <div className="space-y-4">
                      <h1 className="text-4xl md:text-5xl font-black font-outfit uppercase tracking-tight text-transparent bg-clip-text bg-gradient-to-b from-white to-white/60">
                        {t("verify.title") || "Verify Record"}
                      </h1>
                      <p className="text-white/40 text-sm md:text-base leading-relaxed max-w-md mx-auto font-light">
                        {t("verify.subtitle") || "Enter the unique cryptographic ID found on the certificate to verify its authenticity and completion details."}
                      </p>
                    </div>

                    <form onSubmit={handleVerify} className="w-full space-y-6 pt-4">
                      
                      {/* Custom Input */}
                      <div className="relative group w-full">
                        <div className={`absolute -inset-0.5 bg-gradient-to-r from-[#E8C468]/0 via-[#E8C468]/40 to-[#E8C468]/0 rounded-2xl blur opacity-0 transition-opacity duration-500 ${isFocused ? 'opacity-100' : 'group-hover:opacity-50'}`} />
                        
                        <div className="relative flex items-center bg-[#0a0a0a] border border-white/5 rounded-2xl px-2 py-2 shadow-inner transition-colors duration-300">
                          <div className="pl-5 pr-3 text-white/20">
                            <Search className="w-5 h-5" />
                          </div>
                          <input 
                            type="text" 
                            placeholder={t("verify.placeholder") || "Enter Certificate ID (e.g. xT6YRt8w2...)"}
                            onFocus={() => setIsFocused(true)}
                            onBlur={() => setIsFocused(false)}
                            className="w-full bg-transparent border-none py-4 text-white text-lg font-mono tracking-widest placeholder:text-white/20 placeholder:font-sans placeholder:tracking-normal outline-none"
                            value={certId}
                            onChange={(e) => setCertId(e.target.value)}
                            autoComplete="off"
                            spellCheck="false"
                            disabled={loading}
                          />
                          
                          {/* Status Icon */}
                          <div className={`pr-5 pl-2 transition-all duration-300 ${certId.length > 10 ? 'opacity-100 scale-100' : 'opacity-0 scale-75'}`}>
                            <CheckCircle2 className="w-5 h-5 text-[#E8C468]" />
                          </div>
                        </div>
                      </div>

                      <motion.button 
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        type="submit"
                        disabled={!certId.trim() || loading}
                        className="w-full relative overflow-hidden rounded-2xl group disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100 mt-4"
                      >
                        <div className="absolute inset-0 bg-gradient-to-r from-[#E8C468] via-[#F4D789] to-[#E8C468] bg-[length:200%_auto] group-hover:animate-gradient-x" />
                        <div className="relative px-8 py-5 flex items-center justify-center font-bold text-black text-lg tracking-wide uppercase">
                          {loading ? (
                            <Loader2 className="w-6 h-6 animate-spin text-black" />
                          ) : (
                            t("verify.button.authenticate") || "Authenticate"
                          )}
                        </div>
                      </motion.button>
                    </form>
                  </motion.div>
                )}

                {/* STATE: SUCCESS / FOUND */}
                {certificate && !loading && (
                  <motion.div
                    key="success"
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="w-full flex flex-col items-center space-y-6"
                  >
                    <div className="w-24 h-24 rounded-full bg-green-500/10 border border-green-500/20 flex items-center justify-center mb-2">
                      <CheckCircle2 className="w-12 h-12 text-green-400" strokeWidth={1.5} />
                    </div>
                    
                    <h2 className="text-3xl font-bold text-white uppercase tracking-wider font-outfit">
                      {t("verify.authentic_title") || "Authentic Record"}
                    </h2>
                    
                    <div className="w-full bg-white/5 border border-white/10 rounded-2xl p-6 text-left space-y-4">
                      <div>
                        <p className="text-white/40 text-xs uppercase tracking-widest mb-1">{t("verify.student_name") || "Student Name"}</p>
                        <p className="text-xl text-white font-medium">{certificate.studentName}</p>
                      </div>
                      <div className="h-[1px] w-full bg-white/5" />
                      <div>
                        <p className="text-white/40 text-xs uppercase tracking-widest mb-1">{t("verify.course_title") || "Course Title"}</p>
                        <p className="text-lg text-white font-medium">{certificate.courseName}</p>
                      </div>
                      <div className="h-[1px] w-full bg-white/5" />
                      <div className="flex justify-between items-center">
                        <div>
                          <p className="text-white/40 text-xs uppercase tracking-widest mb-1">{t("verify.issue_date") || "Issue Date"}</p>
                          <p className="text-white font-mono">{new Date(certificate.issueDate?.seconds * 1000).toLocaleDateString()}</p>
                        </div>
                        <div className="text-right">
                          <p className="text-white/40 text-xs uppercase tracking-widest mb-1">{t("verify.record_id") || "Record ID"}</p>
                          <p className="text-[#E8C468] font-mono text-sm">{certificate.id}</p>
                        </div>
                      </div>
                    </div>

                    <div className="flex gap-4 w-full pt-4">
                      <button 
                        onClick={handleReset}
                        className="flex-1 py-4 px-6 rounded-xl border border-white/10 text-white/70 hover:bg-white/5 hover:text-white transition-all font-bold uppercase tracking-wider text-sm"
                      >
                        {t("verify.btn.check_another") || "Check Another"}
                      </button>
                      <Link 
                        href={`/courses/${certificate.courseId}/certificate`}
                        className="flex-1 py-4 px-6 rounded-xl bg-white/10 border border-white/20 text-white hover:bg-white/20 transition-all flex items-center justify-center gap-2 font-bold uppercase tracking-wider text-sm"
                      >
                        {t("verify.btn.view_certificate") || "View Certificate"} <ArrowRight className="w-4 h-4" />
                      </Link>
                    </div>
                  </motion.div>
                )}

                {/* STATE: ERROR / INVALID */}
                {error && !loading && (
                  <motion.div
                    key="error"
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="w-full flex flex-col items-center space-y-6 py-4"
                  >
                    <div className="w-24 h-24 rounded-full bg-red-500/10 border border-red-500/20 flex items-center justify-center mb-2">
                      <XCircle className="w-12 h-12 text-red-500" strokeWidth={1.5} />
                    </div>
                    
                    <h2 className="text-3xl font-bold text-white uppercase tracking-wider font-outfit">
                      {t("verify.invalid_title") || "Invalid Record"}
                    </h2>
                    
                    <p className="text-white/60">
                      {error}
                    </p>

                    <button 
                      onClick={handleReset}
                      className="mt-6 py-4 px-12 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all font-bold uppercase tracking-wider text-sm"
                    >
                      {t("verify.btn.try_again") || "Try Again"}
                    </button>
                  </motion.div>
                )}

              </AnimatePresence>
            </div>
          </div>
        </motion.div>
      </main>
    </div>
  );
}
