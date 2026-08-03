"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { BookOpen, Users, Star, Search, Play, ChevronRight, Loader2, Filter, Video } from "lucide-react";
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
    setFiltered(courses.filter(c =>
      (c.courseName || c.courseTitle || "").toLowerCase().includes(q)
    ));
  }, [search, courses]);

  if (loading) {
    return (
      <div className="flex h-[70vh] items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#D4AF37] animate-spin" />
      </div>
    );
  }

  const totalStudents = courses.reduce((a, c) => a + (c.enrolledStudents?.length || 0), 0);

  return (
    <div className="space-y-8 pb-20">

      {/* Header */}
      <motion.div {...fadeUp(0)} className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
        <div>
          <p className="text-white/35 text-sm font-medium mb-1">{t('teacher.studio')}</p>
          <h1 className="text-3xl md:text-4xl font-bold text-white tracking-tight">{t('teacher.courses.title')}</h1>
          <p className="text-white/35 text-sm mt-2">
            {courses.length} {t('teacher.courses.subtitle_part1')} · {totalStudents} {t('teacher.courses.subtitle_part2')}
          </p>
        </div>
      </motion.div>

      {/* Summary Cards */}
      <motion.div {...fadeUp(0.05)} className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: t('teacher.courses.stat_total'), value: courses.length, color: "#60A5FA", glow: "rgba(96,165,250,0.1)" },
          { label: t('teacher.courses.stat_students'), value: totalStudents, color: "#34D399", glow: "rgba(52,211,153,0.1)" },
          { label: t('teacher.courses.stat_rating'), value: courses.length ? (courses.reduce((a, c) => a + (c.rating || 0), 0) / courses.length).toFixed(1) : "—", color: "#D4AF37", glow: "rgba(212,175,55,0.1)" },
          { label: t('teacher.courses.stat_reviews'), value: courses.reduce((a, c) => a + (c.reviewCount || 0), 0), color: "#A78BFA", glow: "rgba(167,139,250,0.1)" },
        ].map(({ label, value, color, glow }) => (
          <div key={label} className="rounded-2xl p-5 border border-white/[0.06]" style={{ background: "#232323" }}>
            <p className="text-2xl font-bold text-white">{value}</p>
            <p className="text-white/40 text-xs font-medium mt-1">{label}</p>
            <div className="h-0.5 rounded-full mt-3 w-8" style={{ background: color }} />
          </div>
        ))}
      </motion.div>

      {/* Search */}
      <motion.div {...fadeUp(0.1)} className="flex items-center gap-3">
        <div className="relative flex-1 max-w-sm">
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
                  {course.courseBanner
                    ? <Image src={course.courseBanner.startsWith("assets/") ? `/${course.courseBanner}` : course.courseBanner} alt={course.courseName || ""} fill className="object-cover group-hover:scale-105 transition-transform duration-500" />
                    : <div className="absolute inset-0 flex items-center justify-center"><BookOpen className="w-12 h-12 text-white/10" /></div>
                  }
                  <div className="absolute inset-0 bg-gradient-to-t from-[#232323] via-black/10 to-transparent" />
                  {/* Hover overlay */}
                  <div className="absolute inset-0 flex items-center justify-center gap-3 opacity-0 group-hover:opacity-100 transition-all duration-300 bg-black/50 backdrop-blur-sm">
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
    </div>
  );
}
