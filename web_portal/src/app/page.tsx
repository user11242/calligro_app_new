"use client";
import { useEffect, useState } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { db } from "@/lib/firebase";
import { collection, query, limit, getDocs, orderBy } from "firebase/firestore";
import AutoTranslatedText from "@/components/AutoTranslatedText";
import Image from "next/image";
import { Star, ArrowRight, Play, Layout, Users, Sparkles } from "lucide-react";
import { formatImageUrl } from "@/lib/utils";
import { useTranslation } from "@/hooks/useTranslation";

export default function Home() {
  const [courses, setCourses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const { t } = useTranslation();

  useEffect(() => {
    const fetchPopular = async () => {
      try {
        const q = query(collection(db, "courses"), orderBy("enrolledCount", "desc"), limit(3));
        const snap = await getDocs(q);
        setCourses(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      } catch (err) {
        console.error("Home fetch error:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchPopular();
  }, []);

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: { 
      opacity: 1,
      transition: { staggerChildren: 0.15, delayChildren: 0.2 }
    }
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 30 },
    visible: { opacity: 1, y: 0, transition: { duration: 0.8 } }
  };

  return (
    <main className="academy-bg min-h-screen font-sans">
      <Navbar />

      {/* ═══════ Parchment Scroll Hero Section ═══════ */}
      <section className="relative pt-8 md:pt-16 pb-20 px-4 sm:px-6 max-w-[90rem] mx-auto z-10 w-full">
         <div className="relative w-full rounded-[32px] md:rounded-[60px] overflow-hidden shadow-[0_40px_100px_-20px_rgba(238,179,75,0.08)]" 
              style={{ background: 'linear-gradient(165deg, #f5f0e8 0%, #ece4d4 40%, #e8dcc8 100%)' }}>
             
             {/* Decorative Ink Brush Strokes SVG */}
             <div className="absolute inset-0 pointer-events-none overflow-hidden">
                 <svg width="100%" height="100%" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
                     <path d="M-50,0 Q150,120 50,350 T400,700" stroke="#d4c4a0" strokeWidth="200" strokeLinecap="round" fill="none" opacity="0.25" />
                     <path d="M800,50 Q600,300 900,600" stroke="#c8b68a" strokeWidth="150" strokeLinecap="round" fill="none" opacity="0.15" />
                     <path d="M400,-80 Q700,200 500,500" stroke="#bfa976" strokeWidth="80" strokeLinecap="round" fill="none" opacity="0.1" />
                 </svg>
                 {/* Subtle paper texture dots */}
                 <div className="absolute inset-0 opacity-[0.03]" style={{ backgroundImage: 'radial-gradient(circle, #3a2a10 1px, transparent 1px)', backgroundSize: '24px 24px' }} />
             </div>

             {/* Content Container */}
             <div className="relative z-10 flex flex-col items-center text-center px-6 sm:px-12 md:px-20 py-20 md:py-32 lg:py-40">
                 
                 {/* Top Badge */}
                 <motion.div 
                     initial={{ opacity: 0, y: 20 }}
                     animate={{ opacity: 1, y: 0 }}
                     className="inline-flex items-center gap-3 px-6 py-2.5 rounded-full border-2 border-[#8a7450]/30 bg-[#8a7450]/10 backdrop-blur-sm mb-12"
                 >
                     <Sparkles className="w-4 h-4 text-[#8a7450]" />
                     <span className="text-[10px] sm:text-xs font-black uppercase tracking-[0.3em] text-[#8a7450]">Calligro Web Portal</span>
                 </motion.div>

                 {/* Main Headline */}
                 <motion.h1 
                     initial={{ opacity: 0, y: 30 }}
                     animate={{ opacity: 1, y: 0 }}
                     transition={{ delay: 0.1, duration: 0.8 }}
                     className="text-5xl sm:text-7xl md:text-8xl lg:text-[110px] font-black font-outfit leading-[0.92] tracking-tighter text-[#1a1208] select-none mb-8"
                 >
                     {t("hero.title")} <br />
                     <span className="relative inline-block" style={{ color: '#8a6914' }}>
                         Calligraphy.
                         {/* Hand-drawn underline */}
                         <svg className="absolute w-[105%] h-4 md:h-6 -bottom-2 md:-bottom-4 left-[-2%]" viewBox="0 0 200 20" preserveAspectRatio="none">
                             <path d="M5,12 C30,4 60,18 100,8 C140,-2 170,16 195,10" stroke="#8a6914" strokeWidth="3" fill="none" strokeLinecap="round" opacity="0.6"/>
                             <path d="M10,15 C50,8 90,19 130,6 C160,0 180,14 192,11" stroke="#8a6914" strokeWidth="2" fill="none" strokeLinecap="round" opacity="0.3"/>
                         </svg>
                     </span>
                 </motion.h1>
                 
                 {/* Subtitle */}
                 <motion.p 
                     initial={{ opacity: 0 }}
                     animate={{ opacity: 1 }}
                     transition={{ delay: 0.3, duration: 0.8 }}
                     className="text-lg md:text-2xl text-[#5a4a2a]/70 leading-relaxed font-medium max-w-3xl mb-16"
                 >
                     {t("hero.subtitle")}
                 </motion.p>

                 {/* ── 50% Grant Seal ── */}
                 <motion.div 
                     initial={{ scale: 0.7, opacity: 0 }}
                     animate={{ scale: 1, opacity: 1 }}
                     transition={{ type: "spring", stiffness: 120, damping: 14, delay: 0.35 }}
                     className="relative mb-16"
                 >
                     <div className="relative w-48 h-48 sm:w-56 sm:h-56 md:w-72 md:h-72 mx-auto">
                         <svg viewBox="0 0 200 200" className="w-full h-full drop-shadow-lg" xmlns="http://www.w3.org/2000/svg">
                             {/* Outer organic ink splat */}
                             <path d="M100,8 C130,5 155,2 175,20 C195,38 198,65 195,90 C192,115 200,140 185,160 C170,180 140,190 110,193 C80,196 50,200 28,185 C6,170 -2,140 2,115 C6,90 18,70 32,50 C46,30 70,11 100,8 Z" fill="#1a1208" />
                             {/* Inner ring */}
                             <path d="M100,22 C125,19 147,14 162,28 C177,42 182,62 180,85 C178,108 184,130 172,148 C160,166 138,174 112,177 C86,180 60,184 42,172 C24,160 14,138 16,115 C18,92 28,72 40,55 C52,38 75,25 100,22 Z" stroke="#eeb34b" strokeWidth="2" strokeDasharray="6 4" fill="none" opacity="0.5"/>
                         </svg>
                         {/* Text Inside */}
                         <div className="absolute inset-0 flex flex-col items-center justify-center select-none">
                             <span className="text-6xl sm:text-7xl md:text-[100px] font-black font-outfit tracking-tighter leading-none text-[#eeb34b] drop-shadow-sm" style={{ textShadow: '0 2px 10px rgba(238,179,75,0.3)' }}>50%</span>
                             <span className="text-[10px] sm:text-xs md:text-sm font-black uppercase tracking-[0.25em] text-[#eeb34b]/80 mt-1 md:mt-2">منحة أكاديمية</span>
                         </div>
                     </div>
                 </motion.div>

                 {/* Grant Description */}
                 <motion.p 
                     initial={{ opacity: 0, y: 10 }}
                     animate={{ opacity: 1, y: 0 }}
                     transition={{ delay: 0.5 }}
                     className="text-base md:text-lg text-[#5a4a2a]/60 max-w-xl mb-12 leading-relaxed"
                 >
                     سجّل الآن واحصل تلقائيًا على منحة أكاديمية تغطي ٥٠٪ من رسوم الدورة عبر البوابة.
                 </motion.p>

                 {/* CTAs */}
                 <motion.div 
                     initial={{ opacity: 0, y: 20 }}
                     animate={{ opacity: 1, y: 0 }}
                     transition={{ delay: 0.55 }}
                     className="flex flex-col sm:flex-row gap-5 items-center"
                 >
                     <Link href="/courses">
                         <button className="group flex items-center justify-center gap-4 px-14 py-5 rounded-full text-sm font-black uppercase tracking-[0.15em] bg-[#1a1208] text-[#f5f0e8] hover:bg-[#2a1f10] transition-all shadow-xl hover:shadow-2xl">
                             {t("hero.cta.join")}
                             <ArrowRight className="w-5 h-5 group-hover:translate-x-2 transition-transform duration-300" />
                         </button>
                     </Link>
                     <Link href="/download">
                         <button className="px-14 py-5 rounded-full text-sm font-black uppercase tracking-[0.15em] text-[#5a4a2a] border-2 border-[#8a7450]/30 hover:bg-[#8a7450]/10 hover:border-[#8a7450]/50 transition-all">
                             {t("hero.cta.app")}
                         </button>
                     </Link>
                 </motion.div>
             </div>

             {/* Bottom decorative torn-edge SVG */}
             <div className="absolute bottom-0 left-0 right-0 pointer-events-none">
                 <svg viewBox="0 0 1440 60" preserveAspectRatio="none" className="w-full h-8 md:h-12" fill="var(--bg-color, #000000)">
                     <path d="M0,60 L0,30 C120,45 240,10 360,25 C480,40 600,5 720,20 C840,35 960,8 1080,22 C1200,36 1320,12 1440,28 L1440,60 Z" style={{ fill: '#0a0a0a' }}/>
                 </svg>
             </div>
         </div>
      </section>

      {/* Modern Trending Section */}
      <section className="relative py-32 px-6 max-w-7xl mx-auto z-10">
        <motion.div
           initial={{ opacity: 0, y: 20 }}
           whileInView={{ opacity: 1, y: 0 }}
           viewport={{ once: true }}
           className="flex flex-col md:flex-row justify-between items-end mb-20 gap-8"
        >
          <div className="text-start">
            <p className="text-[10px] md:text-xs font-black text-primary uppercase tracking-[0.3em] mb-4">{t("home.trending")}</p>
            <h2 className="text-4xl md:text-6xl font-black font-outfit tracking-tight">
              {t("home.popular")}
            </h2>
          </div>
          <Link href="/courses" className="glass-premium px-8 py-4 rounded-full text-xs font-black uppercase tracking-[0.15em] text-white/70 hover:text-primary transition-all border-white/10 shadow-lg flex items-center gap-2 group">
            {t("home.enter_library")}
            <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
          </Link>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-10">
          <AnimatePresence mode="wait">
            {loading ? (
               Array(3).fill(0).map((_, i) => (
                <div key={i} className="glass-premium rounded-[40px] aspect-[4/5]  bg-white/5 border-white/5" />
               ))
            ) : (
              courses.map((course, i) => (
                <motion.div
                  key={course.id}
                  initial={{ opacity: 0, y: 40 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: i * 0.15, duration: 0.8 }}
                  whileHover={{ y: -15, scale: 1.02 }}
                  className="glass-premium rounded-[48px] overflow-hidden group cursor-pointer border-t border-white/10 border-x border-white/5 hover:border-primary/30 transition-all duration-500 flex flex-col h-full bg-[#0a0a0a] shadow-[0_30px_60px_-15px_rgba(0,0,0,0.5)]"
                >
                  <Link href={`/courses/${course.id}`} className="flex flex-col h-full">
                    {/* Course Banner */}
                    <div className="relative aspect-square w-full overflow-hidden">
                      <Image 
                        src={formatImageUrl(course.courseBanner) || "/images/placeholder.png"} 
                        alt={course.courseName || "Course Banner"}
                        fill
                        className="object-cover transition-transform duration-[2500ms] group-hover:scale-110 ease-out"
                        priority={false}
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-[#0a0a0a] via-black/40 to-transparent opacity-90" />
                      
                      <div className="absolute top-6 right-6">
                         <span className="glass-premium px-5 py-2 rounded-2xl text-[10px] font-black uppercase tracking-widest text-[#0a0a0a] bg-primary">
                            {course.selectedCategory || "Art"}
                         </span>
                      </div>
                    </div>

                    {/* Content */}
                    <div className="p-10 flex flex-col flex-grow relative -mt-10 backdrop-blur-3xl bg-black/40 rounded-t-[48px] border-t border-white/10">
                        <div className="flex items-center gap-2 mb-6">
                            <Star className="w-4 h-4 text-primary fill-primary" />
                            <span className="text-sm font-black text-white/90">4.9</span>
                            <span className="text-white/20 mx-2">|</span>
                            <Users className="w-4 h-4 text-primary/60" />
                            <span className="text-xs font-bold text-white/50 tracking-wider uppercase font-outfit">{course.enrolledCount || 0} {t("home.students")}</span>
                        </div>

                        <h3 className="text-3xl font-black font-outfit mb-4 text-white group-hover:gold-text transition-all duration-500 leading-tight">
                           <AutoTranslatedText text={course.courseName || course.courseTitle} />
                        </h3>
                        
                        <div className="flex-grow">
                           <p className="text-white/40 text-sm font-medium line-clamp-2 leading-relaxed mb-8">
                              <AutoTranslatedText text={course.courseDescription || "Master the foundations of classical Arabic scripts."} />
                           </p>
                        </div>

                        <div className="flex justify-between items-center pt-8 border-t border-white/5">
                            <div className="flex flex-col">
                                <span className="text-xs font-bold text-white/30 line-through">${Number(course.price).toFixed(0)}</span>
                                <span className="text-3xl font-black font-outfit text-primary">${(Number(course.price) / 2).toFixed(0)}</span>
                            </div>
                            <div className="w-14 h-14 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center group-hover:bg-primary group-hover:scale-110 transition-all duration-300">
                                <ArrowRight className="w-6 h-6 text-primary group-hover:text-black transition-colors" />
                            </div>
                        </div>
                    </div>
                  </Link>
                </motion.div>
              ))
            )}
          </AnimatePresence>
        </div>
      </section>

      <Footer />
    </main>
  );
}
