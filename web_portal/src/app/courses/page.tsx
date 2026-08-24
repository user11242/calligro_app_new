"use client";
import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { db, auth } from "@/lib/firebase";
import { collection, query, orderBy, onSnapshot } from "firebase/firestore";
import { onAuthStateChanged, User } from "firebase/auth";
import Navbar from "@/components/Navbar";
import CourseCard from "@/components/CourseCard";
import { Search, Loader2 } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { useTranslation } from "@/hooks/useTranslation";

export default function CoursesPage() {
  const searchParams = useSearchParams();
  const [courses, setCourses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState(searchParams?.get("q") || "");
  const [isSearchFocused, setIsSearchFocused] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState("All");
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const { t } = useTranslation();

  const categories = ["All", ...(currentUser ? ["MyCourses"] : []), "Beginner", "Intermediate", "Advanced"];

  useEffect(() => {
    setCurrentPage(1);
  }, [search, selectedCategory]);

  useEffect(() => {
    const q = searchParams?.get("q");
    if (q !== null && q !== undefined) {
      setSearch(q);
    }
  }, [searchParams]);

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
    
    const enrolledStudents = Array.isArray(c.enrolledStudents) ? c.enrolledStudents : [];
    const isEnrolled = currentUser ? enrolledStudents.includes(currentUser.uid) : false;
    
    const matchesCategory = 
      selectedCategory === "All" || 
      (selectedCategory === "MyCourses" && isEnrolled) ||
      (selectedCategory !== "MyCourses" && c.selectedCategory === selectedCategory);
    
    return matchesSearch && matchesCategory;
  });

  const coursesPerPage = 5;
  const totalPages = Math.ceil(filteredCourses.length / coursesPerPage);
  const paginatedCourses = filteredCourses.slice((currentPage - 1) * coursesPerPage, currentPage * coursesPerPage);

  return (
    <main className="min-h-screen bg-transparent selection:bg-[#E8C468]/30 relative text-[#FDFBF7]">
      
      {/* ── AMBIENT BACKGROUND ── */}
      <div className="fixed inset-0 z-0 pointer-events-none bg-[url('/images/noise.png')] opacity-[0.03]" />
      
      {/* Subtle Sidebar Glow */}
      <div className="fixed top-0 right-0 w-[500px] h-full bg-[#E8C468]/[0.02] blur-[150px] pointer-events-none z-0" />

      <div className="relative z-50">
        <Navbar />
      </div>
      
      {/* ── MAIN EDITORIAL LAYOUT ── */}
      <section className="relative pt-32 md:pt-40 px-6 md:px-12 z-10 pb-64">
        <div className="max-w-[1400px] mx-auto flex flex-col lg:flex-row gap-12 lg:gap-16">
          
          {/* ── LEFT COLUMN (Right in RTL): ENHANCED SIDEBAR ── */}
          <div className="w-full lg:w-[350px] shrink-0 lg:sticky lg:top-40 self-start">
            <div className="flex flex-col space-y-12">
              
              {/* Massive Title Area */}
              <div className="space-y-6">
                <div className="w-12 h-1 bg-[#E8C468] rounded-full" />
                <h1 
                  className="text-5xl md:text-6xl lg:text-[70px] font-black font-outfit uppercase tracking-tighter text-white" 
                  style={{ lineHeight: '1.3' }}
                >
                  {t("portal.title") || "Courses"}
                </h1>
                <p className="text-white/50 text-base leading-relaxed max-w-sm">
                  {t("portal.subtitle") || "Master the art of modern calligraphy with our premium selection of courses."}
                </p>
              </div>

              {/* Refined Search Pill */}
              <div className="relative group">
                <div className={`absolute inset-0 bg-[#E8C468]/5 rounded-2xl blur-lg transition-opacity duration-300 ${isSearchFocused ? 'opacity-100' : 'opacity-0'}`} />
                <div className="relative flex items-center bg-white/[0.03] border border-white/10 rounded-2xl px-4 py-3.5 shadow-inner transition-colors focus-within:border-[#E8C468]/50 focus-within:bg-white/[0.05]">
                  <Search className={`w-5 h-5 transition-colors ${isSearchFocused ? 'text-[#E8C468]' : 'text-white/30'}`} />
                  <input 
                    type="text" 
                    placeholder={t("portal.search_placeholder") || "Search Library..."}
                    onFocus={() => setIsSearchFocused(true)}
                    onBlur={() => setIsSearchFocused(false)}
                    className="w-full bg-transparent border-none px-4 text-sm text-white placeholder:text-white/30 outline-none"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
              </div>

              {/* Enhanced Categories List (Larger, more structured) */}
              <div className="space-y-6 pt-2">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] text-white/40 font-black uppercase tracking-[0.2em]">{t("categories.title")}</span>
                </div>
                
                <div className="flex flex-row lg:flex-col gap-2 lg:gap-3 overflow-x-auto hide-scrollbar pb-4 lg:pb-0">
                  {categories.map((cat) => (
                    <button
                      key={cat}
                      onClick={() => setSelectedCategory(cat)}
                      className="group relative flex items-center justify-between shrink-0 transition-all duration-300 w-full"
                    >
                      <div className={`flex items-center px-5 py-4 rounded-xl w-full transition-all duration-300 border ${
                        selectedCategory === cat
                          ? "bg-white/[0.06] border-white/10"
                          : "bg-transparent border-transparent hover:bg-white/[0.02]"
                      }`}>
                        <span className={`text-sm md:text-base font-bold tracking-wide transition-colors duration-300 ${
                          selectedCategory === cat 
                            ? "text-white" 
                            : "text-white/50 group-hover:text-white/80"
                        }`}>
                          {t(`categories.${cat.toLowerCase()}`)}
                        </span>
                        
                        {/* Active Indicator Line */}
                        {selectedCategory === cat && (
                          <motion.div 
                            layoutId="activeCategorySidebar"
                            className="absolute right-0 top-1/2 -translate-y-1/2 w-1.5 h-6 bg-[#E8C468] rounded-l-full"
                          />
                        )}
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Verify Certificate Button */}
              <div className="pt-8">
                <a 
                  href="/verify"
                  className="group relative flex items-center justify-between bg-gradient-to-r from-[#d4af37]/10 to-transparent border border-[#d4af37]/20 rounded-2xl p-5 hover:bg-[#d4af37]/20 hover:border-[#d4af37]/40 transition-all duration-300"
                >
                  <div className="flex flex-col">
                    <span className="text-white font-bold text-lg mb-1">{t("portal.verify_btn_title") || "Verify a Certificate"}</span>
                    <span className="text-white/50 text-xs">{t("portal.verify_btn_subtitle") || "Check the authenticity of an ID"}</span>
                  </div>
                  <div className="w-10 h-10 rounded-full bg-[#d4af37] flex items-center justify-center shadow-[0_0_15px_rgba(212,175,55,0.4)] group-hover:scale-110 transition-transform">
                    <svg className="w-5 h-5 text-[#111111]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                </a>
              </div>

            </div>
          </div>

          {/* ── VERTICAL DIVIDER ── */}
          <div className="hidden lg:block w-px bg-gradient-to-b from-white/10 via-white/5 to-transparent self-stretch" />

          {/* ── RIGHT COLUMN (Left in RTL): STACKED DECK COURSES ── */}
          <div className="flex-1 w-full min-w-0">
            {loading ? (
              <div className="flex flex-col items-center justify-center py-40 gap-6 h-full">
                <Loader2 className="w-10 h-10 text-white/20 animate-spin" />
              </div>
            ) : filteredCourses.length > 0 ? (
              <div className="flex flex-col relative pb-[20vh]">
                <AnimatePresence>
                  {paginatedCourses.map((course, idx) => {
                    return (
                      <motion.div
                        key={course.id}
                        layout
                        initial={{ opacity: 0, y: 50 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, scale: 0.95 }}
                        transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                        className="w-full relative"
                      >
                        <CourseCard course={course} />
                      </motion.div>
                    );
                  })}
                </AnimatePresence>
                
                {/* Pagination Controls */}
                {totalPages > 1 && (
                  <div className="flex items-center justify-center space-x-6 rtl:space-x-reverse pt-12 border-t border-white/5 mt-12">
                    <button
                      onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                      disabled={currentPage === 1}
                      className="px-5 py-2.5 bg-white/5 hover:bg-white/10 disabled:opacity-30 disabled:pointer-events-none rounded-xl text-white text-sm font-bold uppercase tracking-widest transition-all border border-white/10"
                    >
                      {t("pagination.prev") || "Prev"}
                    </button>
                    <span className="text-white/60 text-sm font-bold tracking-widest">
                      {currentPage} / {totalPages}
                    </span>
                    <button
                      onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                      disabled={currentPage === totalPages}
                      className="px-5 py-2.5 bg-white/5 hover:bg-white/10 disabled:opacity-30 disabled:pointer-events-none rounded-xl text-white text-sm font-bold uppercase tracking-widest transition-all border border-white/10"
                    >
                      {t("pagination.next") || "Next"}
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <motion.div 
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="flex flex-col items-start justify-center py-32 space-y-8"
              >
                <h2 className="text-3xl font-light text-white/40 tracking-wide">
                  {t("portal.no_results") || "No courses found."}
                </h2>
                <button 
                  onClick={() => { setSearch(""); setSelectedCategory("All"); }}
                  className="px-6 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-white text-xs font-black uppercase tracking-widest transition-colors border border-white/10"
                >
                  {t("portal.clear_filters") || "Clear Filters"}
                </button>
              </motion.div>
            )}
          </div>

        </div>
      </section>
    </main>
  );
}
