"use client";
import { useState, useEffect } from "react";
import { db } from "@/lib/firebase";
import { collection, query, where, onSnapshot } from "firebase/firestore";
import Navbar from "@/components/Navbar";
import TeacherCard from "@/components/TeacherCard";
import { Loader2, Users } from "lucide-react";
import { motion } from "framer-motion";
import { useTranslation } from "@/hooks/useTranslation";

export default function TeachersPage() {
  const [teachers, setTeachers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
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
    <main className="min-h-screen bg-secondary-dark">
      <Navbar />
      
      {/* Header */}
      <section className="pt-40 pb-12 px-6 border-b border-white/5">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col gap-6 mb-16">
            <div className="space-y-4">
              <h1 className="text-5xl md:text-7xl font-bold font-outfit uppercase tracking-tighter leading-none italic">
                {t("teachers.title")}
              </h1>
              <p className="text-white/40 max-w-lg text-lg leading-relaxed">
                {t("teachers.subtitle")}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Teachers Grid */}
      <section className="py-24 px-6 relative overflow-hidden">
        {/* Artistic Background Gradients */}
        <div className="absolute top-0 left-1/4 w-[500px] h-[500px] bg-primary/5 rounded-full blur-[120px] -z-10" />
        <div className="absolute bottom-0 right-1/4 w-[500px] h-[500px] bg-primary/3 rounded-full blur-[120px] -z-10" />

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
              {teachers.map((teacher, index) => (
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
