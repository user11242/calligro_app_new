"use client";
import { useEffect, useState } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { db } from "@/lib/firebase";
import { collection, query, limit, getDocs, orderBy } from "firebase/firestore";
import AutoTranslatedText from "@/components/AutoTranslatedText";
import { Star, ArrowRight, Play, Layout, Users, Sparkles } from "lucide-react";
import { formatImageUrl } from "@/lib/utils";

export default function Home() {
  const [courses, setCourses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

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
      transition: { staggerChildren: 0.15, delayChildren: 0.3 }
    }
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0, transition: { duration: 0.8 } }
  };

  return (
    <main className="academy-bg min-h-screen font-sans">
      <Navbar />

      {/* Simplified Hero Section */}
      <section className="relative pt-44 pb-32 px-6 flex flex-col items-center text-center overflow-hidden">
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
          className="max-w-5xl z-10 relative"
        >
          <motion.div variants={itemVariants} className="inline-flex items-center gap-2 px-6 py-2 rounded-full glass border-white/5 mb-10 shadow-xl">
            <Sparkles className="w-4 h-4 text-primary" />
            <span className="text-[10px] font-black uppercase tracking-[4px] text-primary">Academy Portal</span>
          </motion.div>

          <motion.h1 variants={itemVariants} className="text-4xl sm:text-6xl md:text-7xl font-black font-outfit leading-[1.1] tracking-tighter mb-10 select-none gold-glow">
            <AutoTranslatedText text="Master the Art of" /> <br />
            <span className="gold-text"><AutoTranslatedText text="Arabic Calligraphy" /></span>
          </motion.h1>

          <motion.p variants={itemVariants} className="text-lg md:text-xl text-white/40 mb-16 max-w-xl mx-auto leading-relaxed font-medium">
            <AutoTranslatedText text="Professional masterclasses from the world's finest calligraphers on a professional digital portal." />
          </motion.p>

          <motion.div variants={itemVariants} className="flex flex-col sm:flex-row gap-6 justify-center items-center">
             <Link href="/courses">
                <button className="btn-gold group flex items-center gap-4">
                   <AutoTranslatedText text="Explore Academy" />
                   <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                </button>
             </Link>
             <Link href="/download">
                <button className="glass px-10 py-4 rounded-2xl text-white/60 font-black uppercase tracking-widest text-[10px] border-white/5 hover:bg-white/5 transition-all flex items-center gap-4">
                   <AutoTranslatedText text="Mobile App" />
                </button>
             </Link>
          </motion.div>
        </motion.div>
      </section>

      {/* 2. REAL-TIME COURSES (UPGRADED) */}
      <section className="relative py-32 px-6 max-w-7xl mx-auto z-10">
        <motion.div
           initial={{ opacity: 0 }}
           whileInView={{ opacity: 1 }}
           className="flex flex-col md:flex-row justify-between items-end mb-16 gap-8"
        >
          <div className="text-start">
            <p className="text-[10px] font-black text-primary uppercase tracking-[4px] mb-4">Trending Now</p>
            <h2 className="text-4xl md:text-5xl font-black font-outfit">
              <AutoTranslatedText text="Popular Masterclasses" />
            </h2>
          </div>
          <Link href="/courses" className="glass px-8 py-3 rounded-xl text-xs font-black uppercase tracking-widest text-white/60 hover:text-primary transition-all border-white/5">
            <AutoTranslatedText text="Enter Academy Library" />
          </Link>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-10">
          <AnimatePresence mode="wait">
            {loading ? (
               Array(3).fill(0).map((_, i) => (
                <div key={i} className="glass-premium rounded-[40px] aspect-[4/5] animate-pulse bg-white/5" />
               ))
            ) : (
              courses.map((course, i) => (
                <motion.div
                  key={course.id}
                  initial={{ opacity: 0, y: 30 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.1 }}
                  whileHover={{ y: -10 }}
                  className="glass-premium rounded-[44px] overflow-hidden group cursor-pointer border-white/5 hover:border-primary/20 transition-all flex flex-col h-full"
                >
                  <Link href={`/courses/${course.id}`} className="flex flex-col h-full">
                    {/* Course Banner */}
                    <div className="relative aspect-square w-full overflow-hidden">
                      <img 
                        src={formatImageUrl(course.courseBanner)} 
                        alt={course.courseName}
                        className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700"
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-[#121212] via-transparent to-transparent opacity-60" />
                      
                      <div className="absolute top-6 right-6">
                         <span className="glass px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest text-primary border-primary/20 backdrop-blur-xl">
                            {course.selectedCategory || "Art"}
                         </span>
                      </div>
                    </div>

                    {/* Content */}
                    <div className="p-10 flex flex-col flex-grow">
                        <div className="flex items-center gap-2 mb-4">
                            <Star className="w-4 h-4 text-primary fill-primary" />
                            <span className="text-sm font-black text-white/80">4.9</span>
                            <span className="text-white/20 mx-2">|</span>
                            <Users className="w-4 h-4 text-white/30" />
                            <span className="text-xs font-bold text-white/40">{course.enrolledCount || 0} Students</span>
                        </div>

                        <h3 className="text-2xl font-black font-outfit mb-4 group-hover:gold-text transition-all leading-tight">
                           <AutoTranslatedText text={course.courseName || course.courseTitle} />
                        </h3>
                        
                        <div className="flex-grow">
                           <p className="text-white/40 text-xs font-medium line-clamp-2 leading-relaxed mb-6">
                              <AutoTranslatedText text={course.courseDescription || "Master the foundations of classical Arabic scripts."} />
                           </p>
                        </div>

                        <div className="flex justify-between items-center pt-8 border-t border-white/5">
                            <span className="text-2xl font-black font-outfit text-white">${Number(course.price).toFixed(0)}</span>
                            <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center group-hover:bg-primary transition-colors">
                                <ArrowRight className="w-5 h-5 text-primary group-hover:text-secondary-dark transition-colors" />
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

      {/* 3. EXPERIENCE CALLIGRO BANNER */}
      <section className="py-24 px-6 max-w-7xl mx-auto z-10">
          <div className="glass-premium rounded-[40px] md:rounded-[60px] p-8 sm:p-16 md:p-24 relative overflow-hidden text-center border-primary/10">
              <div className="absolute inset-0 bg-primary/5 -z-10" />
              <div className="max-w-2xl mx-auto space-y-10">
                  <Layout className="w-12 h-12 md:w-16 md:h-16 text-primary mx-auto opacity-40 mb-8" />
                  <h3 className="text-3xl sm:text-4xl md:text-6xl font-black font-outfit uppercase tracking-tighter shadow-primary">
                    <AutoTranslatedText text="Your Studio, Anywhere." />
                  </h3>
                  <p className="text-lg md:text-xl text-white/40 font-medium">
                    <AutoTranslatedText text="The Calligro Web Portal is perfectly optimized for your desktop experience. Sync your progress, join live sessions, and view masterworks in high resolution." />
                  </p>
                   <Link href="/login" className="inline-block pt-8">
                      <button className="btn-gold px-16">
                        <AutoTranslatedText text="Access Your Account" />
                      </button>
                   </Link>
              </div>
          </div>
      </section>

      <Footer />
    </main>
  );
}
