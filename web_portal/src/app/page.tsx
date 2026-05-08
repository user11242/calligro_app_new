"use client";
import { useEffect, useState } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { db } from "@/lib/firebase";
import { collection, query, limit, getDocs, orderBy, where } from "firebase/firestore";
import Image from "next/image";
import { Star, ArrowRight, Play, Layout, Users, Sparkles } from "lucide-react";
import { formatImageUrl } from "@/lib/utils";
import { useTranslation } from "@/hooks/useTranslation";

export default function Home() {
  const [teachers, setTeachers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [mounted, setMounted] = useState(false);
  const { t, locale } = useTranslation();

  useEffect(() => {
    setMounted(true);
    const fetchMasters = async () => {
      try {
        // Fetch teachers from the 'users' collection
        const q = query(
          collection(db, "users"), 
          where("role", "==", "teacher"),
          limit(3)
        );
        const snap = await getDocs(q);
        setTeachers(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      } catch (err) {
        console.error("Home fetch error:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchMasters();
  }, []);

  if (!mounted) return <div className="min-h-screen bg-[#0a0a0a]" />;

  return (
    <main className="academy-bg min-h-screen font-sans">
      <Navbar />

      {/* ═══════ Cinematic Full-Width Hero ═══════ */}
      <section className="relative w-full overflow-hidden">
        <div className="relative w-full h-screen">
          <Image
            src={
              locale === "en" ? "/assets/images/web-hero-en.png" : 
              locale === "tr" ? "/assets/images/web-hero-tr.png" : 
              "/assets/images/web-hero.jpeg"
            }
            alt="Calligro Hero"
            fill
            className="object-cover object-top"
            priority
          />
          {/* Content Overlay - Positioned on the right side under the 50% text */}
          <div className="absolute left-6 right-6 md:left-auto md:right-32 bottom-12 md:bottom-24 flex flex-col z-20" dir="ltr">
            <motion.div 
               initial={{ opacity: 0, y: 30 }}
               animate={{ opacity: 1, y: 0 }}
               transition={{ duration: 1 }}
               className="max-w-xl flex flex-col items-center md:items-end"
            >
              <div className="flex flex-col sm:flex-row gap-3 md:gap-4 items-center w-full sm:w-auto">
                <Link href="/courses" className="w-full sm:w-auto">
                  <button className="group flex items-center justify-center gap-4 w-full sm:w-auto px-8 md:px-12 py-4 md:py-5 rounded-full text-xs md:text-sm font-black uppercase tracking-widest bg-primary text-black hover:scale-105 transition-all shadow-2xl">
                    {t("hero.cta.join")}
                    <ArrowRight className="w-5 h-5 group-hover:translate-x-2 transition-transform" />
                  </button>
                </Link>
                <Link href="/download" className="w-full sm:w-auto">
                  <button className="w-full sm:w-auto px-8 md:px-12 py-4 md:py-5 rounded-full text-xs md:text-sm font-black uppercase tracking-widest text-white border-2 border-white/20 hover:bg-white/10 backdrop-blur-md transition-all">
                    {t("hero.cta.app")}
                  </button>
                </Link>
              </div>
            </motion.div>
          </div>
        </div>
      </section>

      {/* ═══════ Advanced Modern About Section ═══════ */}
      <section className="relative py-32 px-6 overflow-hidden">
        {/* Animated Background Elements */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-full pointer-events-none z-0">
          <motion.div 
            animate={{ 
              scale: [1, 1.2, 1],
              opacity: [0.1, 0.2, 0.1],
              rotate: [0, 90, 0]
            }}
            transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
            className="absolute -top-[20%] -left-[10%] w-[600px] h-[600px] bg-primary/10 rounded-full blur-[120px]"
          />
          <motion.div 
            animate={{ 
              scale: [1.2, 1, 1.2],
              opacity: [0.1, 0.15, 0.1],
              rotate: [0, -90, 0]
            }}
            transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
            className="absolute top-[40%] -right-[10%] w-[500px] h-[500px] bg-primary/5 rounded-full blur-[100px]"
          />
        </div>

        <div className="max-w-7xl mx-auto relative z-10">
          <div className="text-center mb-24">
            <motion.span 
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="text-xs font-black text-primary uppercase tracking-[0.4em] mb-6 inline-block"
            >
              {t("home.about.title")}
            </motion.span>
            <motion.h2 
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="text-5xl md:text-7xl font-black font-outfit tracking-tighter text-white mb-8 leading-none"
            >
              {t("home.about.subtitle")}
            </motion.h2>
            <motion.p 
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 0.2 }}
              className="text-lg md:text-xl text-white/50 max-w-3xl mx-auto font-medium leading-relaxed"
            >
              {t("home.about.desc")}
            </motion.p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 mb-8">
            {/* Mission Card */}
            <motion.div 
              initial={{ opacity: 0, x: -30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              whileHover={{ y: -10 }}
              className="lg:col-span-7 glass-premium p-10 md:p-14 rounded-[48px] border border-white/10 bg-black/40 backdrop-blur-3xl flex flex-col justify-between group overflow-hidden relative"
            >
              <div className="absolute top-0 right-0 p-12 opacity-5 group-hover:opacity-10 transition-opacity">
                <Sparkles className="w-48 h-48 text-primary" />
              </div>
              <div>
                <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center border border-primary/20 mb-10 group-hover:scale-110 transition-transform">
                  <Layout className="w-8 h-8 text-primary" />
                </div>
                <h3 className="text-3xl md:text-4xl font-black font-outfit text-white mb-6 tracking-tight uppercase">
                  {t("home.about.mission")}
                </h3>
                <p className="text-white/60 text-lg leading-relaxed max-w-xl">
                  {t("home.about.mission_desc")}
                </p>
              </div>
            </motion.div>

            {/* Vision Card */}
            <motion.div 
              initial={{ opacity: 0, x: 30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              whileHover={{ y: -10 }}
              className="lg:col-span-5 glass-premium p-10 md:p-14 rounded-[48px] border border-white/10 bg-primary/[0.03] backdrop-blur-3xl flex flex-col group overflow-hidden relative"
            >
              <div className="w-16 h-16 rounded-2xl bg-primary/20 flex items-center justify-center border border-primary/30 mb-10 group-hover:rotate-12 transition-transform">
                <Users className="w-8 h-8 text-primary" />
              </div>
              <h3 className="text-3xl md:text-4xl font-black font-outfit text-white mb-6 tracking-tight uppercase">
                {t("home.about.vision")}
              </h3>
              <p className="text-white/60 text-lg leading-relaxed">
                {t("home.about.vision_desc")}
              </p>
            </motion.div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Feature 1 */}
            <motion.div 
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.1 }}
              whileHover={{ scale: 1.02 }}
              className="glass-premium p-10 rounded-[40px] border border-white/5 bg-white/[0.02] hover:border-primary/40 transition-all group"
            >
              <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mb-8 border border-white/10 group-hover:bg-primary group-hover:text-black transition-all">
                <Play className="w-5 h-5" />
              </div>
              <h4 className="text-xl font-black text-white mb-4 uppercase tracking-tight">
                {t("home.about.feature1.title")}
              </h4>
              <p className="text-white/40 text-sm leading-relaxed">
                {t("home.about.feature1.desc")}
              </p>
            </motion.div>

            {/* Feature 2 */}
            <motion.div 
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.2 }}
              whileHover={{ scale: 1.02 }}
              className="glass-premium p-10 rounded-[40px] border border-white/5 bg-white/[0.02] hover:border-primary/40 transition-all group"
            >
              <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mb-8 border border-white/10 group-hover:bg-primary group-hover:text-black transition-all">
                <Users className="w-5 h-5" />
              </div>
              <h4 className="text-xl font-black text-white mb-4 uppercase tracking-tight">
                {t("home.about.feature2.title")}
              </h4>
              <p className="text-white/40 text-sm leading-relaxed">
                {t("home.about.feature2.desc")}
              </p>
            </motion.div>

            {/* Feature 3 */}
            <motion.div 
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.3 }}
              whileHover={{ scale: 1.02 }}
              className="glass-premium p-10 rounded-[40px] border border-white/5 bg-white/[0.02] hover:border-primary/40 transition-all group"
            >
              <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center mb-8 border border-white/10 group-hover:bg-primary group-hover:text-black transition-all">
                <Sparkles className="w-5 h-5" />
              </div>
              <h4 className="text-xl font-black text-white mb-4 uppercase tracking-tight">
                {t("home.about.feature3.title")}
              </h4>
              <p className="text-white/40 text-sm leading-relaxed">
                {t("home.about.feature3.desc")}
              </p>
            </motion.div>
          </div>
        </div>
      </section>

      {/* ═══════ Modern Teachers Section ═══════ */}
      <section className="relative py-32 px-6 max-w-7xl mx-auto z-10">
        <motion.div
           initial={{ opacity: 0, y: 20 }}
           whileInView={{ opacity: 1, y: 0 }}
           viewport={{ once: true }}
           className="flex flex-col md:flex-row justify-between items-end mb-24 gap-8"
        >
          <div className="text-start">
            <p className="text-[10px] md:text-xs font-black text-primary uppercase tracking-[0.3em] mb-4">{t("home.trending")}</p>
            <h2 className="text-3xl md:text-5xl lg:text-7xl font-black font-outfit tracking-tighter text-white leading-none">
              {t("teachers.title")}
            </h2>
          </div>
          <Link href="/teachers" className="glass-premium px-10 py-5 rounded-full text-xs font-black uppercase tracking-[0.2em] text-white/80 hover:text-primary transition-all border-white/10 shadow-xl flex items-center gap-4 group">
            {t("home.enter_library")}
            <ArrowRight className="w-5 h-5 group-hover:translate-x-2 transition-transform" />
          </Link>
        </motion.div>

          <AnimatePresence mode="wait">
            {loading ? (
              <motion.div 
                key="skeletons"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="grid grid-cols-1 md:grid-cols-3 gap-12 col-span-full"
              >
                {Array(3).fill(0).map((_, i) => (
                  <div key={i} className="glass-premium rounded-[64px] aspect-[4/5] bg-white/5 border-white/5 animate-pulse" />
                ))}
              </motion.div>
            ) : (
              <motion.div 
                key="content"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="grid grid-cols-1 md:grid-cols-3 gap-12 col-span-full"
              >
                {teachers.map((teacher, i) => (
                  <motion.div
                    key={teacher.id}
                    initial={{ opacity: 0, scale: 0.9, y: 40 }}
                    whileInView={{ opacity: 1, scale: 1, y: 0 }}
                    viewport={{ once: true }}
                    transition={{ delay: i * 0.2, duration: 0.8, ease: [0.23, 1, 0.32, 1] }}
                    whileHover={{ y: -20 }}
                    className="group relative"
                  >
                    {/* Decorative Background Glow */}
                    <div className="absolute inset-0 bg-primary/5 rounded-[64px] blur-2xl group-hover:bg-primary/10 transition-colors duration-500" />
                    
                    <div className="relative glass-premium rounded-[64px] p-10 border border-white/10 bg-black/40 backdrop-blur-3xl overflow-hidden flex flex-col items-center text-center h-full shadow-2xl">
                      
                      {/* Teacher Image with Premium Frame */}
                      <div className="relative w-48 h-48 mb-10">
                        <div className="absolute inset-0 rounded-full border-2 border-primary/20 group-hover:border-primary transition-colors duration-500 animate-[spin_10s_linear_infinite] group-hover:animate-[spin_4s_linear_infinite] border-dashed" />
                        <div className="absolute inset-2 rounded-full border border-white/10" />
                        <div className="absolute inset-4 rounded-full overflow-hidden border-4 border-[#0a0a0a] shadow-2xl">
                          <Image 
                            src={formatImageUrl(teacher.photoUrl || teacher.profileImage) || "/assets/images/Logo.png"} 
                            alt={teacher.name || "Teacher"}
                            fill
                            className="object-cover grayscale group-hover:grayscale-0 transition-all duration-700 scale-110 group-hover:scale-100"
                          />
                        </div>
                        
                        {/* Certified Badge */}
                        <div className="absolute -bottom-2 right-4 bg-primary text-black p-2 rounded-full shadow-xl border-4 border-[#0a0a0a] group-hover:scale-110 transition-transform">
                          <Sparkles className="w-5 h-5" />
                        </div>
                      </div>

                      <h3 className="text-3xl font-black font-outfit text-white mb-8 tracking-tight group-hover:gold-text transition-all">
                        {teacher.name || "Anonymous Master"}
                      </h3>

                      {/* Stats Row */}
                      <div className="grid grid-cols-2 gap-8 w-full py-8 border-y border-white/5 mb-10">
                        <div className="flex flex-col items-center">
                          <span className="text-2xl font-black text-white font-outfit">{teacher.followerCount || 0}</span>
                          <span className="text-[9px] font-black text-primary/60 uppercase tracking-widest">{t("course.students")}</span>
                        </div>
                        <div className="flex flex-col items-center border-l border-white/10">
                          <div className="flex items-center gap-1">
                            <Star className="w-4 h-4 text-primary fill-primary" />
                            <span className="text-2xl font-black text-white font-outfit">{Number(teacher.rating || 5.0).toFixed(1)}</span>
                          </div>
                          <span className="text-[9px] font-black text-primary/60 uppercase tracking-widest">{t("course.rating")}</span>
                        </div>
                      </div>

                      {/* Action Button */}
                      <Link href={`/teachers/${teacher.id}`} className="w-full py-5 rounded-3xl bg-white/5 border border-white/10 text-white font-black uppercase tracking-[0.2em] text-[10px] hover:bg-primary hover:text-black hover:border-primary transition-all shadow-inner">
                        {t("course.learn_more")}
                      </Link>
                    </div>
                  </motion.div>
                ))}
              </motion.div>
            )}
          </AnimatePresence>
      </section>

      <Footer />
    </main>
  );
}
