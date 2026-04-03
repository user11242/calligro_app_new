"use client";
import { useEffect, useState } from "react";
import { db } from "@/lib/firebase";
import { collection, query, orderBy, onSnapshot } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import CourseCard from "@/components/CourseCard";
import { Search, SlidersHorizontal, Loader2 } from "lucide-react";
import { motion } from "framer-motion";
import AutoTranslatedText from "@/components/AutoTranslatedText";

export default function CoursesPage() {
  const [courses, setCourses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

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

  const filteredCourses = courses.filter(c => 
    c.courseTitle?.toLowerCase().includes(search.toLowerCase()) ||
    c.teacherName?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <main className="min-h-screen bg-secondary-dark">
      <Navbar />
      
      {/* Header */}
      <section className="pt-40 pb-12 px-6">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-8 mb-12">
            <div>
              <h1 className="text-4xl md:text-5xl font-bold font-outfit mb-4 uppercase tracking-tight">
                <AutoTranslatedText text="Academy" /> <span className="gold-text"><AutoTranslatedText text="Portal" /></span>
              </h1>
              <p className="text-white/40 max-w-lg">
                <AutoTranslatedText text="Your destination for authentic calligraphy education. Join masterclasses and secure your seat in our interactive live classrooms." />
              </p>
            </div>

            {/* Filters / Search */}
            <div className="flex items-center gap-4 w-full md:w-auto">
              <div className="relative flex-grow md:w-80 group">
                <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-white/20 group-focus-within:text-primary transition-colors" />
                <input 
                  type="text" 
                  placeholder="..." 
                  className="input-glass pl-12"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
                <div className="absolute left-12 top-1/2 -translate-y-1/2 pointer-events-none">
                   {!search && <span className="text-white/20 text-sm"><AutoTranslatedText text="Search courses or teachers..." /></span>}
                </div>
              </div>
              <button className="glass p-3 rounded-xl hover:text-primary transition-colors">
                <SlidersHorizontal className="w-6 h-6" />
              </button>
            </div>
          </div>

          {loading ? (
            <div className="flex flex-col items-center justify-center py-40 gap-4">
              <Loader2 className="w-10 h-10 text-primary animate-spin" />
              <p className="text-white/20 font-bold uppercase tracking-widest text-xs">
                <AutoTranslatedText text="Syncing Academy..." />
              </p>
            </div>
          ) : filteredCourses.length > 0 ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
              {filteredCourses.map((course, idx) => (
                <motion.div
                  key={course.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: idx * 0.05 }}
                >
                  <CourseCard course={course} />
                </motion.div>
              ))}
            </div>
          ) : (
            <div className="text-center py-40">
              <p className="text-white/40 text-lg">
                <AutoTranslatedText text="No courses found matching your search." />
              </p>
            </div>
          )}
        </div>
      </section>
    </main>
  );
}
