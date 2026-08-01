"use client";
import { useEffect, useState } from "react";
import { db, auth } from "@/lib/firebase";
import { collection, query, orderBy, onSnapshot } from "firebase/firestore";
import { onAuthStateChanged, User } from "firebase/auth";
import Navbar from "@/components/Navbar";
import CourseCard from "@/components/CourseCard";
import { Search, Loader2, Sparkles, Filter } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { useTranslation } from "@/hooks/useTranslation";
import Image from "next/image";

export default function CoursesPage() {
  const [courses, setCourses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("All");
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const { t } = useTranslation();

  const categories = ["All", "Beginner", "Intermediate", "Advanced"];

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
    });
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    const q = query(collection(db, "courses"), orderBy("createdAt", "desc"));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const courseList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setCourses(courseList);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const filteredCourses = courses.filter(c => {
    if (c.startDate) {
      const start = c.startDate.toDate ? c.startDate.toDate() : new Date(c.startDate);
      if (!isNaN(start.getTime())) {
        const now = new Date();
        const enrolledStudents = Array.isArray(c.enrolledStudents) ? c.enrolledStudents : [];
        const isEnrolled = currentUser ? enrolledStudents.includes(currentUser.uid) : false;
        
        if (now.getTime() > start.getTime() && !isEnrolled) {
          return false;
        }
      }
    }

    const searchTerm = search.toLowerCase();
    const matchesSearch = 
      (c.courseName?.toLowerCase().includes(searchTerm) ||
       c.courseTitle?.toLowerCase().includes(searchTerm) ||
       c.teacherName?.toLowerCase().includes(searchTerm) ||
       c.selectedCategory?.toLowerCase().includes(searchTerm) ||
       c.courseDescription?.toLowerCase().includes(searchTerm));
    
    const matchesCategory = selectedCategory === "All" || c.selectedCategory === selectedCategory;
    
    return matchesSearch && matchesCategory;
  });

  return (
    <main className="min-h-screen bg-[#13110C] selection:bg-primary/30 relative">
      
      {/* ── AMBIENT WARM TEXTURE ── */}
      <div className="fixed inset-0 z-0 pointer-events-none opacity-[0.03] mix-blend-screen" style={{ backgroundImage: "url('/images/bg_calligraphy.png')", backgroundSize: 'cover', backgroundPosition: 'center', backgroundAttachment: 'fixed' }} />
      <div className="fixed inset-0 z-0 pointer-events-none bg-[url('/images/noise.png')] opacity-[0.02]" />

      <div className="relative z-50">
        <Navbar />
      </div>
      
      {/* ── CINEMATIC HEADER ── */}
      <section className="relative pt-40 pb-20 px-6 overflow-hidden">
        {/* Warm Ambient Glowing Orbs */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[80vw] h-[50vh] bg-[#D4B04C]/5 rounded-full blur-[120px] pointer-events-none" />
        <div className="absolute top-20 right-0 w-[40vw] h-[40vw] bg-[#8B5CF6]/5 rounded-full blur-[100px] pointer-events-none" />
        
        <div className="relative max-w-5xl mx-auto text-center space-y-6 z-10">
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-[#1A1814]/80 border border-[#D4B04C]/20 backdrop-blur-md"
          >
            <Sparkles className="w-4 h-4 text-[#D4B04C]" />
            <span className="text-xs font-bold uppercase tracking-widest text-[#D4B04C]">Masterclass Academy</span>
          </motion.div>
          
          <motion.h1 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="text-5xl md:text-7xl lg:text-8xl font-black font-outfit uppercase tracking-tighter text-[#FDFBF7] drop-shadow-[0_10px_30px_rgba(0,0,0,0.5)]"
          >
            {t("portal.title")}
          </motion.h1>
          
          <motion.p 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
            className="text-[#FDFBF7]/60 text-lg md:text-xl max-w-2xl mx-auto"
          >
            {t("portal.subtitle")}
          </motion.p>
        </div>
      </section>

      {/* ── FLOATING COMMAND BAR (Dynamic Island Style) ── */}
      <section className="sticky top-24 z-40 px-6 mb-16">
        <motion.div 
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="max-w-4xl mx-auto bg-[#1A1814]/80 backdrop-blur-3xl border border-[#FDFBF7]/10 p-2 md:p-3 rounded-full flex flex-col md:flex-row items-center gap-4 shadow-[0_20px_60px_rgba(0,0,0,0.5)]"
        >
          {/* Search Input */}
          <div className="relative flex-1 w-full group">
            <Search className="absolute left-6 top-1/2 -translate-y-1/2 w-5 h-5 text-[#FDFBF7]/40 group-focus-within:text-[#D4B04C] transition-colors" />
            <input 
              type="text" 
              placeholder={t("portal.search_placeholder")}
              className="w-full bg-transparent border-none py-3 md:py-4 pl-14 pr-6 text-[#FDFBF7] placeholder:text-[#FDFBF7]/30 outline-none font-medium"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div className="hidden md:block w-px h-10 bg-[#FDFBF7]/10" />

          {/* Categories Pill Toggle */}
          <div className="flex items-center gap-1 w-full md:w-auto overflow-x-auto hide-scrollbar px-2 pb-2 md:pb-0">
            {categories.map((cat) => (
              <button
                key={cat}
                onClick={() => setSelectedCategory(cat)}
                className={`px-6 py-2.5 rounded-full text-xs font-black uppercase tracking-widest transition-all duration-300 whitespace-nowrap ${
                  selectedCategory === cat 
                    ? "bg-[#D4B04C] text-[#13110C] shadow-[0_0_20px_rgba(212,176,76,0.3)]" 
                    : "text-[#FDFBF7]/50 hover:bg-[#FDFBF7]/5 hover:text-[#FDFBF7]"
                }`}
              >
                {t(`categories.${cat.toLowerCase()}`)}
              </button>
            ))}
          </div>
        </motion.div>
      </section>

      {/* ── COURSE GRID ── */}
      <section className="px-6 pb-40 relative z-10">
        <div className="max-w-7xl mx-auto">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-40 gap-6">
              <div className="relative">
                <Loader2 className="w-16 h-16 text-[#D4B04C] animate-spin" />
                <div className="absolute inset-0 bg-[#D4B04C]/20 blur-2xl animate-pulse" />
              </div>
              <p className="text-[#FDFBF7]/40 font-black uppercase tracking-[0.3em] text-[10px]">
                {t("portal.syncing")}
              </p>
            </div>
          ) : filteredCourses.length > 0 ? (
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-8 lg:gap-12">
              <AnimatePresence>
                {filteredCourses.map((course, idx) => (
                  <motion.div
                    key={course.id}
                    layout
                    initial={{ opacity: 0, scale: 0.95, y: 40 }}
                    animate={{ opacity: 1, scale: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    transition={{ delay: idx * 0.05, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                  >
                    <CourseCard course={course} />
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          ) : (
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex flex-col items-center justify-center py-40 text-center space-y-6"
            >
              <div className="w-24 h-24 rounded-full bg-[#1A1814] border border-[#FDFBF7]/10 flex items-center justify-center">
                <Filter className="w-10 h-10 text-[#FDFBF7]/20" />
              </div>
              <p className="text-[#FDFBF7]/60 text-xl font-medium max-w-sm">
                {t("portal.no_results")}
              </p>
              <button 
                onClick={() => { setSearch(""); setSelectedCategory("All"); }}
                className="px-8 py-3 bg-[#1A1814] hover:bg-[#FDFBF7]/10 rounded-full text-[#FDFBF7] text-sm font-black uppercase tracking-widest transition-colors border border-[#FDFBF7]/10"
              >
                {t("portal.clear_filters")}
              </button>
            </motion.div>
          )}
        </div>
      </section>
    </main>
  );
}
