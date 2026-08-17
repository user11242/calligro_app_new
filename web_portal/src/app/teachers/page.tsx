"use client";
import { useState, useEffect } from "react";
import { db } from "@/lib/firebase";
import { collection, query, where, onSnapshot } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import TeacherCard from "@/components/TeacherCard";
import { Loader2, Users, Search } from "lucide-react";
import { motion } from "framer-motion";
import { useTranslation } from "@/hooks/useTranslation";

export default function TeachersPage() {
  const [teachers, setTeachers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const { t } = useTranslation();

  useEffect(() => {
    // Fetch users with role "teacher"
    const q = query(collection(db, "users"), where("role", "==", "teacher"));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const teacherList = snapshot.docs.map(doc => ({
        uid: doc.id,
        ...doc.data()
      }));
      setTeachers(teacherList);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  return (
    <main className="min-h-screen bg-transparent pt-32 pb-24">
      <Navbar />
      
      {/* Clean Header */}
      <section className="px-6 mb-16">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6 border-b border-white/10 pb-8">
          <div>
            <h1 className="text-3xl md:text-5xl font-black font-outfit uppercase tracking-wider text-white">
              {t("teachers.title") || "Teachers"}
            </h1>
          </div>
          
          <div className="relative w-full md:w-80 shrink-0">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-white/40" />
            <input 
              type="text"
              placeholder={t("teachers.search_placeholder") || "Search..."}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded-xl py-3 pl-10 pr-4 text-sm text-white placeholder-white/40 outline-none focus:border-[#E8C468]/50 focus:bg-white/10 transition-all"
            />
          </div>
        </div>
      </section>

      {/* Teachers Grid */}
      <section className="px-6">
        <div className="max-w-7xl mx-auto">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-40 gap-6">
              <div className="relative">
                <div className="absolute inset-0 bg-primary/20 blur-xl rounded-full animate-pulse" />
                <Loader2 className="w-12 h-12 text-primary animate-spin relative" />
              </div>
              <p className="text-sm font-black uppercase tracking-[0.3em] text-white/20 animate-pulse">
                {t("teachers.syncing")}
              </p>
            </div>
          ) : teachers.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-10">
              {teachers.filter(teacher => {
                const term = searchQuery.toLowerCase();
                const name = (teacher.fullName || teacher.name || "").toLowerCase();
                return name.includes(term);
              }).map((teacher, index) => (
                <motion.div
                  key={teacher.uid}
                  initial={{ opacity: 0, y: 30 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.6, delay: index * 0.1, ease: [0.23, 1, 0.32, 1] }}
                >
                  <TeacherCard teacher={teacher} />
                </motion.div>
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-40 text-center space-y-8">
              <div className="w-32 h-32 bg-white/5 rounded-[2.5rem] flex items-center justify-center border border-white/10 group hover:border-primary/30 transition-all duration-700">
                <Users className="w-12 h-12 text-white/10 group-hover:text-primary/40 transition-all" />
              </div>
              <div className="space-y-3">
                <h3 className="text-2xl font-black font-outfit uppercase tracking-tight text-white/40 italic">
                  {t("teachers.no_results")}
                </h3>
              </div>
            </div>
          )}
        </div>
      </section>

      {/* Footer Space */}
      <div className="h-40" />
    </main>
  );
}
