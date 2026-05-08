"use client";
import { useEffect, useState } from "react";
import { db } from "@/lib/firebase";
import { collection, query, orderBy, onSnapshot } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import CourseCard from "@/components/CourseCard";
import { Search, SlidersHorizontal, Loader2 } from "lucide-react";
import { motion } from "framer-motion";
import { useTranslation } from "@/hooks/useTranslation";

export default function CoursesPage() {
  const [courses, setCourses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("All");
  const [isFilterOpen, setIsFilterOpen] = useState(false);
  const { t } = useTranslation();

  const categories = ["All", "Beginner", "Intermediate", "Advanced"];

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
    <main className="min-h-screen bg-secondary-dark">
      <Navbar />
      
      {/* Header */}
      <section className="pt-40 pb-12 px-6">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col gap-10 mb-16">
            <div className="flex flex-col md:flex-row md:items-end justify-between gap-8">
              <div className="space-y-4">
                <h1 className="text-5xl md:text-7xl font-bold font-outfit uppercase tracking-tighter leading-none">
                  {t("portal.title")}
                </h1>
                <p className="text-white/40 max-w-lg text-lg leading-relaxed">
                  {t("portal.subtitle")}
                </p>
              </div>

              {/* Enhanced Search & Filter Row */}
              <div className="flex items-center gap-4 w-full md:w-auto relative">
                <div className="relative flex-grow md:w-96 group">
                  <Search className="absolute left-6 top-1/2 -translate-y-1/2 w-5 h-5 text-white/20 group-focus-within:text-primary transition-all duration-300" />
                  <input 
                    type="text" 
                    placeholder={t("portal.search_placeholder")} 
                    className="w-full bg-white/[0.03] border border-white/10 rounded-2xl py-5 pl-14 pr-6 text-white placeholder:text-white/10 outline-none focus:border-primary/50 focus:bg-white/[0.05] transition-all duration-500 shadow-2xl backdrop-blur-xl"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
                
                {/* Filter Trigger Button */}
                <div className="relative">
                  <button 
                    onClick={() => setIsFilterOpen(!isFilterOpen)}
                    className={`p-5 rounded-2xl border transition-all duration-500 glass ${
                      isFilterOpen || selectedCategory !== "All" 
                        ? "bg-primary text-black border-primary shadow-[0_10px_30px_rgba(238,229,147,0.3)]" 
                        : "bg-white/[0.03] text-white/40 border-white/10 hover:border-white/30"
                    }`}
                  >
                    <SlidersHorizontal className="w-6 h-6" />
                  </button>

                  {/* Glass Filter Dropdown */}
                  {isFilterOpen && (
                    <motion.div 
                      initial={{ opacity: 0, y: 10, scale: 0.95 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      className="absolute right-0 top-[calc(100%+12px)] z-50 min-w-[200px] bg-[#1a1a1a] border border-white/10 rounded-3xl p-3 shadow-[0_20px_50px_rgba(0,0,0,0.5)] backdrop-blur-3xl overflow-hidden"
                    >
                      <div className="flex flex-col gap-1">
                        {categories.map((cat) => (
                          <button
                            key={cat}
                            onClick={() => {
                              setSelectedCategory(cat);
                              setIsFilterOpen(false);
                            }}
                            className={`w-full text-left px-5 py-4 rounded-2xl text-xs font-black uppercase tracking-widest transition-all duration-300 border ${
                              selectedCategory === cat 
                                ? "bg-primary/20 text-primary border-primary/30" 
                                : "text-white/40 border-transparent hover:bg-white/[0.05] hover:text-white"
                            }`}
                          >
                            {t(`categories.${cat.toLowerCase()}`)}
                          </button>
                        ))}
                      </div>
                    </motion.div>
                  )}
                </div>
              </div>
            </div>
          </div>

          {loading ? (
            <div className="flex flex-col items-center justify-center py-40 gap-6">
              <div className="relative">
                <Loader2 className="w-16 h-16 text-primary animate-spin" />
                <div className="absolute inset-0 bg-primary/20 blur-2xl animate-pulse" />
              </div>
              <p className="text-white/40 font-black uppercase tracking-[0.3em] text-[10px]">
                {t("portal.syncing")}
              </p>
            </div>
          ) : filteredCourses.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-10 lg:gap-14">
              {filteredCourses.map((course, idx) => (
                <motion.div
                  key={course.id}
                  initial={{ opacity: 0, y: 30 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: idx * 0.1, duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
                >
                  <CourseCard course={course} />
                </motion.div>
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-40 text-center space-y-6">
              <div className="w-20 h-20 rounded-full bg-white/[0.03] border border-white/10 flex items-center justify-center">
                <Search className="w-8 h-8 text-white/10" />
              </div>
              <p className="text-white/40 text-xl font-medium max-w-sm">
                {t("portal.no_results")}
              </p>
              <button 
                onClick={() => { setSearch(""); setSelectedCategory("All"); }}
                className="text-primary text-sm font-black uppercase tracking-widest hover:underline"
              >
                {t("portal.clear_filters")}
              </button>
            </div>
          )}
        </div>
      </section>
    </main>
  );
}
