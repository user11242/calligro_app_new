"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { db } from "@/lib/firebase";
import { doc, getDoc } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { motion } from "framer-motion";
import { CheckCircle2, Zap, ArrowRight, PlayCircle } from "lucide-react";
import Link from "next/link";
import AutoTranslatedText from "@/components/AutoTranslatedText";

export default function SuccessPage() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const router = useRouter();

  useEffect(() => {
    if (!id) return;
    const fetchCourse = async () => {
      const docRef = doc(db, "courses", id as string);
      const docSnap = await getDoc(docRef);
      if (docSnap.exists()) {
        setCourse({ id: docSnap.id, ...docSnap.data() });
      }
    };
    fetchCourse();
  }, [id]);

  return (
    <main className="academy-bg min-h-screen font-sans overflow-x-hidden">
      <Navbar />

      <section className="pt-44 pb-32 px-6 flex flex-col items-center">
        <motion.div
           initial={{ opacity: 0, scale: 0.9 }}
           animate={{ opacity: 1, scale: 1 }}
           transition={{ duration: 0.6, type: "spring" }}
           className="glass-premium p-12 md:p-20 rounded-[60px] border-white/5 max-w-3xl w-full text-center relative overflow-hidden"
        >
          {/* Decorative Elements */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-40 h-1 bg-gradient-to-r from-transparent via-primary/40 to-transparent"></div>
          
          <div className="relative z-10 flex flex-col items-center">
            <motion.div 
               initial={{ rotate: -10, scale: 0 }}
               animate={{ rotate: 0, scale: 1 }}
               transition={{ delay: 0.3, type: "spring" }}
               className="w-24 h-24 bg-primary/20 rounded-[32px] flex items-center justify-center mb-10 shadow-[0_0_50px_rgba(212,175,55,0.3)] border border-primary/30"
            >
               <CheckCircle2 className="w-12 h-12 text-primary" />
            </motion.div>

            <h1 className="text-4xl md:text-6xl font-black font-outfit gold-text mb-6">
               <AutoTranslatedText text="Enrollment Successful!" />
            </h1>
            
            <p className="text-white/40 text-lg md:text-xl font-medium max-w-md mx-auto mb-12">
               <AutoTranslatedText text="Welcome to the Academy. Your artistic journey starts now." />
            </p>

            {course && (
              <motion.div 
                 initial={{ opacity: 0, y: 20 }}
                 animate={{ opacity: 1, y: 0 }}
                 transition={{ delay: 0.5 }}
                 className="glass p-8 rounded-3xl border-white/5 bg-white/[0.02] mb-12 w-full text-left"
              >
                <p className="text-[10px] font-black text-primary uppercase tracking-[4px] mb-2">Selected Course</p>
                <div className="flex justify-between items-center">
                  <h2 className="text-xl font-bold text-white font-outfit">{course.courseName || course.courseTitle}</h2>
                  <div className="flex items-center gap-2 text-primary/60 text-xs font-black">
                     <PlayCircle className="w-4 h-4" />
                     {course.totalLessons || 0} LESSONS
                  </div>
                </div>
              </motion.div>
            )}

            <div className="flex flex-col sm:flex-row gap-6 w-full">
               <Link 
                  href={`/courses/${id}`}
                  className="flex-1 py-5 bg-primary text-black font-black uppercase tracking-[3px] text-xs rounded-2xl hover:scale-[1.05] transition-all flex items-center justify-center gap-3 shadow-[0_20px_40px_-10px_rgba(212,175,55,0.4)] border-2 border-primary group"
               >
                  <Zap className="w-4 h-4 group-hover:animate-bounce" />
                  <AutoTranslatedText text="Explore Course Dashboard" />
                  <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
               </Link>
               
               <Link 
                  href="/courses"
                  className="flex-1 py-5 bg-white/5 border border-white/10 text-white font-black uppercase tracking-[3px] text-xs rounded-2xl hover:bg-white/10 transition-all flex items-center justify-center"
               >
                  <AutoTranslatedText text="Discover More Art" />
               </Link>
            </div>
          </div>
        </motion.div>
      </section>

      <Footer />
    </main>
  );
}
