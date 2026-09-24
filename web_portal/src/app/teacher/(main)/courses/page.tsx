"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { BookOpen, Users, Star, Search, Play, ChevronRight, Loader2, Filter, Video, Plus, X, MonitorPlay, Radio } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { collection, query, where, getDocs } from "firebase/firestore";
import Link from "next/link";
import Image from "next/image";
import { onAuthStateChanged } from "firebase/auth";
import { useTranslation } from "@/hooks/useTranslation";

const fadeUp = (delay = 0) => ({
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay, ease: "easeOut" as const },
});

export default function TeacherCoursesPage() {
  const [courses, setCourses] = useState<any[]>([]);
  const [filtered, setFiltered] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [activeTab, setActiveTab] = useState<"live" | "recorded">("live");
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const { t } = useTranslation();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) return;
      try {
        const snap = await getDocs(
          query(collection(db, "courses"), where("teacherId", "==", user.uid))
        );
        const list = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        setCourses(list);
        setFiltered(list);
      } finally {
        setLoading(false);
      }
    });
    return () => unsub();
  }, []);

  useEffect(() => {
    const q = search.toLowerCase();
    setFiltered(courses.filter(c => {
      const type = c.courseType || "live";
      if (type !== activeTab) return false;
      return (c.courseName || c.courseTitle || "").toLowerCase().includes(q);
    }));
  }, [search, courses, activeTab]);

  if (loading) {
    return (
      <div className="flex h-[70vh] items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#D4AF37] animate-spin" />
      </div>
    );
  }

  const visibleCourses = courses.filter(c => (c.courseType || "live") === activeTab);
  const totalStudents = visibleCourses.reduce((a, c) => a + (c.enrolledStudents?.length || 0), 0);

  return (
    <div className="space-y-8 pb-20">

      {/* Header */}
      <motion.div {...fadeUp(0)} className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
        <div>
          <p className="text-white/35 text-sm font-medium mb-1">{t('teacher.studio')}</p>
          <h1 className="text-3xl md:text-4xl font-bold text-white tracking-tight">{t('teacher.courses.title')}</h1>
          <p className="text-white/35 text-sm mt-2">
            {visibleCourses.length} {t('teacher.courses.subtitle_part1')} · {totalStudents} {t('teacher.courses.subtitle_part2')}
          </p>
        </div>
        <button
          onClick={() => setIsCreateModalOpen(true)}
          className="flex items-center gap-2 px-6 py-3 rounded-xl text-black font-bold whitespace-nowrap shadow-[0_0_20px_rgba(212,175,55,0.3)] transition-transform hover:scale-105 active:scale-95"
          style={{ background: "linear-gradient(135deg, #D4AF37, #E0C17E)" }}
        >
          <Plus className="w-5 h-5" /> إنشاء دورة جديدة
        </button>
      </motion.div>

      {/* Summary Cards */}
      <motion.div {...fadeUp(0.05)} className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: t('teacher.courses.stat_total'), value: visibleCourses.length, color: "#60A5FA", glow: "rgba(96,165,250,0.1)" },
          { label: t('teacher.courses.stat_students'), value: totalStudents, color: "#34D399", glow: "rgba(52,211,153,0.1)" },
          { label: t('teacher.courses.stat_rating'), value: visibleCourses.length ? (visibleCourses.reduce((a, c) => a + (c.rating || 0), 0) / visibleCourses.length).toFixed(1) : "—", color: "#D4AF37", glow: "rgba(212,175,55,0.1)" },
          { label: t('teacher.courses.stat_reviews'), value: visibleCourses.reduce((a, c) => a + (c.reviewCount || 0), 0), color: "#A78BFA", glow: "rgba(167,139,250,0.1)" },
        ].map(({ label, value, color, glow }) => (
          <div key={label} className="rounded-2xl p-5 border border-white/[0.06]" style={{ background: "#232323" }}>
            <p className="text-2xl font-bold text-white">{value}</p>
            <p className="text-white/40 text-xs font-medium mt-1">{label}</p>
            <div className="h-0.5 rounded-full mt-3 w-8" style={{ background: color }} />
          </div>
        ))}
      </motion.div>

      {/* Tabs & Search */}
      <motion.div {...fadeUp(0.1)} className="flex flex-col md:flex-row items-center gap-4 justify-between border-b border-white/5 pb-4">
        
        {/* Tabs */}
        <div className="flex items-center gap-2 bg-[#1A1A1A] p-1.5 rounded-xl border border-white/5 w-full md:w-auto">
          <button
            onClick={() => setActiveTab("live")}
            className={`flex-1 md:flex-none flex items-center justify-center gap-2 px-6 py-2.5 rounded-lg text-sm font-bold transition-all ${
              activeTab === "live" ? "bg-[#232323] text-white shadow-lg border border-white/10" : "text-white/40 hover:text-white hover:bg-white/5 border border-transparent"
            }`}
          >
            <Radio className={`w-4 h-4 ${activeTab === "live" ? "text-red-500" : ""}`} /> الدورات المباشرة
          </button>
          <button
            onClick={() => setActiveTab("recorded")}
            className={`flex-1 md:flex-none flex items-center justify-center gap-2 px-6 py-2.5 rounded-lg text-sm font-bold transition-all ${
              activeTab === "recorded" ? "bg-[#232323] text-white shadow-lg border border-white/10" : "text-white/40 hover:text-white hover:bg-white/5 border border-transparent"
            }`}
          >
            <MonitorPlay className={`w-4 h-4 ${activeTab === "recorded" ? "text-blue-500" : ""}`} /> الدورات المسجلة
          </button>
        </div>

        {/* Search */}
        <div className="relative w-full md:max-w-sm">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30" />
          <input
            type="text"
            placeholder={t('teacher.courses.search')}
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full bg-[#232323] border border-white/[0.08] rounded-xl pl-10 pr-4 py-3 text-sm text-white placeholder-white/25 outline-none focus:border-[#D4AF37]/40 transition-colors"
          />
        </div>
      </motion.div>

      {/* Course Grid */}
      {filtered.length === 0 ? (
        <motion.div {...fadeUp(0.15)} className="rounded-2xl border border-dashed border-white/10 p-16 text-center" style={{ background: "#232323" }}>
          <BookOpen className="w-10 h-10 text-white/15 mx-auto mb-4" />
          <p className="text-white font-semibold mb-2">{search ? t('teacher.courses.no_courses_search') : t('teacher.courses.no_courses')}</p>
          <p className="text-white/35 text-sm max-w-xs mx-auto leading-relaxed">
            {search ? t('teacher.courses.no_courses_search') : t('teacher.courses.no_courses_desc')}
          </p>
        </motion.div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
          {filtered.map((course, idx) => {
            const enrolled = course.enrolledStudents?.length || 0;
            const max = course.maxStudents;
            const fillPct = max ? Math.min((enrolled / max) * 100, 100) : 20;
            return (
              <motion.div key={course.id} {...fadeUp(0.05 * idx)}
                className="group rounded-2xl overflow-hidden border border-white/[0.06] hover:border-[#D4AF37]/20 transition-all duration-300 hover:-translate-y-1 flex flex-col"
                style={{ background: "#232323", boxShadow: "0 4px 24px rgba(0,0,0,0.3)" }}
              >
                {/* Thumbnail */}
                <div className="relative h-48 bg-[#1A1A1A] overflow-hidden shrink-0">
                  {(course.courseBanner || course.thumbnailUrl)
                    ? <Image src={(course.courseBanner || course.thumbnailUrl).startsWith("assets/") ? `/${course.courseBanner || course.thumbnailUrl}` : (course.courseBanner || course.thumbnailUrl)} alt={course.courseName || ""} fill className="object-cover group-hover:scale-105 transition-transform duration-500" />
                    : <div className="absolute inset-0 flex items-center justify-center"><BookOpen className="w-12 h-12 text-white/10" /></div>
                  }
                  <div className="absolute inset-0 bg-gradient-to-t from-[#232323] via-black/10 to-transparent" />
                  {/* Hover overlay */}
                  <div className="absolute inset-0 flex items-center justify-center gap-3 opacity-0 group-hover:opacity-100 transition-all duration-300 bg-black/50 backdrop-blur-sm">
                    {activeTab === "live" ? (
                      <>
                        <Link href={`/teacher/courses/${course.id}`}>
                          <button className="flex items-center gap-2 text-sm font-bold px-4 py-2.5 rounded-xl text-black"
                            style={{ background: "linear-gradient(135deg, #D4AF37, #B58C28)" }}>
                            <Play className="w-3.5 h-3.5 fill-black" /> {t('teacher.dashboard.open_studio')}
                          </button>
                        </Link>
                        <Link href={`/teacher/courses/${course.id}/classroom`}>
                          <button className="flex items-center gap-2 text-sm font-bold px-4 py-2.5 rounded-xl text-white border border-white/20 bg-white/10 backdrop-blur-sm hover:bg-white/20 transition-colors">
                            <Video className="w-3.5 h-3.5" /> {t('teacher.courses.go_live')}
                          </button>
                        </Link>
                      </>
                    ) : (
                      <Link href={`/teacher/courses/${course.id}/edit`}>
                        <button className="flex items-center gap-2 text-sm font-bold px-5 py-2.5 rounded-xl text-black"
                          style={{ background: "linear-gradient(135deg, #60A5FA, #3B82F6)" }}>
                          <BookOpen className="w-4 h-4 fill-black/20" /> تعديل المحتوى
                        </button>
                      </Link>
                    )}
                  </div>
                  {/* Badges */}
                  <div className="absolute top-3 left-3 text-white text-xs font-bold px-2.5 py-1 rounded-lg border border-white/10 backdrop-blur-sm"
                    style={{ background: "rgba(0,0,0,0.65)" }}>
                    {course.price ? `$${course.price}` : t('teacher.courses.free')}
                  </div>
                  <div className="absolute top-3 right-3 flex items-center gap-1.5 text-white text-xs px-2.5 py-1 rounded-lg border border-white/10 backdrop-blur-sm"
                    style={{ background: "rgba(0,0,0,0.65)" }}>
                    <Users className="w-3 h-3" /> {enrolled}
                  </div>
                  {/* Status Badge */}
                  {course.status && (
                    <div className={`absolute bottom-3 left-3 text-xs font-bold px-2.5 py-1 rounded-lg border backdrop-blur-sm ${
                      course.status === 'published' ? 'bg-green-500/20 border-green-500/40 text-green-400' :
                      course.status === 'needs_revision' ? 'bg-red-500/20 border-red-500/40 text-red-400 animate-pulse' :
                      course.status === 'under_review' ? 'bg-amber-500/20 border-amber-500/40 text-amber-400' :
                      course.status === 'rejected' ? 'bg-red-500/20 border-red-500/40 text-red-400' :
                      'bg-white/10 border-white/10 text-white/50'
                    }`}>
                      {course.status === 'published' ? '✅ منشور' :
                       course.status === 'needs_revision' ? '⚠️ يتطلب تعديلات' :
                       course.status === 'under_review' ? '⏳ قيد المراجعة' :
                       course.status === 'rejected' ? '❌ مرفوض' :
                       '📝 مسودة'}
                    </div>
                  )}
                </div>

                {/* Body */}
                <div className="p-5 flex flex-col flex-1">
                  <h3 className="text-white font-semibold text-[15px] leading-snug line-clamp-2 mb-auto">
                    {course.courseName || course.courseTitle || "Untitled Course"}
                  </h3>

                  <div className="mt-4 space-y-3">
                    {/* Enrollment bar */}
                    <div>
                      <div className="flex justify-between text-[10px] text-white/25 mb-1.5">
                        <span>{t('teacher.courses.enrollment')}</span>
                        <span>{enrolled}{max ? `/${max}` : ""} {t('teacher.dashboard.enrolled')}</span>
                      </div>
                      <div className="h-1 bg-white/5 rounded-full overflow-hidden">
                        <div className="h-full rounded-full transition-all duration-500"
                          style={{ width: `${fillPct}%`, background: "linear-gradient(90deg, #D4AF37, #E0C17E)" }} />
                      </div>
                    </div>

                    {/* Footer row */}
                    <div className="flex items-center justify-between pt-1">
                      <div className="flex items-center gap-1 text-xs" style={{ color: "#D4AF37" }}>
                        <Star className="w-3.5 h-3.5" style={{ fill: "#D4AF37" }} />
                        <span className="font-bold">{course.rating?.toFixed(1) || "—"}</span>
                        <span className="text-white/20">({course.reviewCount || 0})</span>
                      </div>
                      <Link href={`/teacher/courses/${course.id}`}
                        className="flex items-center gap-1 text-xs font-semibold text-white/35 hover:text-white transition-colors">
                        {t('teacher.dashboard.manage')} <ChevronRight className="w-3.5 h-3.5" />
                      </Link>
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}

      {/* Create Course Modal */}
      <AnimatePresence>
        {isCreateModalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div 
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setIsCreateModalOpen(false)}
              className="absolute inset-0 bg-black/80 backdrop-blur-sm"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="relative w-full max-w-2xl bg-[#13151A] border border-white/10 rounded-3xl shadow-2xl overflow-hidden"
            >
              <div className="p-6 border-b border-white/10 flex items-center justify-between">
                <h2 className="text-xl font-bold text-white">اختر نوع الدورة</h2>
                <button 
                  onClick={() => setIsCreateModalOpen(false)}
                  className="p-2 rounded-full hover:bg-white/10 text-white/50 hover:text-white transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
              
              <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-4">
                
                {/* Live Course Option */}
                <div className="border border-white/10 rounded-2xl p-6 bg-[#1A1A1A] hover:bg-[#232323] hover:border-[#D4AF37]/50 transition-all group flex flex-col cursor-not-allowed opacity-80">
                  <div className="w-12 h-12 rounded-xl bg-red-500/10 border border-red-500/20 flex items-center justify-center mb-4">
                    <Radio className="w-6 h-6 text-red-500" />
                  </div>
                  <h3 className="text-lg font-bold text-white mb-2">دورة مباشرة (Live)</h3>
                  <p className="text-white/50 text-sm leading-relaxed mb-6 flex-1">
                    قم بإنشاء جدول حصص تفاعلية مباشرة مع الطلاب باستخدام غرف Calligro Meet الافتراضية.
                  </p>
                  <div className="bg-white/5 p-3 rounded-lg border border-white/5">
                    <p className="text-[#D4AF37] text-xs font-bold flex items-center gap-2">
                      <span className="w-1.5 h-1.5 rounded-full bg-[#D4AF37] animate-pulse" />
                      يرجى استخدام تطبيق الجوال لإنشاء الدورات المباشرة.
                    </p>
                  </div>
                </div>

                {/* Recorded Course Option */}
                <Link href="/teacher/courses/new" onClick={() => setIsCreateModalOpen(false)}>
                  <div className="border border-white/10 rounded-2xl p-6 bg-[#1A1A1A] hover:bg-[#232323] hover:border-blue-500/50 transition-all group flex flex-col h-full cursor-pointer hover:-translate-y-1 shadow-lg">
                    <div className="w-12 h-12 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center mb-4">
                      <MonitorPlay className="w-6 h-6 text-blue-400" />
                    </div>
                    <h3 className="text-lg font-bold text-white mb-2">دورة مسجلة (Recorded)</h3>
                    <p className="text-white/50 text-sm leading-relaxed mb-6 flex-1">
                      قم برفع مقاطع فيديو مسجلة مسبقاً، وإضافة ملفات PDF ليتعلم الطلاب في أي وقت.
                    </p>
                    <button className="w-full py-3 rounded-xl bg-white/5 group-hover:bg-blue-600 transition-colors text-white text-sm font-bold flex items-center justify-center gap-2">
                      <Plus className="w-4 h-4" /> إنشاء دورة مسجلة
                    </button>
                  </div>
                </Link>

              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

    </div>
  );
}
